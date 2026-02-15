# WorkSession base constructors (all I0x)

# Backward-compatible keyword constructor (formerly provided by @kwdef).
function Kernel.WorkSession(;
        session_id,
        labels = String[],
        stage,
        meta,
        simignore_rules = Dict{Symbol, Any}[],
        _settings_cache = Dict{String, Any}()
    )
    return Kernel.WorkSession(session_id, labels, stage, meta, simignore_rules, _settings_cache)
end
