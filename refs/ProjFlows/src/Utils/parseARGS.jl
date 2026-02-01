function parseARGS(f::Function, key)
    for arg in ARGS
        startswith(arg, key) || continue
        val = last(arg, length(arg) - length(key))
        return f(val)
    end
    return f(nothing)
end
parseARGS(T::DataType, key) = parseARGS(key) do str
    isnothing(str) && error("ARG not found, key '", key, "'")
    parse(T, str)
end
parseARGS(key) = parseARGS(key) do str
    isnothing(str) && error("ARG not found, key '", key, "'")
    string(str)
end