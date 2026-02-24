# ============================================================
# 005 — Pipeline stage lineage via commit labels + src_file
# ============================================================

import Simuleos: each_commits, latest_scope, @simos

const SANDBOX_DIR = joinpath(@__DIR__, "_sandbox", basename(@__FILE__))

println("sandbox = ", SANDBOX_DIR)

src_filter = basename(@__FILE__)

@simos system.init(; reinit = true, sandbox = (;
    root = joinpath(@__DIR__, "_sandbox", basename(@__FILE__)),
    clean_on_init = true,
    cleanup_on_reset = false,
))
@simos session.init("pipeline-demo", "run-1")

# Stage 1: prepare
let
    raw_points = [1.0, 2.0, 4.0, 7.0]
    prepared_points = [round(log(1 + x); digits = 4) for x in raw_points]

    @simos stage.inline(prepared_points)
    @simos stage.meta(stage = "prepare")
    @simos scope.capture("prepare")
end
@simos session.commit("prepare-output")

proj = @simos project.current()
prepare_scope = latest_scope(
    proj;
    session = "pipeline-demo",
    commit_label = "prepare-output",
    src_file = src_filter,
)

# Stage 2: fit (reads stage-1 output from tape)
let
    prepared_points = Float64[]
    @simos scope.bind(prepare_scope, proj, prepared_points)

    slope = sum(prepared_points) / length(prepared_points)
    intercept = prepared_points[end] - slope

    @simos stage.inline(prepared_points, slope, intercept)
    @simos stage.meta(stage = "fit")
    @simos scope.capture("fit")

    println("stage-2 recovered prepared_points = ", prepared_points)
    println("stage-2 fit: slope=", slope, " intercept=", intercept)
end
@simos session.commit("fit-output")

fit_scope = latest_scope(
    proj;
    session = "pipeline-demo",
    commit_label = "fit-output",
    src_file = src_filter,
)

# Stage 3: summary (reads stage-2 output from tape)
let
    slope = 0.0
    intercept = 0.0
    @simos scope.bind(fit_scope, proj, slope, intercept)

    prediction_at_5 = slope * 5 + intercept
    status = prediction_at_5 > 0 ? "ok" : "check"

    @simos stage.inline(prediction_at_5, status)
    @simos stage.meta(stage = "summary")
    @simos scope.capture("summary")

    println("stage-3 recovered fit params: slope=", slope, " intercept=", intercept)
    println("stage-3 summary: prediction_at_5=", prediction_at_5, " status=", status)
end

result = @simos session.close("summary-output")
println("finalize.queued_tail_commit = ", result.queued_tail_commit)

println("\n== Pipeline Lineage ==")
for commit in each_commits(proj; session = "pipeline-demo")
    println("commit=", commit.commit_label)
    for scope in commit.scopes
        println(
            "  labels=", join(scope.labels, "/"),
            " stage=", get(scope.metadata, :stage, missing),
            " src_file=", get(scope.metadata, :src_file, missing),
        )
    end
end

@simos system.reset()
println("\nDone.")
