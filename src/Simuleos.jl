module Simuleos

import MassExport

#! include .
include("0.types.jl")
include("scope.extract.jl")
include("scope.labels.jl")
include("scopes.base.jl")

MassExport.@exportall_words

end # module Simuleos