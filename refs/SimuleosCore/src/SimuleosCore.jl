module SimuleosCore

#! include .

import SimuleosBase
import SimuleosBase: MassExport
using OrderedCollections

#! include Core
include("Core/0.types.jl")

#! include SimuleosScopeCore
include("SimuleosScopeCore/label.jl")

MassExport.@exportall_words

end