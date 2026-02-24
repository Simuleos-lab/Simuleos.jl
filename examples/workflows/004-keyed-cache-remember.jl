# ============================================================
# 004 — Keyed cache + remember workflows
# ============================================================

import Simuleos: remember!, @simos

const SANDBOX_DIR = joinpath(@__DIR__, "_sandbox", basename(@__FILE__))
println("sandbox = ", SANDBOX_DIR)

# 1) Populate cache
@simos system.init(; reinit = true, sandbox = (;
    root = joinpath(@__DIR__, "_sandbox", basename(@__FILE__)),
    clean_on_init = true,
    cleanup_on_reset = false,
))
@simos session.init("cache-demo", "run-1")

model = "toy-model"
eps = 1e-6
solver = "HiGHS"
seed = 42

h = @simos cache.key("solver-inputs", model, eps, solver, seed = seed, mode = "fast")
println("ctx_hash(solver-inputs) = ", h)

named_calls = Ref(0)
value1, status1 = remember!("solve"; ctx = "solver-inputs", tags = ["workflow", "cache"]) do
    named_calls[] += 1
    Dict("solver" => solver, "objective" => 0.91, "seed" => seed)
end
value2, status2 = remember!("solve"; ctx = "solver-inputs", tags = ["workflow", "cache"]) do
    named_calls[] += 1
    Dict("solver" => "ignored", "objective" => 9.99, "seed" => -1)
end
println("remember!(ctx=label): ", status1, " then ", status2, " calls=", named_calls[])
println("cached value = ", value2)

metric_calls = Ref(0)
status_metric_1 = @simos cache.remember(h, metric) do
    metric_calls[] += 1
    length(model) + Int(round(-log10(eps)))
end
metric = -1
status_metric_2 = @simos cache.remember(h, metric) do
    metric_calls[] += 1
    999
end
println("@simos cache.remember metric: ", status_metric_1, " then ", status_metric_2, " metric=", metric, " calls=", metric_calls[])

partition_calls = Ref(0)
status_a1 = @simos cache.remember(h, score; metric = "A", fold = 1) do
    partition_calls[] += 1
    101
end
status_a2 = @simos cache.remember(h, score; metric = "A", fold = 1) do
    partition_calls[] += 1
    999
end
status_b1 = @simos cache.remember(h, score; metric = "B", fold = 1) do
    partition_calls[] += 1
    202
end
println("partitioned scores: A1=", status_a1, " A2=", status_a2, " B1=", status_b1, " calls=", partition_calls[])

@simos session.close("run-1")

# 2) Re-initialize and prove cross-session cache reuse
@simos system.init(; reinit = true, sandbox = (;
    root = joinpath(@__DIR__, "_sandbox", basename(@__FILE__)),
    cleanup_on_reset = false,
))
@simos session.init("cache-demo", "run-2")

model = "toy-model"
eps = 1e-6
solver = "HiGHS"
seed = 42
h2 = @simos cache.key("solver-inputs", model, eps, solver, seed = seed, mode = "fast")

cross_calls = Ref(0)
status_cross = @simos cache.remember(h2, metric) do
    cross_calls[] += 1
    123456
end
println("\nctx hash stable across runs? ", h2 == h)
println("cross-session @simos cache.remember metric: status=", status_cross, " metric=", metric, " calls=", cross_calls[])

@simos system.reset()
println("\nDone.")
