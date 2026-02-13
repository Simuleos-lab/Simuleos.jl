# Scoperias macros (I0x with respect to SimOs integration)
# Capture runtime scope directly from Julia locals/globals.

"""
    @scope_capture

Capture current local scope plus globals from `Main` into a label-less `Scope`.
Built-in filtering removes variables whose values are `Module` or `Function`.
"""
macro scope_capture()
    quote
        _locals = Base.@locals()

        _global_names = names(Main; imported = false)
        _globals = Dict{Symbol, Any}()
        for _name in _global_names
            if isdefined(Main, _name)
                _globals[_name] = getfield(Main, _name)
            end
        end

        _scope = Scope(String[], _locals, _globals)
        filter_vars!(_scope) do _var_name, _sv
            !(_sv.val isa Module) && !(_sv.val isa Function)
        end
        _scope
    end
end
