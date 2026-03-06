# ============================================================
# env.jl — Environment variable handling
# ============================================================

"""
    env_settings() -> Dict{String, Any}

Read all environment variables into a settings Dict, with keys as-is.
Key normalization and aliasing is handled by the settings registry.
"""
function env_settings()::Dict{String, Any}
    return Dict{String, Any}(_to_string_key(k) => v for (k, v) in ENV)
end

"""
    env_project_root() -> Union{String, Nothing}

Read project root from environment alias, or return nothing.
"""
function env_project_root()
    get(ENV, SETTING_ALIAS_PROJECT_ROOT_ENV, nothing)
end
