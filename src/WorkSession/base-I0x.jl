# WorkSession base constructors (all I0x)

# Backward-compatible keyword constructor (formerly provided by @kwdef).
function Kernel.WorkSession(;
        label,
        stage,
        meta,
        simignore_rules = Dict{Symbol, Any}[],
        _settings_cache = Dict{String, Any}()
    )
    return Kernel.WorkSession(label, stage, meta, simignore_rules, _settings_cache)
end
