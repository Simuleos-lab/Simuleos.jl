function register_hints()
    if isdefined(Base, :Experimental) && isdefined(Base.Experimental, :register_error_hint)

        # # @require result_collection.jl methods
        # Base.Experimental.register_error_hint(UndefVarError) do io, exc, argtypes, kwargs

        #     #  collect_results, collect_results!
        #     if exc.f in (result_collection, result_collection!)
        #         print(io, "\nYou may need to `using DataFrames`.")
        #     end
        #     if exc.f in (zeros, ones) && argtypes[1] <: Type{<:AbstractRGB}
        #         print(io, "\nYou may need to `using DataFrames`.")
        #     end
        # end
        
    end
end