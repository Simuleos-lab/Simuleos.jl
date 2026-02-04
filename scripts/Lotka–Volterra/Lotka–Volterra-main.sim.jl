#!/usr/bin/env julia
@time let
    import Pkg
    Pkg.activate(@__DIR__)
    
    using Random
    using Dates
    using Serialization
    using Simuleos
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

    # Randomly draw parameters from plausible ranges
    rng = Random.default_rng()
    X0 = rand(rng) * (50 - 20) + 20           # prey initial: 20-50
    Y0 = rand(rng) * (15 - 5) + 5             # predator initial: 5-15
    alpha = rand(rng) * (1.5 - 0.8) + 0.8     # prey growth: 0.8-1.5
    beta = rand(rng) * (0.12 - 0.05) + 0.05   # prey-predator: 0.05-0.12
    delta = rand(rng) * (0.08 - 0.04) + 0.04  # predator benefit: 0.04-0.08
    gamma = rand(rng) * (1.2 - 0.8) + 0.8     # predator mortality: 0.8-1.2
    sigmax = rand(rng) * (0.35 - 0.15) + 0.15 # prey noise: 0.15-0.35
    sigmay = rand(rng) * (0.35 - 0.15) + 0.15 # predator noise: 0.15-0.35
    strength = rand(rng) * (0.8 - 0.3) + 0.3  # intervention strength: 0.3-0.8

    simulate_lv(X0=X0, Y0=Y0, alpha=alpha, beta=beta, delta=delta, gamma=gamma,
                sigmax=sigmax, sigmay=sigmay, seed=rand(1:typemax(Int32)),
                intervention=:predator_death, strength=strength)

    # - store the current stage
    # - run hooks
    # - clear sim.stage
    @sim_commit
end