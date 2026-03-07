# ============================================================
# 007 — Settings + context-tagged artifacts (curated workflow)
# ============================================================

import Simuleos: @simos

const SANDBOX_DIR = joinpath(@__DIR__, "_sandbox", basename(@__FILE__))
const REPORTS_DIR = joinpath(SANDBOX_DIR, "reports")
const SANDBOX_SPEC_CLEAN = (
    root = SANDBOX_DIR,
    clean_on_init = true,
    cleanup_on_reset = false,
)

function write_text_report(
        path::String;
        title::String,
        tag::String,
        note::Union{Nothing, String},
        xs::Vector{Int},
        ys::Vector{Float64},
        summary::Dict{String, Any},
        settings_snapshot,
        context_ref,
    )::String
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "# Simuleos Context-Tagged Report")
        println(io, "title = ", title)
        println(io, "tag = ", tag)
        isnothing(note) || println(io, "note = ", note)
        println(io, "context_ref = ", context_ref)
        println(io)
        println(io, "## Summary")
        for k in sort!(collect(keys(summary)))
            println(io, k, " = ", summary[k])
        end
        println(io)
        println(io, "## Data")
        println(io, "x,y")
        for (x, y) in zip(xs, ys)
            println(io, x, ",", y)
        end
        println(io)
        println(io, "## Settings Snapshot")
        println(io, repr(settings_snapshot))
    end
    return path
end

println("sandbox = ", SANDBOX_DIR)
println("cli args = ", ARGS)

@simos system.init(; reinit = true, sandbox = SANDBOX_SPEC_CLEAN)
@simos session.init("context-tags-demo", "run-1")

# Script defaults go in the script layer.
@simos settings.merge(Dict(
    "workflow" => Dict(
        "context_demo" => Dict(
            "title" => "quadratic-report",
            "n_points" => 6,
            "scale" => 1.25,
            "precision" => 4,
            "tag" => "baseline",
        ),
    ),
); layer = :script)

# Allow CLI overrides to win over script defaults for this example.
# Example:
#   julia --project=. examples/workflows/007-settings-and-context-tags.jl \
#       --set workflow.context_demo.scale=2.0 \
#       --set workflow.context_demo.tag=experiment-A
@simos settings.source.add_args(ARGS; after = :script)

title = String(@simos settings.require("workflow.context_demo.title"))
n_points = Int(@simos settings.require("workflow.context_demo.n_points"))
scale = Float64(@simos settings.require("workflow.context_demo.scale"))
precision = Int(@simos settings.get("workflow.context_demo.precision"; default = 4))
tag = String(@simos settings.get("workflow.context_demo.tag"; default = "untagged"))
note = if @simos settings.has("workflow.context_demo.note")
    String(@simos settings.require("workflow.context_demo.note"))
else
    nothing
end

xs = collect(0:(n_points - 1))
ys = [round(scale * (x^2); digits = precision) for x in xs]
summary = Dict{String, Any}(
    "count" => length(ys),
    "sum" => round(sum(ys); digits = precision),
    "mean" => round(sum(ys) / length(ys); digits = precision),
    "max" => maximum(ys),
)

settings_snapshot = @simos settings.snapshot(; prefix = "workflow.context_demo", nested = true)
println("\nsettings.snapshot(prefix=workflow.context_demo) = ", settings_snapshot)

# Capture a provenance context record before creating the artifact filename.
ctx_ref = @simos context.capture()
ctx_tree = @simos context.resolve(ctx_ref)

artifact_path = joinpath(REPORTS_DIR, "$(title)-$(tag)-$(ctx_ref).txt")
write_text_report(
    artifact_path;
    title = title,
    tag = tag,
    note = note,
    xs = xs,
    ys = ys,
    summary = summary,
    settings_snapshot = settings_snapshot,
    context_ref = ctx_ref,
)

captured_setting_keys = if haskey(ctx_tree, "settings")
    sort!(collect(keys(ctx_tree["settings"]["accessed"])))
else
    String[]
end

artifact_name = basename(artifact_path)
context_short = string(ctx_ref)
@simos rec.inline(artifact_name, context_short, summary)
@simos rec.meta(kind = "text_report", tag = tag, context_ref = context_short)
@simos rec.capture("artifact")
result = @simos session.close("artifact-export")

println("\ncontext ref = ", ctx_ref)
println("context resolve keys = ", sort!(collect(keys(ctx_tree))))
println("captured setting keys = ", captured_setting_keys)
println("artifact = ", artifact_path)
println("finalize.queued_tail_commit = ", result.queued_tail_commit)

@simos system.reset()
println("\nDone.")
