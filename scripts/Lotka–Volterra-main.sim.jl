#!/usr/bin/env julia
@time let
    using Random
    using Dates
    using Serialization
end

## ...- .- .-- -- ..- .--. --. - .--.-..-...
# --- Lotka–Volterra with noise (Euler–Maruyama) ---
function simulate_lv(; X0=30.0, Y0=8.0, α=1.2, β=0.08, δ=0.06, γ=1.0,
                      σx=0.25, σy=0.25, dt=0.01, T=50.0, seed=1,
                      intervention=:predator_death, strength=0.6, t_int=T/2)

    rng = MersenneTwister(seed)
    n  = Int(floor(T/dt)) + 1
    ts = collect(0:dt:T)
    X  = similar(ts); Y = similar(ts)
    X[1] = X0; Y[1] = Y0

    αt = fill(α, n); βt = fill(β, n); δt = fill(δ, n); γt = fill(γ, n)
    k = Int(clamp(round(t_int/dt)+1, 1, n))
    if intervention == :predator_death
        γt[k:end] .= γ * strength
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
        dx = (αt[i]*x - βt[i]*x*y)*dt + σx*x*√dt*randn(rng)
        dy = (δt[i]*x*y - γt[i]*y)*dt + σy*y*√dt*randn(rng)
        X[i+1] = max(0.0, x + dx)
        Y[i+1] = max(0.0, y + dy)
    end

    # mark non-lite variables to be stored
    # - call store hooks
    # - add link to scope
    @sim_store X, Y, ts

    # - collect scope variables
    # - tag the sope with label
    # - add it to the current stage [global]
    # - return the scope [local]
    @sim_capture "simulate_lv"
end

# --- main execution ---
let

    # - start a new simulation session
    # - collect metadata
    #   - date, time
    #   - path to script 
    #     - hash of commit
    #       - error if dirty
    # - clear sim.stage
    # - run hooks
    # - tag the scope with label
    @sim_session "Lotka-Volterra Simulation"

    simulate_lv(seed=42, intervention=:predator_death, strength=0.55)

    # - store the current stage
    # - run hooks
    # - clear sim.stage
    @sim_commit 
end