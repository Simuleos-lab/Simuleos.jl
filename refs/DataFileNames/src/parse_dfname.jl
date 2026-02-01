# -------------------------------------------------------------------
_tryparse(T, v) = tryparse(T, v)
_tryparse(::Type{String}, v) = string(v)

_parse_key(k) = string(k)
function _parse_val(v::AbstractString)
    for T in _OUTPUT_VAL_TYPES
        r = _tryparse(T, v)
        !isnothing(r) && return r
    end
    return string(v)
end

function _parse_pair(p::AbstractString)
    dig = split(p, _SEPS[:PAIR_SEP])
    length(dig) == 2 || return nothing
    return (_parse_key(first(dig)) => _parse_val(last(dig)))
end

# -------------------------------------------------------------------
# function _parse_dfname(dfn::String, ondigest::Function)
#     dfn = basename(dfn)
#     head_str, params_str, ext_str, digest = _parse_regex(dfn)
#     !isempty(digest) && return ondigest(dfn, digest)
    
#     keepempty = false
#     head_split = split(head_str, _SEPS[:ELEMT_SEP]; keepempty) .|> string
#     params_split = split(params_str, _SEPS[:ELEMT_SEP]; keepempty) .|> string
    
#     return (;
#         head = _parse_val.(head_split),
#         params = Dict{String, Any}(_parse_pair.(params_split)...),
#         ext = string(ext_str)
#     )
# end

_noerr(x...) = nothing
function _parse_dfname(dfn::String, ondigest::Function)
    _check__SEPS()

    dfn = basename(dfn)
    
    # containers
    head = []
    params = Dict{String, Any}()
    ext = ""

    # empty string
    isempty(dfn) && return (;head, params, ext)

    # escape 
    ESC_SEPS = _hex_escaped_seps()
    hex_plsep = ESC_SEPS[:PARAMS_LSEP] |> Regex
    hex_prsep = ESC_SEPS[:PARAMS_RSEP] |> Regex
    hex_elsep = ESC_SEPS[:ELEMT_SEP] |> Regex
    hex_extsep = ESC_SEPS[:EXT_SEP] |> Regex

    # first digest
    dig = split(dfn, hex_elsep; keepempty = false)
    
    # extenssion
    # if "blo<<bla=1>>.ext", extract ".ext"
    # if "bla.ext", extract ".ext"
    # if "bla", extract ""
    ext_dig = split(last(dig), hex_prsep; keepempty = false)
    ext_str = string(last(ext_dig))
    if startswith(ext_str, hex_extsep)
        ext = ext_str
    else
        ext_dig = split(last(dig), hex_extsep; keepempty = false)
        ext = length(ext_dig) > 1 ?
            (last(dig)[max(end - length(last(ext_dig)), 1):end]) :
            ""
    end

    # redigest
    if !isempty(ext)
        dfn = dfn[1:end - length(ext)]
        dig = split(dfn, hex_elsep; keepempty = false)
    end

    # head
    for _ in eachindex(dig)
        startswith(first(dig), hex_plsep) && break
        str = first(dig)
        str = _check_str(str, _noerr)
        isnothing(str) && return ondigest(dfn, dig)
        push!(head, _parse_val(str))
        popfirst!(dig)
    end

    # params
    if !isempty(dig)
        dig[1] = replace(dig[1], hex_plsep => "")
        dig[end] = replace(dig[end], hex_prsep => "")
        for _ in eachindex(dig)
            str = first(dig)
            param = _parse_pair(str)
            isnothing(param) && return ondigest(dfn, dig)
            push!(params, param)
            popfirst!(dig)
        end
    end

    !isempty(dig) && return ondigest(dfn, dig)

    return (;head, params, ext)

end

## -------------------------------------------------------------------
_isvalid_dfname_ondigest(dfn, digest) = true
function isvalid_dfname(dfn::String)
    dfn = basename(dfn)
    digflag = _parse_dfname(dfn, _isvalid_dfname_ondigest)
    return digflag !== true
end

## ------------------------------------------------------
_error_ondigest(dfn, digest) = error("Invalid name '", dfn, "'. Digest: '", digest, "'")
parse_dfname(dfn::String) = _parse_dfname(dfn::String, _error_ondigest)

_nothing_ondigest(dfn, digest) = nothing
tryparse_dfname(dfn::String) = _parse_dfname(dfn::String, _nothing_ondigest)

## ------------------------------------------------------
dfheads(dfname::String) = parse_dfname(dfname)[1]
dfparams(dfname::String) = parse_dfname(dfname)[2]
dfparam(dfname::String, k::String) = dfparams(dfname)[k]
dfparam(dfname::String, k::String, dft) = get(dfparams(dfname), k, dft)
dfext(dfname::String) = parse_dfname(dfname)[3]
