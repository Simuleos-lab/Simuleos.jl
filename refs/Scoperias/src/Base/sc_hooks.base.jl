## ..... -- ->- .- -- .. .. - . -_- .-
# MARK: sc_hook_query_hash

sc_hook_query_hash(query::Any, h0) = hash(query, h0)

function sc_hook_query_hash(query::Vector, h0)
    h = hash(h0)
    for el in query
        h = sc_hook_query_hash(el, h)
    end
    return h
end

## ..... -- ->- .- -- .. .. - . -_- .-
# MARK:  sc_sel_hook!
function sc_sel_hook!(f::Function, query::Vector, key::Int = 0)
    qhash = sc_hook_query_hash(query, UInt(0))
    __SC_SEL_HOOKS[(qhash, key)] = SC_HOOK(query, f)
    nothing
end

## ..... -- ->- .- -- .. .. - . -_- .-
# MARK:  sc_call_hook!
function sc_call_hook!(f::Function, query::Vector)
    qhash = sc_hook_query_hash(query, UInt(0))
    __SC_CALL_HOOKS[qhash] = SC_HOOK(query, f)
    nothing
end


## ..... -- ->- .- -- .. .. - . -_- .-
# MARK: sc_builtin_sel_hook
function sc_builtin_sel_hook(
    scv::SimuleosScopeVariable
)
    # key, val, src

    scv.key == "__SC_CONFIG" && return :ignore
    scv.key == "__SC_HOOKS" && return :ignore

    if sc_is_labelkey(scv.key)
        isempty(scv.val) && return :ignore
    end

    # include cheap stuff
    isa(scv.val, Char) && return :include
    isa(scv.val, Date) && return :include
    isa(scv.val, String) && return :include
    isa(scv.val, Symbol) && return :include
    isa(scv.val, Number) && return :include
    isa(scv.val, DateTime) && return :include
    isa(scv.val, VersionNumber) && return :include

    isa(scv.val, Module) && return :ignore
    isa(scv.val, Function) && return :ignore

    # TAI/ ignore by default non primitive globals
    # scv.src === :global && return :nullblob

    return nothing
end
## ..... -- ->- .- -- .. .. - . -_- .-
# MARK: sc_run_sel_hooks
function sc_run_sel_hooks(sc::Scope)
    
    # matched_hooks
    matched_hooks = SC_HOOK[]
    for hook in values(__SC_SEL_HOOKS)
        _sc_scope_match_all(hook, sc) || continue
        push!(matched_hooks, hook)
    end
    isempty(matched_hooks) && 
        error("No validation hook for this scope:\n$(sc)")



    # run hooks
    selected_scope = Dict{String, SimuleosScopeVariable}()
    for scv in values(sc)
        # run matched_hooks
        val_key = :unhandled
        for hook in matched_hooks
            ret = hook.fun(scv)
            isa(ret, Symbol) || continue
            val_key = ret
        end

        if val_key === :unhandled
            error("Unhandled variable! key \"$(scv.key)\", Type `$(typeof(scv.val))`, src '$(scv.src)'")
        elseif val_key == :ignore
            # noop
        elseif val_key == :include
            selected_scope[scv.key] = scv
        else
            error("Invalid val_key (check hook return variable)! val_key '$(val_key)', key \"$(scv.key)\", Type `$(typeof(scv.val))`, src '$(scv.src)'")
        end
    end
    return Scope(selected_scope)
end

## ..... -- ->- .- -- .. .. - . -_- .-
# MARK: sc_reset_sel_hooks!
function sc_reset_sel_hooks!(;builtin=true)
    empty!(__SC_SEL_HOOKS)
    builtin && sc_sel_hook!(sc_builtin_sel_hook, [])
    nothing
end

## ..... -- ->- .- -- .. .. - . -_- .-
# MARK: sc_reset_call_hooks!
function sc_reset_call_hooks!()
    empty!(__SC_CALL_HOOKS)
    nothing
end

#TODO/ Add queried reset!

## ..... -- ->- .- -- .. .. - . -_- .-
# MARK: sc_run_ret_hooks
function sc_run_ret_hooks(sc::Scope)
    for hook in values(__SC_CALL_HOOKS)
        _sc_scope_match_all(hook, sc) || continue
        return hook.fun(sc)
    end
end

## ..... -- ->- .- -- .. .. - . -_- .-
macro sc_call(lb="")
    quote 
        let
            # create label
            isempty($(lb)) || Scoperias.@sc_label $(lb)
            local rsc = Scoperias.@sc_rawscope()
            Scoperias.sc_check_for_local_label(rsc)
            local hsc = Scoperias.sc_run_sel_hooks(rsc)
            Scoperias.sc_run_ret_hooks(hsc)
        end
    end |> esc
end