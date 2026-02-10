# Macro implementations for Simuleos Recorder

# I0x — pure macro helper
function _extract_symbols(expr)
    if expr isa Symbol
        return [expr]
    elseif expr isa Expr && expr.head == :tuple
        return [arg for arg in expr.args if arg isa Symbol]
    else
        return Symbol[]
    end
end

# Module references for use in macro-generated code
const _Recorder = Recorder
const _Kernel = Kernel
