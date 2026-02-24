# ============================================================
# shared.jl — In-memory shared scope registry (MVP)
# ============================================================

function _shared_key(key)::String
    k = strip(String(key))
    isempty(k) && error("@simos shared key must be a non-empty string.")
    return k
end

function _shared_registry()::Dict{String, _Kernel.SimuleosScope}
    sim = _Kernel._get_sim()
    return sim.shared_scopes
end

function _shared_source_value(
        name::Symbol,
        locals::AbstractDict{Symbol, Any},
        globals::AbstractDict{Symbol, Any},
    )
    if haskey(locals, name)
        return locals[name]
    end
    if haskey(globals, name)
        return globals[name]
    end
    error("Variable `$(name)` not found in local or global scope.")
end

function _shared_make_scope_variable(name::Symbol, value)
    inline_vars = Set{Symbol}([name])
    blob_vars = Set{Symbol}()
    hash_vars = Set{Symbol}()
    return _Kernel._make_scope_variable(
        :shared, value, inline_vars, blob_vars, hash_vars, name, nothing
    )
end

function _shared_capture_build_scope(
        key::String,
        locals::AbstractDict{Symbol, Any},
        globals::AbstractDict{Symbol, Any},
        src_file::String,
        src_line::Int;
        names::Union{Nothing, Vector{Symbol}} = nothing,
    )::_Kernel.SimuleosScope
    scope = _Kernel.SimuleosScope()

    if isnothing(names)
        for (name, val) in locals
            _Kernel.is_capture_excluded(val) && continue
            scope.variables[name] = _shared_make_scope_variable(name, val)
        end
        for (name, val) in globals
            haskey(scope.variables, name) && continue
            _Kernel.is_capture_excluded(val) && continue
            scope.variables[name] = _shared_make_scope_variable(name, val)
        end
    else
        for name in names
            val = _shared_source_value(name, locals, globals)
            _Kernel.is_capture_excluded(val) && continue
            scope.variables[name] = _shared_make_scope_variable(name, val)
        end
    end

    pushfirst!(scope.labels, key)
    scope.metadata[:shared_key] = key
    scope.metadata[:src_file] = src_file
    scope.metadata[:src_line] = src_line
    scope.metadata[:threadid] = Threads.threadid()
    return scope
end

function shared_capture(
        key::AbstractString,
        locals::AbstractDict{Symbol, Any},
        globals::AbstractDict{Symbol, Any},
        src_file::String,
        src_line::Int;
        names::Union{Nothing, Vector{Symbol}} = nothing,
    )::_Kernel.SimuleosScope
    sim = _Kernel._get_sim()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Call `@simos session.init(...)` first.")

    key_s = _shared_key(key)
    scope = _shared_capture_build_scope(key_s, locals, globals, src_file, src_line; names=names)
    scope = apply_capture_filters(scope, ws)
    sim.shared_scopes[key_s] = scope
    return scope
end

function shared_get(key::AbstractString)::_Kernel.SimuleosScope
    reg = _shared_registry()
    key_s = _shared_key(key)
    haskey(reg, key_s) || error("Shared scope `$(key_s)` not found.")
    return reg[key_s]
end

function shared_keys()::Vector{String}
    reg = _shared_registry()
    return sort!(collect(keys(reg)))
end

function shared_has(key::AbstractString)::Bool
    reg = _shared_registry()
    return haskey(reg, _shared_key(key))
end

function shared_drop!(key::AbstractString)::Bool
    reg = _shared_registry()
    key_s = _shared_key(key)
    if haskey(reg, key_s)
        delete!(reg, key_s)
        return true
    end
    return false
end

function shared_clear!()::Int
    reg = _shared_registry()
    n = length(reg)
    empty!(reg)
    return n
end

function shared_merge!(dest_key::AbstractString, src_key::AbstractString)::_Kernel.SimuleosScope
    reg = _shared_registry()
    dest_s = _shared_key(dest_key)
    src_scope = shared_get(src_key)

    dest_scope = get!(reg, dest_s) do
        scope = _Kernel.SimuleosScope(dest_s)
        scope.metadata[:shared_key] = dest_s
        scope
    end

    for (name, var) in src_scope.variables
        dest_scope.variables[name] = var
    end

    return dest_scope
end
