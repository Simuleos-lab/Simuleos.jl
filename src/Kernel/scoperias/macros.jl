# ============================================================
# scoperias/macros.jl — Scope capture macro
# ============================================================

"""
    @scope_capture

Capture all local and global variables in the current scope.
Returns a `SimuleosScope` with variables classified as :local or :global.
Module and Function values are excluded by default.
"""
macro scope_capture()
    # We need to capture at the caller's scope
    # Use Base.@locals for local variables
    # Global variables come from the calling module
    mod = __module__
    quote
        let
            _locals = Base.@locals
            _scope = $SimuleosScope()

            # Add local variables
            for (name, val) in _locals
                if $is_capture_excluded(val)
                    continue
                end
                _scope.variables[name] = $InlineScopeVariable(
                    :local, $type_short(val), val
                )
            end

            # Add global variables (from calling module)
            for name in names($mod; all=false)
                haskey(_scope.variables, name) && continue  # locals shadow globals
                isdefined($mod, name) || continue
                val = getfield($mod, name)
                if $is_capture_excluded(val)
                    continue
                end
                _scope.variables[name] = $InlineScopeVariable(
                    :global, $type_short(val), val
                )
            end

            _scope
        end
    end |> esc
end
