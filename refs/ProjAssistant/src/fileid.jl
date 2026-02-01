function _fileid_reg()
    dig = "\\d"
    num_seps = "[\\.-]"
    id_sep = "[\\b-_]"
    return Regex("^(?<id>(?:$(dig)$(num_seps))*(?:$(dig)$(num_seps))$(id_sep)).*\$")
end

const _FILEID_REG = _fileid_reg()

function _get_file_id(fname::AbstractString)
    fname = basename(fname)
    m = match(_FILEID_REG, fname)
    return isnothing(m) ? "" : m[:id]
end

macro fileid()
    quote
        local file = $(string(__source__.file))
        $(_get_file_id)(file)
    end
end