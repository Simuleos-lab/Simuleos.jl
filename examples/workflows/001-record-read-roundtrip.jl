# ============================================================
# 001 — Record + Read round-trip (curated workflow example)
# ============================================================

import Simuleos: each_commits, each_scopes, latest_scope, value, @simos

# HERE
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

let
    # HERE
    proj = @simos project.current()

    println("\n== Commit List ==")
    for commit in each_commits(proj; session = "roundtrip-demo")
        println("commit=", commit.commit_label, " scopes=", length(commit.scopes))
    end

    println("\n== Warmup Variable Storage Modes ==")
    warmup_scope = latest_scope(proj; session = "roundtrip-demo", commit_label = "warmup")
    for name in (:params, :table, :raw_signal)
        var = warmup_scope.variables[name]
        println(name, " type=", typeof(var), " resolved=", value(var, proj))
    end

    println("\n== Flat Scope Walk ==")
    for scope in each_scopes(proj; session = "roundtrip-demo")
        labels = join(scope.labels, "/")
        step = get(scope.metadata, :step, missing)
        phase = get(scope.metadata, :phase, missing)
        println("scope=", labels, " step=", step, " phase=", phase)
        for name in (:params, :table, :raw_signal, :squares, :total)
            haskey(scope.variables, name) || continue
            println("  ", name, " => ", value(scope.variables[name], proj))
        end
    end
end

@simos system.reset()
println("\nDone.")
