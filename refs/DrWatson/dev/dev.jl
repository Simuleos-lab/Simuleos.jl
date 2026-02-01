import DrWatson
const DW = DrWatson

# NOTE: Waiting for julia issue
## ----------------------------------------------------------------------------------------
# function register_hints()
#     if isdefined(Base, :Experimental) && isdefined(Base.Experimental, :register_error_hint)

#         @info "isdefined"

#         # @require result_collection.jl methods
#         Base.Experimental.register_error_hint(LoadError) do io, exc, argtypes, kwargs

#             # #  collect_results, collect_results!
#             # if exc.f in (result_collection, result_collection!)
#             #     print(io, "\nYou may need to `using DataFrames`.")
#             # end
#             # if exc.f in (zeros, ones) && argtypes[1] <: Type{<:AbstractRGB}
#             #     print(io, "\nYou may need to `using DataFrames`.")
#             # end
#             print(io, "Hiiiiiadsdfasdfasdfsadfasdfasdfii")
#         end
        
#     end
# end

# register_hints()

## ----------------------------------------------------------------------------------------
DW.jhdc

## ----------------------------------------------------------------------------------------
module Hinter

    only_int(x::Int)      = 1
    any_number(x::Number) = 2

    function __init__()

        empty!(Base.Experimental._hint_handlers)

        # Documentation exmaple
        Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
            if exc.f == only_int
                # Color is not necessary, this is just to show it's possible.
                print(io, "\nDid you mean to call ")
                printstyled(io, "`any_number`?", color=:cyan)
            end
        end

        # Extra hints
        # Base.Experimental.register_error_hint(UndefVarError) do io, exc, argtypes, kwargs
        #     printstyled(io, "Hi, `UndefVarError`!", color=:cyan)
        # end

        Base.Experimental.register_error_hint(UndefVarError) do io::IO, ex::UndefVarError
            printstyled(io, "Hi, `UndefVarError`!", color=:cyan)
        end

    end

end

## ----------------------------------------------------------------------------------------
import Base
# Overwrite showerror
function Base.showerror(io::IO, ex::UndefVarError)
    print(io, "UndefVarError: $(ex.var) not defined")
    Base.Experimental.show_error_hints(io, ex)
end

## ----------------------------------------------------------------------------------------
# Documentation exmaple is working
Hinter.only_int(1.0)
#=
ERROR: LoadError: MethodError: no method matching only_int(::Float64)
HINT: Did you mean to call `any_number`?
Closest candidates are:
  only_int(::Int64) at /Users/Pereiro/.julia/dev/DrWatson/dev/dev.jl:34
Stacktrace:
 [1] top-level scope at /Users/Pereiro/.julia/dev/DrWatson/dev/dev.jl:64
 [2] include_string(::Function, ::Module, ::String, ::String) at ./loading.jl:1088
in expression starting at /Users/Pereiro/.julia/dev/DrWatson/dev/dev.jl:64
=#

## ----------------------------------------------------------------------------------------
# My custom custom hint isn't. 
# I hit an UndefVarError, but is failing to hint
Hinter.only_int2(1.0)
#=
ERROR: LoadError: UndefVarError: only_int2 not defined
Stacktrace:
[1] getproperty(::Module, ::Symbol) at ./Base.jl:26
[2] top-level scope at /Users/Pereiro/.julia/dev/DrWatson/dev/dev.jl:69
[3] include_string(::Function, ::Module, ::String, ::String) at ./loading.jl:1088
in expression starting at /Users/Pereiro/.julia/dev/DrWatson/dev/dev.jl:69
=#

## ----------------------------------------------------------------------------------------
@edit getproperty(Hinter, :only_int2)


## ----------------------------------------------------------------------------------------
# The dictionary is populated 
Base.Experimental._hint_handlers
#=
IdDict{Type,Array{Any,1}} with 3 entries:
  MethodError   => Any[#1]
  LoadError     => Any[#3]
  UndefVarError => Any[#2]
=#

## ----------------------------------------------------------------------------------------
# I can call my function
Base.Experimental._hint_handlers[UndefVarError][1](stdout, :bla, :bla, :bla)

## ----------------------------------------------------------------------------------------
# checking err type
try
    Hinter.only_int(1.0)
catch err
    @show typeof(err)
    rethrow(err)
end

## ----------------------------------------------------------------------------------------
# checking err type
try
    Hinter.only_int2(1.0)
catch err
    @show typeof(err)
    # rethrow(err)
    Base.Experimental.show_error_hints(stdout, err)
end

## ----------------------------------------------------------------------------------------