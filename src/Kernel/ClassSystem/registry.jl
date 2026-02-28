# ============================================================
# classsystem/registry.jl — Semantic class metadata registry
# ============================================================

const _SIM_CLASS_ID_RE = r"^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*$"
const _SIM_CLASS_SPEC_RE = r"^([a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*)@v([1-9][0-9]*)$"

"""
    SimuleosClass{ID, V}

Parametric Julia class tag used for internal dispatch ergonomics.
`ID` is a `Symbol` semantic class id (for example `Symbol("snap.scope")`) and
`V` is a positive class version integer.
"""
struct SimuleosClass{ID, V} end

"""
    SimuleosClassFieldSpec(name, semantic_type; required=true)

Metadata-only field descriptor for a semantic class.
"""
struct SimuleosClassFieldSpec
    name::String
    semantic_type::String
    required::Bool
end

function SimuleosClassFieldSpec(
        name::AbstractString,
        semantic_type::AbstractString;
        required::Bool = true,
    )::SimuleosClassFieldSpec
    field_name = strip(String(name))
    isempty(field_name) && error("Class field name must be non-empty.")
    type_name = strip(String(semantic_type))
    isempty(type_name) && error("Class field semantic type must be non-empty.")
    return SimuleosClassFieldSpec(field_name, type_name, required)
end

"""
    SimuleosClassSpec

Metadata contract for one semantic class version.
"""
struct SimuleosClassSpec
    id::String
    version::Int
    compose_from::Vector{String}
    fields::Vector{SimuleosClassFieldSpec}
end

function _normalize_class_id(id::AbstractString)::String
    id_s = strip(String(id))
    occursin(_SIM_CLASS_ID_RE, id_s) || error(
        "Invalid class id `$(id_s)`. Expected dotted lowercase id like `snap.scope`."
    )
    return id_s
end

function _normalize_class_version(version::Integer)::Int
    v = Int(version)
    v > 0 || error("Invalid class version `$(version)`. Expected positive integer.")
    return v
end

class_spec_string(id::AbstractString, version::Integer)::String =
    string(_normalize_class_id(id), "@v", _normalize_class_version(version))

function _normalize_compose_from(compose_from)::Vector{String}
    refs = String[]
    seen = Set{String}()
    for ref in compose_from
        parsed = class_parse(String(ref))
        parsed.spec in seen && continue
        push!(refs, parsed.spec)
        push!(seen, parsed.spec)
    end
    return refs
end

function _normalize_field_specs(fields)::Vector{SimuleosClassFieldSpec}
    specs = SimuleosClassFieldSpec[]
    for field in fields
        if field isa SimuleosClassFieldSpec
            push!(specs, field)
            continue
        end
        if field isa NamedTuple
            keys = propertynames(field)
            (:name in keys && :semantic_type in keys) || error(
                "Field metadata NamedTuple must include `name` and `semantic_type`."
            )
            required = :required in keys ? Bool(getproperty(field, :required)) : true
            push!(specs, SimuleosClassFieldSpec(
                getproperty(field, :name),
                getproperty(field, :semantic_type);
                required = required,
            ))
            continue
        end
        error("Unsupported class field metadata entry type: $(typeof(field)).")
    end
    return specs
end

function SimuleosClassSpec(
        id::AbstractString,
        version::Integer;
        compose_from = String[],
        fields = SimuleosClassFieldSpec[],
    )::SimuleosClassSpec
    return SimuleosClassSpec(
        _normalize_class_id(id),
        _normalize_class_version(version),
        _normalize_compose_from(compose_from),
        _normalize_field_specs(fields),
    )
end

const _SIM_CLASS_REGISTRY = Dict{String, SimuleosClassSpec}()

"""
    class_parse(spec) -> NamedTuple

Parse a canonical semantic class spec string like `snap.scope@v1`.
Returns `(id, version, spec)`.
"""
function class_parse(spec::AbstractString)
    spec_s = strip(String(spec))
    m = match(_SIM_CLASS_SPEC_RE, spec_s)
    isnothing(m) && error(
        "Invalid class spec `$(spec_s)`. Expected format `name.space@vN` with lowercase ids."
    )
    id = _normalize_class_id(m.captures[1])
    version = _normalize_class_version(parse(Int, m.captures[2]))
    return (id = id, version = version, spec = class_spec_string(id, version))
