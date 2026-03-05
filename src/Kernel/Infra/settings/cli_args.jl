# ============================================================
# cli_args.jl — CLI argument parsing for settings
#
# Parses `--set key=value` and `--config path.json` from
# a Vector{String} of command-line arguments.
# ============================================================

"""
    _coerce_cli_value(s::String) -> Any

Coerce a CLI string value to the appropriate Julia type:
- "true"/"false" → Bool
- Integer pattern → Int
- Float pattern → Float64
- Otherwise → String
"""
function _coerce_cli_value(s::String)
    lower = lowercase(strip(s))
    lower == "true" && return true
    lower == "false" && return false
    lower == "nothing" && return nothing

    # Try integer
    int_val = tryparse(Int, s)
    !isnothing(int_val) && return int_val

    # Try float
    float_val = tryparse(Float64, s)
    !isnothing(float_val) && return float_val

    return s
end

"""
    parse_cli_args(args::Vector{String}) -> Dict{String, Any}

Parse CLI arguments into a flat settings Dict.

Supported forms:
- `--set key=value`   — set a single setting
- `--config path.json` — load all settings from a JSON file

Returns a Dict{String, Any} with flattened dotted keys.
"""
function parse_cli_args(args::Vector{String})::Dict{String, Any}
    result = Dict{String, Any}()
    i = 1
    while i <= length(args)
        arg = args[i]

        if arg == "--set"
            i + 1 > length(args) && error("--set requires a key=value argument.")
            kv = args[i + 1]
            eq_idx = findfirst('=', kv)
            isnothing(eq_idx) && error("--set value must be key=value, got: $(repr(kv))")
            key = _settings_validate_key(kv[1:eq_idx-1])
            val_str = kv[eq_idx+1:end]
            result[key] = _coerce_cli_value(val_str)
            i += 2
        elseif startswith(arg, "--set=")
            kv = arg[7:end]
            eq_idx = findfirst('=', kv)
            isnothing(eq_idx) && error("--set= value must be key=value, got: $(repr(kv))")
            key = _settings_validate_key(kv[1:eq_idx-1])
            val_str = kv[eq_idx+1:end]
            result[key] = _coerce_cli_value(val_str)
            i += 1
        elseif arg == "--config"
            i + 1 > length(args) && error("--config requires a file path argument.")
            path = args[i + 1]
            json_data = _settings_flatten_dict(_read_json_file(path))
            merge!(result, json_data)
            i += 2
        elseif startswith(arg, "--config=")
            path = arg[10:end]
            json_data = _settings_flatten_dict(_read_json_file(path))
            merge!(result, json_data)
            i += 1
        else
            # Skip unrecognized arguments
            i += 1
        end
    end
    return result
end

"""
    settings_source_add_args!(simos::SimOs, args::Vector{String}; after::Symbol=:session)

Parse CLI args and add them as a `:cli` settings layer.
"""
function settings_source_add_args!(simos::SimOs, args::Vector{String}; after::Symbol = :session)
    data = parse_cli_args(args)
    stack = _settings_stack_required(simos)

    existing_idx = _settings_stack_layer_index(stack, :cli)
    if !isnothing(existing_idx)
        layer = stack.layers[existing_idx]
        merge!(layer.data, data)
        for k in keys(data)
            layer.key_origin[k] = SETTINGS_SOURCE_TAG_CLI
        end
        _settings_stack_rebuild!(stack)
        return layer
    end

    layer = SettingsLayer(
        name = :cli,
        kind = :cli,
        is_mutable = false,
        persistent = false,
        origin = Dict{String, Any}(
            "source" => SETTINGS_SOURCE_TAG_CLI,
            "arg_count" => length(args),
        ),
        data = data,
    )
    _settings_insert_or_replace_layer!(stack, layer; after = after)
    return layer
end
