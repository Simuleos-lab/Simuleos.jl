function _exportall(filter::Function, mod::Module)
    for sym in names(mod; all = true, imported = true)
        filter(sym) == true || continue
        @eval mod export $(sym)
    end
end

macro _exportall_underscore()
    return quote
        ProjFlows._exportall($(__module__)) do sym
            startswith(string(sym), r"@?_") && return true
            return false
        end
    end
end

macro _exportall_words()
    return quote
        ProjFlows._exportall($(__module__)) do sym
            sym == :eval && return false
            sym == :include && return false
            startswith(string(sym), r"@?[a-zA-Z]") && return true
            return false
        end
    end
end

macro _exportall_non_underscore()
    return quote
        ProjFlows._exportall($(__module__)) do sym
            sym == :eval && return false
            sym == :include && return false
            startswith(string(sym), r"@?[^_#]") && return true
            return false
        end
    end
end

macro _exportall_uppercase()
    return quote
        ProjFlows._exportall($(__module__)) do sym
            startswith(string(sym), r"@?[A-Z]") && return true
            return false
        end
    end
end

