#!/usr/bin/env julia
# Lotka-Volterra Simulation Plotting Script
# Uses Simuleos query API to load recorded simulation data

@time begin
    import Pkg
    Pkg.activate(@__DIR__)
    
    using Simuleos
    using CairoMakie
end

## ..--. --. .- --. .- .- -.. - .--. -. -. 
# Load data from .simuleos recording
function load_lv_data(simuleos_path::String)
    root = RootHandler(simuleos_path)

    # Get the first (and only) session
    sess = rand(sessions(root))
    t = tape(sess)

    # Get the latest commit
    commit = rand(collect(t))
    @time scope = rand(collect(scopes(commit)))

    # Extract variables
    vars = Dict{String, VariableWrapper}()
    for var in variables(scope)
        vars[name(var)] = var
    end

    # Load blob data for time series
    ts_ref = blob_ref(vars["ts"])
    X_ref = blob_ref(vars["X"])
    Y_ref = blob_ref(vars["Y"])

    ts = data(load_blob(blob(root, ts_ref)))
    X = data(load_blob(blob(root, X_ref)))
    Y = data(load_blob(blob(root, Y_ref)))

    # Extract parameters (lite values)
    params = Dict{String, Any}()
    for (k, var) in vars
        v = value(var)
        if !isnothing(v)
            params[k] = v
        end
    end

    return (; 
        ts, X, Y, params, 
        metadata=metadata(commit), 
        scope_label=label(scope)
    )
end

# Plot population dynamics over time
function plot_populations(ts, X, Y; title="Lotka-Volterra Population Dynamics")
    fig = Figure(size=(800, 500))
    ax = Axis(fig[1, 1],
        xlabel="Time",
        ylabel="Population",
        title=title
    )

    lines!(ax, ts, X, label="Prey (X)", color=:blue, linewidth=1.5)
    lines!(ax, ts, Y, label="Predator (Y)", color=:red, linewidth=1.5)

    axislegend(ax, position=:rt)

    return fig
end

# Plot phase space (prey vs predator)
function plot_phase_space(X, Y; title="Phase Space")
    fig = Figure(size=(600, 600))
    ax = Axis(fig[1, 1],
        xlabel="Prey (X)",
        ylabel="Predator (Y)",
        title=title
    )

    lines!(ax, X, Y, color=:purple, linewidth=1.0, alpha=0.8)
    scatter!(ax, [X[1]], [Y[1]], color=:green, markersize=12, label="Start")
    scatter!(ax, [X[end]], [Y[end]], color=:red, markersize=12, label="End")

    axislegend(ax, position=:rt)

    return fig
end

# Combined dashboard
function plot_dashboard(ts, X, Y, params; session_label="")
    fig = Figure(size=(1200, 800))

    # Title with session info
    Label(fig[0, 1:4], session_label, fontsize=20, font=:bold)

    # Population dynamics
    ax1 = Axis(fig[1, 1:2],
        xlabel="Time",
        ylabel="Population",
        title="Population Dynamics"
    )
    lines!(ax1, ts, X, label="Prey (X)", color=:blue, linewidth=1.5)
    lines!(ax1, ts, Y, label="Predator (Y)", color=:red, linewidth=1.5)
    axislegend(ax1, position=:rt)

    # Phase space
    ax2 = Axis(fig[1, 3],
        xlabel="Prey (X)",
        ylabel="Predator (Y)",
        title="Phase Space"
    )
    lines!(ax2, X, Y, color=:purple, linewidth=1.0, alpha=0.8)
    scatter!(ax2, [X[1]], [Y[1]], color=:green, markersize=12, label="Start")
    scatter!(ax2, [X[end]], [Y[end]], color=:red, markersize=12, label="End")
    axislegend(ax2, position=:rt)

    # Parameters panel
    param_text = join([
        "Parameters:",
        "  alpha = $(get(params, "alpha", "?"))",
        "  beta = $(get(params, "beta", "?"))",
        "  delta = $(get(params, "delta", "?"))",
        "  gamma = $(get(params, "gamma", "?"))",
        "  sigmax = $(get(params, "sigmax", "?"))",
        "  sigmay = $(get(params, "sigmay", "?"))",
        "",
        "Initial conditions:",
        "  X₀ = $(get(params, "X0", "?"))",
        "  Y₀ = $(get(params, "Y0", "?"))",
        "",
        "Simulation:",
        "  T = $(get(params, "T", "?"))",
        "  dt = $(get(params, "dt", "?"))",
        "  seed = $(get(params, "seed", "?"))",
        "",
        "Intervention:",
        "  type = $(get(params, "intervention", "?"))",
        "  strength = $(round(get(params, "strength", 0.0), digits=3))",
        "  t_int = $(get(params, "t_int", "?"))",
    ], "\n")

    Label(fig[1, 4], param_text, fontsize=12, halign=:left, valign=:top,
          tellwidth=false, tellheight=true)

    return fig
end

## ..--. -. -.- .- -- - -. -- .- .- .- .-.- .- .-.- - -. -
# Main execution
let
    simuleos_path = joinpath(@__DIR__, ".simuleos")

    println("Loading data from: ", simuleos_path)
    lv = load_lv_data(simuleos_path)

    println("Session: ", lv.scope_label)
    println("Time points: ", length(lv.ts))
    println("Parameters: ", keys(lv.params))

    # Create plots
    fig = plot_dashboard(lv.ts, lv.X, lv.Y, lv.params,
                        session_label="Lotka-Volterra Simulation")

    # Save plot
    output_path = joinpath(@__DIR__, "lv_dashboard.png")
    save(output_path, fig, px_per_unit=2)
    println("Saved: ", output_path)

    # Display if interactive
    display(fig)
end