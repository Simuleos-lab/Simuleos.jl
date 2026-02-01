module LiteTapes

import MassExport

# Write your package code here.
using LiteRecords
using OrderedCollections
using Random
using UUIDs
using JSON3

#! include .

#! include Core
include("Core/0.types.jl")
include("Core/1.1.LiteTapeLib.base.jl")
include("Core/1.1.LiteTapeLib.tape.jl")
include("Core/1.2.LiteTapeRecord.base.jl")
include("Core/1.2.LiteTapeRecord.disk.jl")
include("Core/1.2.LiteTapeRecord.lite.jl")
include("Core/1.2.LiteTapeRecord.tape.jl")
include("Core/1.3.LiteTapeSegment.base.jl")
include("Core/1.3.LiteTapeSegment.disk.jl")
include("Core/1.3.LiteTapeSegment.lite.jl")
include("Core/1.3.LiteTapeSegment.tape.jl")

MassExport.@exportall_words

end