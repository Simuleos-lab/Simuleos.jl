# Scope processing utilities

using Dates
using ..Core: Session, Scope, ScopeVariable, _is_lite, _liteify

# Helper function to process scope from locals and globals
# Mutates scope in-place, populating variables
function _process_scope!(
    scope::Scope,
    session::Session,
    locals::Dict{Symbol, Any},
    globals::Dict{Symbol, Any},
    label::String,
    src_file::String,
    src_line::Int
)
    # Helper to process a single variable
    function process_var!(sym::Symbol, val::Any, src::Symbol)
        name = string(sym)
        src_type = first(string(typeof(val)), 25)  # truncate to 25 chars

        if sym in scope.blob_set
            hash = _write_blob(session, val)
            scope.variables[name] = ScopeVariable(
                name = name, src_type = src_type,
                value = nothing, blob_ref = hash, src = src
            )
        elseif _is_lite(val)
            scope.variables[name] = ScopeVariable(
                name = name, src_type = src_type,
                value = _liteify(val), blob_ref = nothing, src = src
            )
        else
            scope.variables[name] = ScopeVariable(
                name = name, src_type = src_type,
                value = nothing, blob_ref = nothing, src = src
            )
        end
    end

    # Process globals first (can be overridden by locals)
    for (sym, val) in globals
        _should_ignore(session, sym, val, label) && continue
        process_var!(sym, val, :global)
    end

    # Process locals (override globals if same name)
    for (sym, val) in locals
        _should_ignore(session, sym, val, label) && continue
        process_var!(sym, val, :local)
    end

    # Set scope metadata
    scope.label = label
    scope.timestamp = now()
    scope.isopen = false
    scope.data[:src_file] = src_file
    scope.data[:src_line] = src_line
    scope.data[:threadid] = Threads.threadid()

    return scope
end
