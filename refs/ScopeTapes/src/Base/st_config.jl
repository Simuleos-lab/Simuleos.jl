## .- .---- . -. -- .. .. -  .- -... - -- ...  -. -. .--. -..
# MARK: Get
st_config(reg::Regex) = __ST_CONFIG[reg]    
st_config() = st_config(r"")

# read only
function st_merged_config(
    rawscope::Scope
)
    conf = Dict{String, Any}()
    for (sc_regex, lconf) in __ST_CONFIG
        _st_match_anylabel(sc_regex, rawscope) || continue
        merge!(conf, lconf)
    end
    return conf
end


# read only
macro st_config()
    quote
        local rawscope = ScopeTapes.@st_rawscope()
        ScopeTapes.st_merged_config(rawscope)
    end |> esc
end

## .- .---- . -. -- .. .. -  .- -... - -- ...  -. -. .--. -..
# MARK: Set
function st_config!(f::Function, reg::Regex)
    global __ST_CONFIG
    lconf = get!(__ST_CONFIG, reg, Dict{String, Any}())
    f(lconf)
    return nothing
end
st_config!(f::Function) = st_config!(f, r"")

function st_config!(reg::Regex, pair0::Pair{String, <:Any}, pairs::Pair{String, <:Any}...)
    global __ST_CONFIG
    lconf = get!(__ST_CONFIG, reg, Dict{String, Any}())
    push!(lconf, pair0, pairs...)
    return nothing
end
st_config!(pair0::Pair{String, <:Any}, pairs::Pair{String, <:Any}...) = 
    st_config!(r"", pair0, pairs...)