# ============================================================
# 005 — Pipeline stage lineage via commit labels + src_file
# ============================================================

import Simuleos: latest_scope, @simos

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

    @simos rec.inline(prepared_points)
    @simos rec.meta(stage = "prepare")
    @simos rec.capture("prepare")
end
@simos rec.commit("prepare-output")

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
    @simos base.bind(prepare_scope, prepared_points)

    slope = sum(prepared_points) / length(prepared_points)
    intercept = prepared_points[end] - slope

    @simos rec.inline(prepared_points, slope, intercept)
    @simos rec.meta(stage = "fit")
    @simos rec.capture("fit")

    println("stage-2 recovered prepared_points = ", prepared_points)
    println("stage-2 fit: slope=", slope, " intercept=", intercept)
end
@simos rec.commit("fit-output")

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
    @simos base.bind(fit_scope, slope, intercept)

    prediction_at_5 = slope * 5 + intercept
    status = prediction_at_5 > 0 ? "ok" : "check"

    @simos rec.inline(prediction_at_5, status)
    @simos rec.meta(stage = "summary")
    @simos rec.capture("summary")

    println("stage-3 recovered fit params: slope=", slope, " intercept=", intercept)
    println("stage-3 summary: prediction_at_5=", prediction_at_5, " status=", status)
end

result = @simos session.close("summary-output")
println("finalize.queued_tail_commit = ", result.queued_tail_commit)

# ── Pipeline lineage via SQLite ──────────────────────────────

@simos sqlite.open(; sync = :refresh)

println("\n== Pipeline Lineage (sqlite) ==")
for row in @simos sqlite.execute("""
    SELECT c.commit_label, c.commit_ord, COUNT(sc.scope_uid) AS scope_count
    FROM commits c
    JOIN sessions s ON c.session_id = s.session_id
    LEFT JOIN scopes sc ON c.commit_uid = sc.commit_uid
    WHERE s.session_label = 'pipeline-demo'
    GROUP BY c.commit_uid
    ORDER BY c.commit_ord
""")
    println("commit=", row[:commit_label], " (#", row[:commit_ord], ", ", row[:scope_count], " scopes)")
end

println("\n== Stage Metadata per Scope (sqlite) ==")
for row in @simos sqlite.execute("""
    SELECT si.scope_labels_csv, si.commit_label, si.src_file, si.src_line,
           m.value_text AS stage_name
    FROM v_scope_inventory si
    JOIN scope_meta_kv m ON si.scope_uid = m.scope_uid AND m.meta_key = 'stage'
    JOIN sessions s ON si.session_id = s.session_id
    WHERE s.session_label = 'pipeline-demo'
    ORDER BY si.commit_ord, si.scope_ord
""")
    println("  scope=", row[:scope_labels_csv],
        " stage=", row[:stage_name],
        " @ ", row[:commit_label],
        " src=", row[:src_file], ":", row[:src_line])
end

println("\n== Variables per Stage (sqlite) ==")
for row in @simos sqlite.execute("""
    SELECT m.value_text AS stage_name, sv.var_name, sv.type_short, sv.storage_kind
    FROM scope_meta_kv m
    JOIN scope_vars sv ON m.scope_uid = sv.scope_uid
    JOIN v_scope_inventory si ON m.scope_uid = si.scope_uid
    JOIN sessions s ON si.session_id = s.session_id
    WHERE m.meta_key = 'stage'
      AND s.session_label = 'pipeline-demo'
      AND sv.storage_kind != 'omitted'
    ORDER BY si.commit_ord, sv.var_ord
""")
    println("  [", row[:stage_name], "] ", row[:var_name], " : ", row[:type_short], " (", row[:storage_kind], ")")
end

@simos sqlite.close()
@simos system.reset()
println("\nDone.")
