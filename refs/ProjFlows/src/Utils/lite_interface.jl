# TODO: Move to ProjFlows?
# This interface determine if an object is lite or not
# overwrite to change definition

islite(::Any) = false    # fallback
islite(::Number) = true
islite(::Symbol) = true
islite(::DateTime) = true
islite(::VersionNumber) = true
islite(::Nothing) = true
islite(s::AbstractString) = length(s) < 256

macro litescope(prefix="")
    return quote
        local _scope = @scope($(prefix))
        filter!(_scope) do p
            islite(last(p)) || return false
            startswith(string(first(p)), "_") && return false
            return true
        end
        _scope
    end
end

## TODO/ DEPRECATE litecontext
## - create a configurable context collection system
## - Update litecontext usage

macro litecontext()
    return quote
        local _scope = @scope()
        filter!(_scope) do p
            last(p) isa Module && return false
            last(p) isa Function && return false
            startswith(string(first(p)), "_") && return false
            return true
        end
        for (k, v) in _scope
            v = islite(v) ? v : hash(v)
            _scope[k] = v
        end
        _scope
    end
end

macro context()
    return quote
        local _scope = @scope()
        filter!(_scope) do p
            last(p) isa Module && return false
            last(p) isa Function && return false
            startswith(string(first(p)), "_") && return false
            return true
        end
        for (k, v) in _scope
            _scope[k] = v
        end
        _scope
    end
end

CONTEXT_CONFIG = Dict(
    "type.include.filtes" => Function[

    ],
    "ider.include.filter" => Function[

    ]
)