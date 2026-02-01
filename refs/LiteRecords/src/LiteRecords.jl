#   # ##### ##### ####    ##### #####    ####  ##### #   # ####  #     #####
#  #  #     #     #   #     #     #     #        #   ## ## #   # #     #
###   ####  ####  ####      #     #      ###     #   # # # ####  #     ####
#  #  #     #     #         #     #         #    #   #   # #     #     #
#   # ##### ##### #       #####   #     ####   ##### #   # #     ##### #####


module LiteRecords

import MassExport

using OrderedCollections
using JSON3
using Random
using UUIDs

# using Distributions
# using LRUCache

#! include .

#! include Base

#! include Core
include("Core/0.types.jl")
include("Core/1.0.AbstractLiteObj.base.jl")
include("Core/1.1.AbstractLiteRecord._lite.jl")
include("Core/1.1.AbstractLiteRecord.base.jl")
include("Core/1.1.AbstractLiteRecord.lite.jl")
include("Core/1.2.AbstractLiteRecordArray._lite.jl")
include("Core/1.2.AbstractLiteRecordArray.base.jl")
include("Core/1.2.AbstractLiteRecordArray.lite.jl")
include("Core/1.3.LiteRecord.base.jl")
include("Core/1.4.BlobArray.base.jl")


MassExport.@exportall_words

end