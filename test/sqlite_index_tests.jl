using Simuleos
using Test
using UUIDs
using SQLite

_sqlite_rowcol(row, name::Symbol) = getproperty(row, name)
_sqlite_rowcol(row, name::AbstractString) = getproperty(row, Symbol(name))
_sqlite_rowcol(row::Dict{Symbol, Any}, name::Symbol) = row[name]
_sqlite_rowcol(row::Dict{Symbol, Any}, name::AbstractString) = row[Symbol(name)]

function _sqlite_materialize_row(row)::Dict{Symbol, Any}
    names = getfield(getfield(row, :q), :names)
    vals = SQLite.values(row)
    return Dict{Symbol, Any}(Symbol(n) => v for (n, v) in zip(names, vals))
end

function _sqlite_one(db, sql::AbstractString, params = ())
    rows = Dict{Symbol, Any}[]
    for row in SQLite.DBInterface.execute(db, sql, params)
        push!(rows, _sqlite_materialize_row(row))
    end
    return only(rows)
end

@testset "SQLiteIndex Phase 2 refresh incremental + drift fallback" begin
    mktempdir() do root
        project_driver = Simuleos.Kernel.proj_init_at(root)
        session_id = uuid4()
        session_dir = joinpath(project_driver.simuleos_dir, "sessions", string(session_id))
        mkpath(joinpath(session_dir, "tapes", "main"))

        open(joinpath(session_dir, "session.json"), "w") do io
            Simuleos.Kernel.JSON3.pretty(io, Dict(
                "session_id" => string(session_id),
                "labels" => Any["sqlite-refresh-test"],
                "meta" => Dict("timestamp" => "2026-02-24T13:00:00"),
            ))
        end

        tape_path = Simuleos.Kernel.tape_path(project_driver, session_id)
        tape = Simuleos.Kernel.TapeIO(tape_path)

        Simuleos.Kernel.append!(tape, Dict(
            "type" => "commit",
            "commit_label" => "c1",
            "metadata" => Dict("timestamp" => "2026-02-24T13:00:01"),
            "scopes" => Any[
                Dict(
                    "labels" => Any["sample"],
                    "metadata" => Dict("src_file" => "/tmp/stage.jl", "src_line" => 10),
                    "variables" => Dict("x" => Dict("src_type" => "Int64", "src" => "local", "value" => 1)),
                ),
            ],
        ))

        idx_path = Simuleos.sqlite_index_rebuild!(project_driver)
        @test isfile(idx_path)

        db = Simuleos.sqlite_index_open(project_driver)
        try
            st0 = _sqlite_one(db, """
                SELECT last_indexed_commit_ord, refresh_mode
                FROM session_index_state
                WHERE session_id = ?
            """, (string(session_id),))
            @test _sqlite_rowcol(st0, :last_indexed_commit_ord) == 1
            @test _sqlite_rowcol(st0, :refresh_mode) == "rebuild"
        finally
            SQLite.close(db)
        end

        # No-op refresh should preserve counts and switch state mode to incremental.
        Simuleos.sqlite_index_refresh!(project_driver)
        db = Simuleos.sqlite_index_open(project_driver)
        try
            counts1 = _sqlite_one(db, """
                SELECT
                    (SELECT COUNT(*) FROM commits WHERE session_id = ?) AS n_commits,
                    (SELECT COUNT(*) FROM scopes WHERE session_id = ?) AS n_scopes
            """, (string(session_id), string(session_id)))
            @test _sqlite_rowcol(counts1, :n_commits) == 1
            @test _sqlite_rowcol(counts1, :n_scopes) == 1

            st1 = _sqlite_one(db, """
                SELECT last_indexed_commit_ord, refresh_mode
                FROM session_index_state
                WHERE session_id = ?
            """, (string(session_id),))
            @test _sqlite_rowcol(st1, :last_indexed_commit_ord) == 1
            @test _sqlite_rowcol(st1, :refresh_mode) == "incremental"
        finally
            SQLite.close(db)
        end

        # Append one commit and refresh incrementally.
        Simuleos.Kernel.append!(tape, Dict(
            "type" => "commit",
            "commit_label" => "c2",
            "metadata" => Dict("timestamp" => "2026-02-24T13:00:02"),
            "scopes" => Any[
                Dict(
                    "labels" => Any["sample"],
                    "metadata" => Dict("src_file" => "/tmp/stage.jl", "src_line" => 20),
                    "variables" => Dict("x" => Dict("src_type" => "Int64", "src" => "local", "value" => 2)),
                ),
            ],
        ))

        Simuleos.sqlite_index_refresh!(project_driver)
        db = Simuleos.sqlite_index_open(project_driver)
        try
            counts2 = _sqlite_one(db, """
                SELECT
                    (SELECT COUNT(*) FROM commits WHERE session_id = ?) AS n_commits,
                    (SELECT COUNT(*) FROM scopes WHERE session_id = ?) AS n_scopes
            """, (string(session_id), string(session_id)))
            @test _sqlite_rowcol(counts2, :n_commits) == 2
            @test _sqlite_rowcol(counts2, :n_scopes) == 2

            st2 = _sqlite_one(db, """
                SELECT last_indexed_commit_ord, refresh_mode
                FROM session_index_state
                WHERE session_id = ?
            """, (string(session_id),))
            @test _sqlite_rowcol(st2, :last_indexed_commit_ord) == 2
            @test _sqlite_rowcol(st2, :refresh_mode) == "incremental"
        finally
            SQLite.close(db)
        end

        # Rewrite/truncate the tape to trigger drift detection and rebuild fallback.
        rm(tape_path; recursive=true, force=true)
        mkpath(tape_path)
        tape_rewritten = Simuleos.Kernel.TapeIO(tape_path)
        Simuleos.Kernel.append!(tape_rewritten, Dict(
            "type" => "commit",
            "commit_label" => "rewritten",
            "metadata" => Dict("timestamp" => "2026-02-24T13:00:03"),
            "scopes" => Any[
                Dict(
                    "labels" => Any["sample"],
                    "metadata" => Dict("src_file" => "/tmp/stage.jl", "src_line" => 30),
                    "variables" => Dict("x" => Dict("src_type" => "Int64", "src" => "local", "value" => 99)),
                ),
            ],
        ))

        Simuleos.sqlite_index_refresh!(project_driver)
        db = Simuleos.sqlite_index_open(project_driver)
        try
            counts3 = _sqlite_one(db, """
                SELECT
                    (SELECT COUNT(*) FROM commits WHERE session_id = ?) AS n_commits,
                    (SELECT COUNT(*) FROM scopes WHERE session_id = ?) AS n_scopes
            """, (string(session_id), string(session_id)))
            @test _sqlite_rowcol(counts3, :n_commits) == 1
            @test _sqlite_rowcol(counts3, :n_scopes) == 1

            only_commit = _sqlite_one(db, """
                SELECT commit_label
                FROM commits
                WHERE session_id = ? AND commit_ord = 1
            """, (string(session_id),))
            @test _sqlite_rowcol(only_commit, :commit_label) == "rewritten"

            st3 = _sqlite_one(db, """
                SELECT last_indexed_commit_ord, refresh_mode
                FROM session_index_state
                WHERE session_id = ?
            """, (string(session_id),))
            @test _sqlite_rowcol(st3, :last_indexed_commit_ord) == 1
            @test _sqlite_rowcol(st3, :refresh_mode) == "rebuild"
        finally
            SQLite.close(db)
        end
    end
