#!/usr/bin/env julia

# Test script to verify settings migration to UXLayers

using Pkg
Pkg.activate("/Users/pereiro/.julia/dev/Simuleos")

using Simuleos

println("Testing Settings Migration to UXLayers")
println("=" ^ 60)

# Create test project
tmpdir = mktempdir()
mkdir(joinpath(tmpdir, ".simuleos"))

println("\n1. Setting up test environment...")
println("   Test project: $tmpdir")

# Write settings files
local_settings = joinpath(tmpdir, ".simuleos", "settings.json")
global_settings = joinpath(homedir(), ".simuleos", "settings.json")

write(local_settings, """{"local_key": "local_value", "shared_key": "local_wins"}""")

# Backup global settings if they exist
global_backup = nothing
if isfile(global_settings)
    global_backup = read(global_settings, String)
end

write(global_settings, """{"global_key": "global_value", "shared_key": "global_loses"}""")

try
    # Activate with args
    println("\n2. Activating project with args...")
    Simuleos.activate(tmpdir, Dict("args_key" => "args_value", "shared_key" => "args_wins"))

    # Test priority order
    println("\n3. Testing priority order...")

    # Args should win (highest priority)
    val = Simuleos.settings("args_key")
    @assert val == "args_value" "Failed: args_key should be 'args_value', got '$val'"
    println("   ✓ args_key = $val (args source)")

    val = Simuleos.settings("shared_key")
    @assert val == "args_wins" "Failed: shared_key should be 'args_wins', got '$val'"
    println("   ✓ shared_key = $val (args priority)")

    # Local should be next priority
    val = Simuleos.settings("local_key")
    @assert val == "local_value" "Failed: local_key should be 'local_value', got '$val'"
    println("   ✓ local_key = $val (local source)")

    # Global should be lowest priority
    val = Simuleos.settings("global_key")
    @assert val == "global_value" "Failed: global_key should be 'global_value', got '$val'"
    println("   ✓ global_key = $val (global source)")

    # Test defaults
    println("\n4. Testing default values...")
    val = Simuleos.settings("missing_key", "default_value")
    @assert val == "default_value" "Failed: missing_key with default should return 'default_value', got '$val'"
    println("   ✓ missing_key with default = $val")

    # Test error on missing without default
    println("\n5. Testing error on missing key...")
    error_thrown = false
    try
        Simuleos.settings("missing_key")
    catch e
        error_thrown = true
        println("   ✓ Correctly threw error: $(typeof(e))")
    end
    @assert error_thrown "Failed: should have thrown error for missing key without default"

    # Check UXLayers integration
    println("\n6. Checking UXLayers integration...")
    ux = Simuleos.SIMOS.ux
    @assert !isnothing(ux) "Failed: UXLayers view should not be nothing"
    @assert ux isa UXLayers._uxLayerView "Failed: ux should be a UXLayerView"
    println("   ✓ UXLayers view created: $(typeof(ux))")

    @assert UXLayers.isloaded(ux) "Failed: UXLayers should be loaded"
    println("   ✓ UXLayers is loaded")

    # Verify sources are loaded
    sources = UXLayers.sources(ux)
    @assert haskey(sources, :args) "Failed: :args source should be loaded"
    @assert haskey(sources, :local) "Failed: :local source should be loaded"
    @assert haskey(sources, :global) "Failed: :global source should be loaded"
    println("   ✓ All sources loaded: $(keys(sources))")

    # Verify priorities
    priorities = UXLayers.priorities(ux)
    @assert priorities == [:args, :local, :global] "Failed: priorities should be [:args, :local, :global], got $priorities"
    println("   ✓ Priority order correct: $priorities")

    println("\n" * "=" ^ 60)
    println("✓ All tests passed! Settings migration successful.")
    println("=" ^ 60)

finally
    # Cleanup
    println("\n7. Cleaning up...")
    rm(tmpdir, recursive=true)

    # Restore global settings
    if !isnothing(global_backup)
        write(global_settings, global_backup)
        println("   ✓ Restored global settings")
    else
        rm(global_settings, force=true)
        println("   ✓ Removed test global settings")
    end

    # Reset SIMOS
    Simuleos.reset_os!()
    println("   ✓ Reset SIMOS state")
end
