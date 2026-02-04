#!/usr/bin/env julia
@time let
    using Random
    using Dates
    using Serialization
end

## ...- .- .-- -- ..- .--. --. - .--.-..-...
# --- Lotka–Volterra with noise (Euler–Maruyama) ---
function simulate_lv(; X0=30.0, Y0=8.0, alpha=1.2, beta=0.08, delta=0.06, gamma=1.0,
                      sigmax=0.25, sigmay=0.25, dt=0.01, T=50.0, seed=1,
                      intervention=:predator_death, strength=0.6, t_int=T/2)

    rng = MersenneTwister(seed)
    n  = Int(floor(T/dt)) + 1
    ts = collect(0:dt:T)
    X  = similar(ts); Y = similar(ts)
    X[1] = X0; Y[1] = Y0

    alphat = fill(alpha, n); betat = fill(beta, n); deltat = fill(delta, n); gammat = fill(gamma, n)
    k = Int(clamp(round(t_int/dt)+1, 1, n))
    if intervention == :predator_death
        gammat[k:end] .= gamma * strength
    elseif intervention == :prey_restock
        X[k] += strength
    elseif intervention == :harvest_prey
        for i in k:round(Int, 1.0/dt):n
            X[i] = max(0.0, X[i] - strength)
        end
    end

    √dt = sqrt(dt)
    for i in 1:n-1
        x, y = X[i], Y[i]
        dx = (alphat[i]*x - betat[i]*x*y)*dt + sigmax*x*√dt*randn(rng)
        dy = (deltat[i]*x*y - gammat[i]*y)*dt + sigmay*y*√dt*randn(rng)
        X[i+1] = max(0.0, x + dx)
        Y[i+1] = max(0.0, y + dy)
    end

    events = Dict(
        "prey_extinct" => any(==(0.0), X),
        "pred_extinct" => any(==(0.0), Y),
        "X_max" => maximum(X),
        "Y_max" => maximum(Y),
        "t_X_max" => ts[argmax(X)],
        "t_Y_max" => ts[argmax(Y)]
    )

    params = Dict(
        "X0"=>X0, "Y0"=>Y0, "alpha"=>alpha, "beta"=>beta, "delta"=>delta, "gamma"=>gamma,
        "sigmax"=>sigmax, "sigmay"=>sigmay, "dt"=>dt, "T"=>T, "seed"=>seed,
        "intervention"=>string(intervention), "strength"=>strength, "t_int"=>t_int
    )

    return Dict("params"=>params, "ts"=>ts, "X"=>X, "Y"=>Y, "events"=>events,
                "rate_schedules"=>Dict("alpha"=>alphat,"beta"=>betat,"delta"=>deltat,"gamma"=>gammat))
end

# --- main execution ---
let
    data = simulate_lv(seed=42, intervention=:predator_death, strength=0.55)

    tag = "LV_seed$(data["params"]["seed"])_int$(data["params"]["intervention"])_s$(round(data["params"]["strength"], digits=3))"
    stamp = Dates.format(now(), "yyyymmdd_HHMMSS")
    fname = joinpath(@__DIR__, "runs", "$(tag)_$(stamp).jls")
    mkpath(dirname(fname))

    open(fname, "w") do io
        serialize(io, data)   # one-file snapshot: params + outputs + summaries
    end

    println("saved: ", fname)
end