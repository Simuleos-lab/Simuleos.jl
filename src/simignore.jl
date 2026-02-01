# Simignore: variable filtering (like .gitignore for Simuleos)
# STUB: No-op implementation for now

# Future: parse .simignore file and match patterns against variable names/types
function _should_ignore(session::Session, name::Symbol, val::Any)::Bool
    return false
end
