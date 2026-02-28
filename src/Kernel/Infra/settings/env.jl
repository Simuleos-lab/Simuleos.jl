# ============================================================
# env.jl — Environment variable handling
# ============================================================

const ENV_PREFIX = "SIMULEOS_"

"""
    env_settings() -> Dict{String, Any}

Read all SIMULEOS_* environment variables into a settings Dict.
Variable names are lowercased and `_` is replaced with `.` to form keys.
E.g., `SIMULEOS_PROJECT_ROOT` -> `"project.root"`.
"""
function env_settings()
    return _simuleos_parse_env(ENV)
end

function _simuleos_parse_env(env)::Dict{String, Any}
    settings = Dict{String, Any}()
    for (k, v) in env
        startswith(String(k), ENV_PREFIX) || continue
        key = lowercase(replace(String(k)[length(ENV_PREFIX)+1:end], "_" => "."))
        settings[key] = v
    end
    return settings
end

"""
    env_project_root() -> Union{String, Nothing}

Read SIMULEOS_PROJECT_ROOT from environment, or return nothing.
"""
function env_project_root()
    get(ENV, "SIMULEOS_PROJECT_ROOT", nothing)
end
