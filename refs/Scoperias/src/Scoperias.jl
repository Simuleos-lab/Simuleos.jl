
# 
module Scoperias

    using MassExport
    using Dates
    using JSON
    using SimpleLockFiles
    using OrderedCollections
    using SHA
    using JLD2
    using Serialization
    using StyledStrings

    #! include .
    
    #! include Base
    include("Base/0.types.jl")
    include("Base/1.globals.jl")
    include("Base/ScopeBase.jl")
    include("Base/ScopeVariableBase.jl")
    include("Base/label.queries.base.jl")
    include("Base/sc_extract.jl")
    include("Base/sc_hooks.base.jl")
    include("Base/sc_labels.jl")
    include("Base/sc_scopes.jl")
    
    #! include Record
    
    #! include Read

    @exportall_words()

    function __init__()
        sc_reset_sel_hooks!(;builtin=true)
    end

end