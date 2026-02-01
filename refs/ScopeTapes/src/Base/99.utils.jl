## --- . -. -- .- - - - .. . . . .- - -. . -. . 
# 'was here' (wh) flags are use for cheking previous runs
macro _tryvalue(sym::Symbol, dflt = nothing)
    return quote
        let
            local _val = $(dflt);
            try
                _val = $(sym)
            catch err  
                # println(err)
            end
            _val
        end
    end |> esc
end

## --- . -. -- .- - - - .. . . . .- - -. . -. . 
function _st_is_subset(sub::Dict, super::Dict)
    for (k0, v0) in sub
        haskey(super, k0) || return false
        super[k0] == v0 || return false
    end
    return true
end

## --- . -. -- .- - - - .. . . . .- - -. . -. . 
_lock(f::Function, arg0::Nothing, args...; kwargs...) = f()
_lock(f::Function, arg0::Any, args...; kwargs...) = lock(f, arg0, args...; kwargs...)

## --- . -. -- .- - - - .. . . . .- - -. . -. . 
function pretty_print_table_1(
    io::IO, 
    rows::Vector{<:Vector};
    printcell::Dict = Dict()
)

    ncols = maximum(length.(rows))
    
    # Normalize rows
    for row in rows
        while length(row) < ncols
            push!(row, "") 
        end
    end

    # Convert all cells to strings
    str_rows = [string.(row) for row in rows]

    # Determine max column widths
    col_widths = [maximum(length.(getindex.(str_rows, i))) for i in 1:ncols]

    # Apply formatting and print with styling
    for (ri, row) in enumerate(rows)
        for (ci, cell) in enumerate(row)
            cell = rpad(string(cell), col_widths[ci] + 2)
            c_fun = get(printcell, ci, print)
            rc_fun = get(printcell, (ri, ci), c_fun)
            rc_fun(io, cell)
        end
        println(io)
    end
end

## --- . -. -- .- - - - .. . . . .- - -. . -. . 