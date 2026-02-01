# It expects an extras(t::type)::Dict method which returns the real extras Dict

# TODO: Use this interface on MetX
# TODO: fix the name collisions (maybe a separate 'MetXInterfaces' package)

# const _EXTRAS_KEY_TYPE = Union{String, Symbol}
# const _EXTRAS_SUBKEYS_TYPE = Vector

# function _subkeys(obj::Any, keys::Vector) 
#     dict = extras(obj)::Dict
#     for key in keys
#         dict = dict[key]::Dict
#     end
#     return dict
# end

# exget(obj::Any, valkey::_EXTRAS_KEY_TYPE) = getindex(extras(obj), valkey)
# exget(obj::Any, valkey::_EXTRAS_KEY_TYPE, deft) = get(extras(obj), valkey, deft)
# exget(obj::Any, subkeys::_EXTRAS_SUBKEYS_TYPE, valkey::_EXTRAS_KEY_TYPE, deft) = get(_subkeys(obj, subkeys), valkey, deft)
# exget(obj::Any, subkeys::_EXTRAS_SUBKEYS_TYPE, valkey::_EXTRAS_KEY_TYPE) = _subkeys(obj, subkeys)[valkey]

# exget!(obj::Any, valkey::_EXTRAS_KEY_TYPE, deft) = get!(extras(obj), valkey, deft)
# exget!(obj::Any, subkeys::_EXTRAS_SUBKEYS_TYPE, valkey::_EXTRAS_KEY_TYPE, deft) = get!(_subkeys(obj, subkeys), valkey, deft)

# exget(f::Function, obj::Any, valkey::_EXTRAS_KEY_TYPE) = get(f, extras(obj), valkey)
# exget(f::Function, obj::Any, subkeys::_EXTRAS_SUBKEYS_TYPE, valkey::_EXTRAS_KEY_TYPE) = get(f, _subkeys(obj, subkeys), valkey)

# exget!(f::Function, obj::Any, valkey) = get!(f, extras(obj), valkey)
# exget!(f::Function, obj::Any, subkeys::_EXTRAS_SUBKEYS_TYPE, valkey::_EXTRAS_KEY_TYPE) = get!(f, _subkeys(obj, subkeys), valkey)

# exset!(obj::Any, valkey::_EXTRAS_KEY_TYPE, val) = setindex!(extras(obj), val, valkey)
# exset!(f::Function, obj::Any, valkey::_EXTRAS_KEY_TYPE) = setindex!(extras(obj), f(), valkey)
# exset!(obj::Any, subkeys::_EXTRAS_SUBKEYS_TYPE, valkey::_EXTRAS_KEY_TYPE, val) = setindex!(_subkeys(obj, subkeys), val, valkey)
# exset!(f::Function, obj::Any, subkeys::_EXTRAS_SUBKEYS_TYPE, valkey::_EXTRAS_KEY_TYPE) = setindex!(_subkeys(obj, subkeys), f(), valkey)

# exkeys(obj::Any) = keys(extras(obj))

# exdelete!(obj::Any, valkey::_EXTRAS_KEY_TYPE) = delete!(extras(obj), valkey)
# exdelete!(obj::Any, subkeys::_EXTRAS_SUBKEYS_TYPE, valkey::_EXTRAS_KEY_TYPE) = delete!(_subkeys(obj, subkeys), valkey)

# exhaskey(obj::Any, valkey::_EXTRAS_KEY_TYPE) = haskey(extras(obj), valkey)
# exhaskey(obj::Any, subkeys::_EXTRAS_SUBKEYS_TYPE, valkey::_EXTRAS_KEY_TYPE) = haskey(_subkeys(obj, subkeys), valkey)

# exempty!(obj::Any) = (empty!(extras(obj)); obj)