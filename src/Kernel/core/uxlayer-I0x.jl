# UXLayer source loading (all I0x - pure settings I/O helpers)

"""
    _load_settings_json(path::String)::Dict{String, Any}

I0x - pure file I/O

Load settings from a JSON file. Returns empty dict if file doesn't exist.
Errors on malformed JSON.
"""
function _load_settings_json(path::String)::Dict{String, Any}
    if !isfile(path)
        return Dict{String, Any}()
    end

    content = read(path, String)
    if isempty(strip(content))
        return Dict{String, Any}()
    end

    # Parse JSON - will error on malformed JSON
    parsed = JSON3.read(content, Dict{String, Any})
    return parsed
end