end

SimuleosClass(id::AbstractString, version::Integer) =
    SimuleosClass{Symbol(_normalize_class_id(id)), _normalize_class_version(version)}()

SimuleosClass(spec::AbstractString) = begin
    parsed = class_parse(spec)
    SimuleosClass(parsed.id, parsed.version)
end

class_tag(id::AbstractString, version::Integer) = SimuleosClass(id, version)
class_tag(spec::AbstractString) = SimuleosClass(spec)

class_id(::SimuleosClass{ID, V}) where {ID, V} = String(ID)
class_version(::SimuleosClass{ID, V}) where {ID, V} = Int(V)
class_spec_string(cls::SimuleosClass{ID, V}) where {ID, V} = class_spec_string(String(ID), Int(V))

"""
    class_register!(spec::SimuleosClassSpec) -> SimuleosClassSpec

Register a semantic class metadata contract.
All `compose_from` references must already exist in the registry.
"""
function class_register!(spec::SimuleosClassSpec)::SimuleosClassSpec
    key = class_spec_string(spec.id, spec.version)
    haskey(_SIM_CLASS_REGISTRY, key) && error("Class `$(key)` is already registered.")

    for ref in spec.compose_from
        class_exists(ref) || error(
            "Class `$(key)` references unknown `compose_from` class `$(ref)`."
        )
    end

    _SIM_CLASS_REGISTRY[key] = spec
    return spec
end

function class_register!(
        id::AbstractString,
        version::Integer;
        compose_from = String[],
        fields = SimuleosClassFieldSpec[],
    )::SimuleosClassSpec
    spec = SimuleosClassSpec(id, version; compose_from = compose_from, fields = fields)
    return class_register!(spec)
end

function class_exists(id::AbstractString, version::Integer)::Bool
    key = class_spec_string(id, version)
    return haskey(_SIM_CLASS_REGISTRY, key)
end

function class_exists(spec_or_id::AbstractString)::Bool
    s = strip(String(spec_or_id))
    if !isnothing(match(_SIM_CLASS_SPEC_RE, s))
        parsed = class_parse(s)
        return haskey(_SIM_CLASS_REGISTRY, parsed.spec)
    end
    id = _normalize_class_id(s)
    return any(spec -> spec.id == id, values(_SIM_CLASS_REGISTRY))
end

function class_spec(id::AbstractString, version::Integer)::SimuleosClassSpec
    key = class_spec_string(id, version)
    haskey(_SIM_CLASS_REGISTRY, key) || error("Class `$(key)` is not registered.")
    return _SIM_CLASS_REGISTRY[key]
end

"""
    class_require!(id, version) -> SimuleosClassSpec

Assert a class is registered and return its metadata spec.
"""
class_require!(id::AbstractString, version::Integer)::SimuleosClassSpec = class_spec(id, version)

"""
    class_spec(spec_or_id::AbstractString) -> SimuleosClassSpec

If passed `name.space@vN`, returns that exact spec.
If passed `name.space`, requires exactly one registered version.
"""
function class_spec(spec_or_id::AbstractString)::SimuleosClassSpec
    s = strip(String(spec_or_id))
    if !isnothing(match(_SIM_CLASS_SPEC_RE, s))
        parsed = class_parse(s)
        return class_spec(parsed.id, parsed.version)
    end

    id = _normalize_class_id(s)
    matches = SimuleosClassSpec[spec for spec in values(_SIM_CLASS_REGISTRY) if spec.id == id]
    isempty(matches) && error("No registered class found for id `$(id)`.")
    if length(matches) > 1
        versions = sort!(Int[spec.version for spec in matches])
        error("Class id `$(id)` has multiple versions registered $(versions). Use `$(id)@vN`.")
    end
    return matches[1]
end

class_specs()::Vector{SimuleosClassSpec} = sort!(
    collect(values(_SIM_CLASS_REGISTRY));
    by = spec -> (spec.id, spec.version),
)

# Test/support helper.
function _class_registry_reset!()::Nothing
    empty!(_SIM_CLASS_REGISTRY)
    return nothing
end
