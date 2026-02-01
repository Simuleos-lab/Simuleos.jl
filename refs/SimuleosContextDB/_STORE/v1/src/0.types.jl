# Basic Knowledge Graph structure
export KGNode
mutable struct KGNode
    id::String
    kind::Symbol
    name::Union{String, Nothing}
    location::Dict{Symbol, Any}
    signature::Union{String, Nothing}
    type::Union{String, Nothing}
end

# Relations in our KG will be stored as (source_id, relation_type, target_id)
const KGRelation = Tuple{String, Symbol, String}

# Simple KG structure
export KnowledgeGraph
struct KnowledgeGraph
    nodes::Dict{String, KGNode}
    relations::Vector{KGRelation}
end