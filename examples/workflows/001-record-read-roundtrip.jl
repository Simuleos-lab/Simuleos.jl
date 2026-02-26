# ============================================================
# 001 — Record + Read round-trip (curated workflow example)
# ============================================================

import Simuleos: value, @simos

@simos system.init(; reinit = true, sandbox = (;
    root = joinpath(@__DIR__, "_sandbox", basename(@__FILE__)),
    clean_on_init = true,
    cleanup_on_reset = false
))
@simos session.init("roundtrip-demo", "run-001")

let
    step = 1
    params = Dict("alpha" => 0.2, "beta" => 0.8)
    table = [Dict("t" => t, "y" => round(sin(t); digits = 4)) for t in 0:3]
    raw_signal = [sin(0.1 * k) for k in 1:200]

    @simos stage.inline(params)
    @simos stage.blob(table)
    @simos stage.hash(raw_signal)
    @simos stage.meta(step = step, phase = "warmup")
    @simos scope.capture("snapshot")
    @simos session.commit("warmup")
end

let
    step = 2
    squares = [k^2 for k in 1:6]
    total = sum(squares)

    @simos stage.inline(squares, total)
    @simos stage.meta(step = step, phase = "summary")
    @simos scope.capture("summary")
    result = @simos session.close("final")
    println("finalize.queued_tail_commit = ", result.queued_tail_commit)
end

# ── Query recorded data via SQLite index ─────────────────────

@simos sqlite.open(; sync = :refresh)

println("\n== Commit List (sqlite) ==")
for row in @simos sqlite.execute("""
    SELECT commit_label, scope_count
    FROM v_commits
    WHERE session_label = 'roundtrip-demo'
    ORDER BY commit_ord
""")
    println("commit=", row[:commit_label], " scopes=", row[:scope_count])
end

println("\n== Warmup Variable Storage Modes (sqlite) ==")
for row in @simos sqlite.execute("""
    SELECT var_name, type_short, storage_kind, blob_ref, hash_ref
    FROM v_scope_vars_inventory
    WHERE commit_label = 'warmup'
      AND var_name IN ('params', 'table', 'raw_signal')
    ORDER BY var_ord
""")
    mode = row[:storage_kind]
    detail = if mode == "blob"
        bref = string(row[:blob_ref])
        " blob=" * (length(bref) > 12 ? bref[1:12] * "..." : bref)
    elseif mode == "hash"
        href = string(row[:hash_ref])
        " hash=" * (length(href) > 12 ? href[1:12] * "..." : href)
    else
        ""
    end
    println(row[:var_name], " type=", row[:type_short], " storage=", mode, detail)
end

println("\n== Flat Scope Walk (sqlite) ==")
for row in @simos sqlite.execute("""
    SELECT scope_uid, scope_labels_csv, commit_label
    FROM v_scope_inventory
    WHERE session_label = 'roundtrip-demo'
    ORDER BY commit_ord, scope_ord
""")
    # Scope metadata from the metadata KV table
    phase = ""
    step_val = ""
    for meta_row in @simos sqlite.execute("""
        SELECT meta_key, value_text FROM scope_meta_kv
        WHERE scope_uid = ? AND meta_key IN ('phase', 'step')
    """, (row[:scope_uid],))
        if meta_row[:meta_key] == "phase"
            phase = meta_row[:value_text]
        elseif meta_row[:meta_key] == "step"
            step_val = meta_row[:value_text]
        end
    end
    println("scope=", row[:scope_labels_csv], " step=", step_val, " phase=", phase)

    # Variables in this scope
    for var_row in @simos sqlite.execute("""
        SELECT var_name, storage_kind, type_short
        FROM scope_vars
        WHERE scope_uid = ? AND storage_kind != 'omitted'
        ORDER BY var_ord
    """, (row[:scope_uid],))
        println("  ", var_row[:var_name], " (", var_row[:storage_kind], ", ", var_row[:type_short], ")")
    end
end

@simos sqlite.close()
@simos system.reset()
println("\nDone.")
