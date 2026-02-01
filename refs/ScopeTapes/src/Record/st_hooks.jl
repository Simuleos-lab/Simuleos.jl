# TODO/ add more ts_class
# - Add ;cont class
#   - If present in the previous scope, it will be recycle

const __ST_SCV_ClASSES = [
    :ignored, :primitive, :unknown,
    :blob, :nullblob
]

# MARK: st_builtin_commit_hook
function st_builtin_commit_hook(
    scv::ScopeVariable, 
    sc::Scope
)
    # key, val, src, st_class

    scv.key == "__ST" && return :ignored
    scv.key == "__ST_CONFIG" && return :ignored
    scv.key == "__ST_HOOKS" && return :ignored
    scv.key == "ST_INIT_WH" && return :ignored
    scv.key == "ST_COMMIT_WH" && return :ignored

    if st_is_labelkey(scv.key)
        isempty(scv.val) && return :ignored
    end

    isa(scv.val, Char) && return :primitive
    isa(scv.val, Date) && return :primitive
    isa(scv.val, String) && return :primitive
    isa(scv.val, Symbol) && return :primitive
    isa(scv.val, Number) && return :primitive
    isa(scv.val, DateTime) && return :primitive
    isa(scv.val, VersionNumber) && return :primitive

    isa(scv.val, Module) && return :ignored
    isa(scv.val, Function) && return :ignored

    # TAI/ ignore by default non primitive globals
    scv.src === :glob && return :nullblob

    return scv.st_class
end

# MARK: st_reset_hooks!
function st_reset_hooks!()
    empty!(__ST_HOOKS)
    st_hook!(st_builtin_commit_hook, r"", 0)
    nothing
end


# MARK: st_hook!
"""
```julia
st_hook!(r"a.label.regex") do scv::ScopeVariable
    scv.src === :glob && return :pass
end
end
```
"""
function st_hook!(hook::Function, sc_regex::Regex, hook_id::Int)
    reg_hooks = get!(OrderedDict, __ST_HOOKS, sc_regex)
    reg_hooks[hook_id] = hook
    nothing
end

st_hook!(hook::Function, sc_regex::Regex) = st_hook!(hook, sc_regex, 1)
st_hook!(hook::Function, hook_id::Int) = st_hook!(hook, r"", hook_id)
st_hook!(hook::Function) = st_hook!(hook, r"", 1)

function _st_match_anylabel(
    sc_regex::Regex, 
    rawscope::Scope
)
    # force r"" to run always
    # even if no labels exist
    sc_regex == r"" && return true
    st_haslabel(rawscope, sc_regex)
end



# MARK: st_run_hooks!
function st_run_hooks!(
    ST::ScopeTape, 
    rawscope::Scope;
    docache = false
)
    hooked_scope = Dict{String, ScopeVariable}()
    for (key, scv) in rawscope
        
        scv.st_class = :unknown

        # run hooks
        for (sc_regex, hooks) in __ST_HOOKS
            _st_match_anylabel(sc_regex, rawscope) || continue
            for hook in values(hooks)
                ret = hook(scv, rawscope)
                ret === :pass && continue
                isa(ret, Symbol) || 
                    error("Invalid hook return value, type $(typeof(ret)), sc_regex: $(sc_regex)")
                scv.st_class = ret
            end
        end

        if scv.st_class === :primitive
            # value is store directly
            hooked_scope[key] = ScopeVariable(;
                key = scv.key, 
                val = scv.val, 
                jl_type = typeof(scv.val), 
                src = scv.src, 
                st_class = scv.st_class, 
                st_hash = nothing
            )
        elseif scv.st_class === :nullblob
            # value is ignored, only hash stored
            hooked_scope[key] = ScopeVariable(;
                key = scv.key, 
                val = nothing, 
                jl_type = typeof(scv.val), 
                src = scv.src, 
                st_class = scv.st_class, 
                st_hash = st_blob_hash(scv.val)
            )
        elseif scv.st_class === :blob
            # value is ignored, but blob is stored
            blob_hash = st_blob_hash(scv.val)
            if docache
                ST.recording_blob_cache[blob_hash] = scv.val
            end
            hooked_scope[key] = ScopeVariable(;
                key = scv.key, 
                val = nothing, 
                jl_type = typeof(scv.val), 
                src = scv.src, 
                st_class = scv.st_class, 
                st_hash = blob_hash
            )
        elseif scv.st_class === :ignored
            # noop
        elseif scv.st_class === :unknown
            error("Unhandled variable! key \"$(scv.key)\", Type `$(typeof(scv.val))`, src '$(scv.src)'")
        else
            error("Invalid st_class (check hook return variable)! st_class '$(scv.st_class)', key \"$(scv.key)\", Type `$(typeof(scv.val))`, src '$(scv.src)'")
        end
    end
    return Scope(hooked_scope)
end

function ts_isclass(scv::ScopeVariable, target)
    target in __ST_SCV_ClASSES || 
        error("Unknown target ts_class, target: $(target)")
    return scv.st_class == target
end

