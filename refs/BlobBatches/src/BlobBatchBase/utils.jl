## --------------------------------------------------------
function _quoted_join(col, sep)
    strs = String[]
    for el in col
        push!(strs, string("\"", el, "\""))
    end
    return join(strs, sep)
end