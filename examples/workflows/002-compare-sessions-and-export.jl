# ============================================================
# 002 — Compare sessions + export (scope_table workflow)
# ============================================================

import Simuleos: scope_table, @simos

const SANDBOX_DIR = joinpath(@__DIR__, "_sandbox", basename(@__FILE__))

function record_run!(session_label::String, biomass_values::Vector{Float64})
    for (step, biomass) in enumerate(biomass_values[1:end-1])
        @simos stage.meta(step = step, session = session_label)
        @simos scope.capture("obs")
        @simos session.queue("iter")
    end

    step = length(biomass_values)
    biomass = biomass_values[end]
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

proj = @simos project.current()
rows_a = scope_table(proj; session = "compare-A")
rows_b = scope_table(proj; session = "compare-B")

println("\nrows(compare-A) = ", length(rows_a))
println("rows(compare-B) = ", length(rows_b))

by_step_a = Dict(Int(row[:step]) => row for row in rows_a if haskey(row, :step))
by_step_b = Dict(Int(row[:step]) => row for row in rows_b if haskey(row, :step))
steps = sort!(collect(intersect(keys(by_step_a), keys(by_step_b))))

comparison = Dict{String, Any}[]
for step in steps
    row_a = by_step_a[step]
    row_b = by_step_b[step]
    biomass_a = Float64(row_a[:biomass])
    biomass_b = Float64(row_b[:biomass])
    push!(comparison, Dict(
        "step" => step,
        "biomass_A" => biomass_a,
        "biomass_B" => biomass_b,
        "delta_B_minus_A" => biomass_b - biomass_a,
        "commit_A" => String(row_a[:commit_label]),
        "commit_B" => String(row_b[:commit_label]),
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

@simos system.reset()
println("\nDone.")
