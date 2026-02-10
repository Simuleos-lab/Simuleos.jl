# Core utilities shared across modules
# Includes lite data detection and metadata capture

# ==================================
# Lite Data Detection and Conversion (all I0x — pure type utilities)
# ==================================

const LITE_TYPES = Union{Bool,Int,Float64,String,Nothing,Missing,Symbol}

_is_lite(::LITE_TYPES) = true
_is_lite(::Any) = false

function _liteify(value::Bool)
    return value
end

function _liteify(value::Int)
    return value
end

function _liteify(value::Float64)
    return value
end

function _liteify(value::String)
    return value
end

function _liteify(::Nothing)
    return nothing
end

function _liteify(::Missing)
    return "__missing__"
end

function _liteify(value::Symbol)
    return string(value)
end

function _liteify(value::Any)
    error("Cannot liteify non-lite value of type $(typeof(value))")
end

