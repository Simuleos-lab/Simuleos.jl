# ============================================================
# 006 — Shared scope handoff (in-memory workflow)
# ============================================================

import Simuleos: capture_filter_bind!, capture_filter_register!, @simos

const SANDBOX_DIR = joinpath(@__DIR__, "_sandbox", basename(@__FILE__))

println("sandbox = ", SANDBOX_DIR)
println("note: `shared.*` is in-memory and process-local in this MVP.")

@simos system.init(; reinit = true, sandbox = (;
    root = SANDBOX_DIR,
    clean_on_init = true,
    cleanup_on_reset = false,
))
@simos session.init("shared-demo", "run-1")

println("\n== 1) Configure capture filter reused by shared.capture ==")
capture_filter_register!("hide_scratch", [Dict(:regex => r"^scratch_", :action => :exclude)])
capture_filter_bind!("params", ["hide_scratch"])

println("\n== 2) Producer stores parameters in shared scope ==")
let
    alpha = 0.75
    n_iter = 4
    label = "baseline"
    scratch_note = "this should be filtered out"

    # Captures current local scope into shared key "params" and applies capture filters now.
    @simos shared.capture("params")
end

println("shared.has(params) = ", @simos shared.has("params"))
println("shared.keys() = ", @simos shared.keys())

println("\n== 3) Consumer binds typed values from shared scope ==")
let
    alpha = 0.0
    n_iter = 0
    label = ""

    @simos shared.bind("params", alpha::Float64, n_iter::Int, label::String)
    score = round(alpha * n_iter; digits = 3)
    status = score > 2 ? "ok" : "check"

    println("bound params: alpha=", alpha, " n_iter=", n_iter, " label=", label)
    println("derived score=", score, " status=", status)

    # Direct-by-name capture form (selected vars only).
    @simos shared.capture("result", score, status)
end

println("\n== 4) Merge override scope into params (shallow variable overwrite) ==")
let
    alpha = 0.90
    label = "override"
    @simos shared.capture("override", alpha, label)
end

@simos shared.merge("params", "override")

let
    alpha = 0.0
    n_iter = 0
    label = ""
    @simos shared.bind("params", alpha::Float64, n_iter::Int, label::String)
    println("params after merge: alpha=", alpha, " n_iter=", n_iter, " label=", label)
end

println("\n== 5) Registry management helpers ==")
println("shared.keys() = ", @simos shared.keys())
println("shared.drop(override) = ", @simos shared.drop("override"))
println("shared.has(override) = ", @simos shared.has("override"))
println("shared.keys() = ", @simos shared.keys())
println("shared.clear() removed = ", @simos shared.clear())
println("shared.keys() = ", @simos shared.keys())

@simos session.close("run-1")
@simos system.reset()

println("\nDone.")
