# ============================================================
# 002 — Compare sessions + export (SQLite query workflow)
# ============================================================

import Simuleos: @simos

const SANDBOX_DIR = joinpath(@__DIR__, "_sandbox", basename(@__FILE__))

function record_run!(session_label::String, biomass_values::Vector{Float64})
    for (step, biomass) in enumerate(biomass_values[1:end-1])
        @simos stage.inline(biomass)
        @simos stage.meta(step = step, session = session_label)
        @simos scope.capture("obs")
        @simos session.queue("iter")
    end

    step = length(biomass_values)
    biomass = biomass_values[end]
    @simos stage.inline(biomass)
    @simos stage.meta(step = step, session = session_label)
    @simos scope.capture("obs")
    result = @simos session.close("tail")
    println("recorded ", session_label, " finalize.queued_tail_commit=", result.queued_tail_commit)
    return nothing
end

function csv_escape(x)
    s = string(x)
    if occursin(',', s) || occursin('"', s) || occursin('\n', s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

function write_csv_rows(path::String, rows::Vector{Dict{String, Any}})
    isempty(rows) && error("No rows to write.")
    cols = sort!(collect(keys(rows[1])))
    open(path, "w") do io
        println(io, join(cols, ","))
        for row in rows
            println(io, join([csv_escape(get(row, c, "")) for c in cols], ","))
        end
    end
    return path
end

println("sandbox = ", SANDBOX_DIR)

@simos system.init(; reinit = true, sandbox = (;
    root = joinpath(@__DIR__, "_sandbox", basename(@__FILE__)),
    clean_on_init = true,
    cleanup_on_reset = false,
))
@simos session.init("compare-A")
record_run!("compare-A", [0.50, 0.61, 0.73, 0.86, 1.00])

@simos system.init(; reinit = true, sandbox = (;
    root = joinpath(@__DIR__, "_sandbox", basename(@__FILE__)),
    cleanup_on_reset = false,
))
@simos session.init("compare-B")
record_run!("compare-B", [0.48, 0.63, 0.78, 0.93, 1.10])

# ── Query both sessions via SQLite ───────────────────────────

@simos sqlite.open(; sync = :refresh)

println("\n== Session Summary (sqlite) ==")
for row in @simos sqlite.execute("""
    SELECT session_label, commit_count, scope_count
    FROM v_sessions
    WHERE session_label IN ('compare-A', 'compare-B')
    ORDER BY session_label
""")
    println("  ", row[:session_label], ": commits=", row[:commit_count], " scopes=", row[:scope_count])
end

# Build per-session step→biomass maps from scope metadata + variables
function fetch_step_biomass(label::String)
    result = Dict{Int, Float64}()
    for row in @simos sqlite.execute("""
        SELECT m.scope_uid, m.value_text AS step_text
        FROM v_scope_meta_inventory m
        WHERE m.meta_key = 'step'
          AND m.session_label = ?
        ORDER BY CAST(m.value_text AS INTEGER)
    """, (label,))
        step = parse(Int, row[:step_text])
        # Get biomass variable value for this scope (inline storage)
        for vrow in @simos sqlite.execute("""
            SELECT vi.var_name
            FROM scope_vars vi
            WHERE vi.scope_uid = ? AND vi.var_name = 'biomass'
        """, (row[:scope_uid],))
            # The value itself is on the tape (inline JSON), but for the
            # comparison we reconstruct from the metadata session label.
            # In a real workflow, you'd hydrate via ScopeReader for inline values.
        end
        result[step] = 0.0  # placeholder — filled from known inputs below
    end
    return result
end

# For this curated example, we use the known biomass values directly
# and demonstrate the SQL-based comparison structure.
biomass_A = Dict(i => v for (i, v) in enumerate([0.50, 0.61, 0.73, 0.86, 1.00]))
biomass_B = Dict(i => v for (i, v) in enumerate([0.48, 0.63, 0.78, 0.93, 1.10]))

# Cross-session comparison via SQL: match scopes by step metadata
comparison = Dict{String, Any}[]
for row in @simos sqlite.execute("""
    SELECT
        ma.value_text AS step,
        ma.commit_label AS commit_A,
        mb.commit_label AS commit_B
    FROM v_scope_meta_inventory ma
    JOIN v_scope_meta_inventory mb
        ON ma.meta_key = mb.meta_key
        AND ma.value_text = mb.value_text
    WHERE ma.meta_key = 'step'
      AND ma.session_label = 'compare-A'
      AND mb.session_label = 'compare-B'
    ORDER BY CAST(ma.value_text AS INTEGER)
""")
    step = parse(Int, row[:step])
    ba = biomass_A[step]
    bb = biomass_B[step]
    push!(comparison, Dict(
        "step" => step,
        "biomass_A" => ba,
        "biomass_B" => bb,
        "delta_B_minus_A" => bb - ba,
        "commit_A" => string(row[:commit_A]),
        "commit_B" => string(row[:commit_B]),
    ))
end

csv_path = joinpath(SANDBOX_DIR, "session-comparison.csv")
write_csv_rows(csv_path, comparison)

println("\n== Comparison ==")
for row in comparison
    println(
        "step=", row["step"],
        " A=", round(row["biomass_A"]; digits = 4),
        " B=", round(row["biomass_B"]; digits = 4),
        " delta=", round(row["delta_B_minus_A"]; digits = 4),
    )
end
println("csv = ", csv_path)

@simos sqlite.close()
@simos system.reset()
println("\nDone.")
