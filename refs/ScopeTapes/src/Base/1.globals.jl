export __ST
__ST::Union{ScopeTape, Nothing} = nothing

function __set__SC!(sc::ScopeTape)
    global __ST = sc;
end

export __ST_CONFIG
const __ST_CONFIG::OrderedDict{Regex, Dict{String, Any}} = OrderedDict(
    r"" => Dict()   # seed black as first
)

__ST_LK_FILE::Union{SimpleLockFile, Nothing} = nothing

# MARK: __ST_HOOKS
export __ST_HOOKS
const __ST_HOOKS::OrderedDict{Regex, OrderedDict{Int, Function}} = OrderedDict(
    r"" => OrderedDict()       # seed black as first
)