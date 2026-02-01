export __SC_CONFIG
const __SC_CONFIG::OrderedDict{Regex, Dict{String, Any}} = OrderedDict(
    r"" => Dict()   # seed black as first
)

export __SC_SEL_HOOKS
const __SC_SEL_HOOKS::OrderedDict{Tuple{UInt, Int}, SC_HOOK} = OrderedDict()

export __SC_CALL_HOOKS
const __SC_CALL_HOOKS::OrderedDict{UInt, SC_HOOK} = OrderedDict()