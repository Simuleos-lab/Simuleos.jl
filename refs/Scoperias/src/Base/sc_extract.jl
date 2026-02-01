# TODO/ make extract/filtering interface
# ---.>._- - -. -->>> -- -_.... < - 

# macro _sc_extract(sc, keys::String...)
#     ex = nothing
#     for key in keys
#         @show key
#         ex = quote
#             $(ex)
#             $(Symbol(key)) = getindex($(sc), $(key))
#         end
#     end
#     ex |> esc
# end

# macro sc_extract(sc, keys::String...)
    
# end