end

@testset "SQLiteIndex Phase 1 metadata rebuild" begin
    mktempdir() do root
        project_driver = Simuleos.Kernel.proj_init_at(root)
        storage = Simuleos.Kernel.BlobStorage(project_driver)

        session_id = uuid4()
        session_dir = joinpath(project_driver.simuleos_dir, "sessions", string(session_id))
        mkpath(joinpath(session_dir, "tapes", "main"))

        open(joinpath(session_dir, "session.json"), "w") do io
            Simuleos.Kernel.JSON3.pretty(io, Dict(
                "session_id" => string(session_id),
                "labels" => Any["sqlite-index-test", "smoke"],
                "meta" => Dict(
                    "timestamp" => "2026-02-24T12:00:00",
                    "init_file" => "/tmp/test-driver.jl",
                    "init_line" => 42,
                    "git_commit" => "abc123",
                    "git_dirty" => false,
                ),
            ))
        end

        blob_ref = Simuleos.Kernel.blob_write(storage, ("blob-key", 1), Dict("a" => 1))
        tape = Simuleos.Kernel.TapeIO(Simuleos.Kernel.tape_path(project_driver, session_id))

        # Non-commit row to ensure `tape_record_ord` is true tape order, not commit order.
        Simuleos.Kernel.append!(tape, Dict(
            "type" => "tape.manifest",
            "writer" => "test",
        ))

        Simuleos.Kernel.append!(tape, Dict(
            "type" => "commit",
            "commit_label" => "uh1.fix.point.fba.v1.main",
            "metadata" => Dict("timestamp" => "2026-02-24T12:00:01"),
            "scopes" => Any[
                Dict(
                    "labels" => Any["main.sample"],
                    "metadata" => Dict(
                        "src_file" => "/tmp/201.fix.point.fba.v1.MAIN.jl",
                        "src_line" => 150,
                        "threadid" => 1,
                        "workflow" => "scripts/simulations.uh.1",
                        "step" => 1,
                    ),
                    "variables" => Dict(
                        "YA1" => Dict("src_type" => "Float64", "src" => "local", "value" => 1.25),
                        "df" => Dict("src_type" => "DataFrame", "src" => "local", "blob_ref" => blob_ref.hash),
                        "sig" => Dict("src_type" => "Vector{Float64}", "src" => "local", "value_hash" => "deadbeef"),
                        "voidy" => Dict("src_type" => "Module", "src" => "global"),
                    ),
                ),
            ],
        ))

        Simuleos.Kernel.append!(tape, Dict(
            "type" => "commit",
            "commit_label" => "uh1.fix.point.fba.v1.main",
            "metadata" => Dict("timestamp" => "2026-02-24T12:00:02"),
            "scopes" => Any[
                Dict(
                    "labels" => Any["main.sample"],
                    "metadata" => Dict(
                        "src_file" => "/tmp/201.fix.point.fba.v1.MAIN.jl",
                        "src_line" => 151,
                        "step" => 2,
                    ),
                    "variables" => Dict(
                        "YA1" => Dict("src_type" => "Float64", "src" => "local", "value" => 2.0),
                    ),
                ),
                Dict(
                    "labels" => Any["main.summary"],
                    "metadata" => Dict(
                        "src_file" => "/tmp/201.fix.point.fba.v1.MAIN.jl",
                        "src_line" => 142,
                        "workflow" => "scripts/simulations.uh.1",
                    ),
                    "variables" => Dict(
                        "N_SAMPLES" => Dict("src_type" => "Int64", "src" => "local", "value" => 2),
                    ),
                ),
            ],
        ))

        idx_path = Simuleos.sqlite_index_rebuild!(project_driver)
        @test isfile(idx_path)
        @test endswith(idx_path, joinpath(".simuleos", "index", "metadata-v1.sqlite"))
        @test Simuleos.sqlite_index_path(project_driver) == idx_path

        db = Simuleos.sqlite_index_open(project_driver)
        try
            manifest = _sqlite_one(db, """
                SELECT schema_version, index_kind, project_root, simuleos_dir
                FROM index_manifest
            """)
            @test _sqlite_rowcol(manifest, :schema_version) == 1
            @test _sqlite_rowcol(manifest, :index_kind) == "simuleos_metadata"
            @test _sqlite_rowcol(manifest, :project_root) == project_driver.root_path
            @test _sqlite_rowcol(manifest, :simuleos_dir) == project_driver.simuleos_dir

            counts = _sqlite_one(db, """
                SELECT
                    (SELECT COUNT(*) FROM sessions) AS n_sessions,
                    (SELECT COUNT(*) FROM session_labels) AS n_session_labels,
                    (SELECT COUNT(*) FROM commits) AS n_commits,
                    (SELECT COUNT(*) FROM scopes) AS n_scopes,
                    (SELECT COUNT(*) FROM scope_labels) AS n_scope_labels
            """)
            @test _sqlite_rowcol(counts, :n_sessions) == 1
            @test _sqlite_rowcol(counts, :n_session_labels) == 2
            @test _sqlite_rowcol(counts, :n_commits) == 2
            @test _sqlite_rowcol(counts, :n_scopes) == 3
            @test _sqlite_rowcol(counts, :n_scope_labels) == 3

            c1 = _sqlite_one(db, """
                SELECT commit_uid, commit_ord, tape_record_ord, commit_label
                FROM commits
                WHERE session_id = ? AND commit_ord = 1
            """, (string(session_id),))
            @test _sqlite_rowcol(c1, :commit_uid) == string(session_id, ":c1")
            @test _sqlite_rowcol(c1, :tape_record_ord) > _sqlite_rowcol(c1, :commit_ord)
            @test _sqlite_rowcol(c1, :commit_label) == "uh1.fix.point.fba.v1.main"

            s1 = _sqlite_one(db, """
                SELECT scope_uid, src_file, src_line
                FROM scopes
                WHERE session_id = ? AND commit_ord = 1 AND scope_ord = 1
            """, (string(session_id),))
            @test _sqlite_rowcol(s1, :scope_uid) == string(session_id, ":c1:s1")
            @test endswith(String(_sqlite_rowcol(s1, :src_file)), "201.fix.point.fba.v1.MAIN.jl")
            @test _sqlite_rowcol(s1, :src_line) == 150

            v_df = _sqlite_one(db, """
                SELECT storage_kind, scope_level, type_short, blob_ref, hash_ref
                FROM scope_vars
                WHERE scope_uid = ? AND var_name = 'df'
            """, (string(session_id, ":c1:s1"),))
            @test _sqlite_rowcol(v_df, :storage_kind) == "blob"
            @test _sqlite_rowcol(v_df, :scope_level) == "local"
            @test _sqlite_rowcol(v_df, :type_short) == "DataFrame"
            @test _sqlite_rowcol(v_df, :blob_ref) == blob_ref.hash
            @test ismissing(_sqlite_rowcol(v_df, :hash_ref))

            v_sig = _sqlite_one(db, """
                SELECT storage_kind, hash_ref
                FROM scope_vars
                WHERE scope_uid = ? AND var_name = 'sig'
            """, (string(session_id, ":c1:s1"),))
            @test _sqlite_rowcol(v_sig, :storage_kind) == "hash"
            @test _sqlite_rowcol(v_sig, :hash_ref) == "deadbeef"

            meta_workflow = _sqlite_one(db, """
                SELECT value_kind, value_text
                FROM scope_meta_kv
                WHERE scope_uid = ? AND meta_key = 'workflow'
            """, (string(session_id, ":c1:s1"),))
            @test _sqlite_rowcol(meta_workflow, :value_kind) == "string"
            @test _sqlite_rowcol(meta_workflow, :value_text) == "scripts/simulations.uh.1"

            sample_scopes = _sqlite_one(db, """
                SELECT COUNT(*) AS n
                FROM scopes s
                JOIN scope_labels l ON l.scope_uid = s.scope_uid
                WHERE s.session_id = ? AND l.label = 'main.sample'
            """, (string(session_id),))
            @test _sqlite_rowcol(sample_scopes, :n) == 2
        finally
            SQLite.close(db)
        end
    end
end
