# Create empty KG
export empty_kg
function empty_kg()
    return KnowledgeGraph(Dict{String, KGNode}(), KGRelation[])
end

# Helper to add nodes
export add_node!
function add_node!(kg::KnowledgeGraph, node::KGNode)
    kg.nodes[node.id] = node
    return node.id
end

# Helper to add relations
export add_relation!
function add_relation!(kg::KnowledgeGraph, source::String, relation::Symbol, target::String)
    push!(kg.relations, (source, relation, target))
end

# Generate unique IDs
let counter = 0
    global function next_id(prefix="node")
        counter += 1
        return "$(prefix)_$(counter)"
    end
end

# Parse Julia code and extract KG
export extract_kg
function extract_kg(code::String, file_path::String="<unknown>")
    kg = empty_kg()
    
    # Create a file node to represent the source file
    file_id = add_node!(kg, KGNode(
        next_id("file"),
        :File,
        file_path,
        Dict(:file => file_path, :start_line => 1, :end_line => count(c -> c == '\n', code) + 1),
        nothing,
        nothing
    ))
    
    # Parse the code
    expr = Meta.parse(code)
    
    # Process the AST
    process_expr!(kg, expr, file_id, file_path)
    
    return kg
end

# Print knowledge graph for visualization
export print_kg
function print_kg(kg::KnowledgeGraph)
    println("Knowledge Graph:")
    println("Nodes ($(length(kg.nodes))):")
    for (id, node) in kg.nodes
        println("  $id: $(node.kind) $(node.name !== nothing ? "'" * node.name * "'" : "")")
    end
    
    println("\nRelations ($(length(kg.relations))):")
    for (src, rel, tgt) in kg.relations
        src_name = kg.nodes[src].name !== nothing ? kg.nodes[src].name : src
        tgt_name = kg.nodes[tgt].name !== nothing ? kg.nodes[tgt].name : tgt
        println("  $src_name -[$rel]-> $tgt_name")
    end
end

# Export knowledge graph to RDF triples file
export export_kg_to_rdf
function export_kg_to_rdf(kg::KnowledgeGraph, filename::String; base_uri::String="http://contextdb.jl/kg#")
    # Ensure the directory exists
    dir_path = "data/ctx"
    mkpath(dir_path)
    
    # Full file path
    filepath = joinpath(dir_path, filename)
    
    # Open file for writing
    open(filepath, "w") do f
        # Write prefix declarations
        println(f, "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .")
        println(f, "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .")
        println(f, "@prefix ctx: <$base_uri> .")
        println(f, "")
        
        # Convert nodes to RDF
        for (id, node) in kg.nodes
            # Create node URI
            node_uri = "ctx:$(id)"
            
            # Write node type triple
            println(f, "$node_uri rdf:type ctx:$(node.kind) .")
            
            # Write node properties
            if node.name !== nothing
                println(f, "$node_uri ctx:name \"$(escape_string(node.name))\" .")
            end
            
            if node.signature !== nothing
                println(f, "$node_uri ctx:signature \"$(escape_string(node.signature))\" .")
            end
            
            if node.type !== nothing
                println(f, "$node_uri ctx:type \"$(escape_string(node.type))\" .")
            end
            
            # Write location information
            for (loc_key, loc_val) in node.location
                # Skip the file entry for brevity in output, unless it's the only location info
                if loc_key == :file && length(node.location) > 1
                    continue
                end
                println(f, "$node_uri ctx:$(loc_key) \"$(escape_string(string(loc_val)))\" .")
            end
            
            # Add blank line between nodes for readability
            println(f, "")
        end
        
        # Convert relations to RDF
        for (src, rel, tgt) in kg.relations
            src_uri = "ctx:$(src)"
            tgt_uri = "ctx:$(tgt)"
            println(f, "$src_uri ctx:$(rel) $tgt_uri .")
        end
    end
    
    @info "Knowledge graph exported to RDF file: $filepath"
    return filepath
end

# Utility to convert knowledge graph to Turtle-formatted string (for testing/debugging)
export kg_to_turtle
function kg_to_turtle(kg::KnowledgeGraph; base_uri::String="http://contextdb.jl/kg#")
    output = IOBuffer()
    
    # Write prefix declarations
    println(output, "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .")
    println(output, "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .")
    println(output, "@prefix ctx: <$base_uri> .")
    println(output, "")
    
    # Convert nodes to RDF
    for (id, node) in kg.nodes
        # Create node URI
        node_uri = "ctx:$(id)"
        
        # Write node type triple
        println(output, "$node_uri rdf:type ctx:$(node.kind) .")
        
        # Write node properties
        if node.name !== nothing
            println(output, "$node_uri ctx:name \"$(escape_string(node.name))\" .")
        end
        
        if node.signature !== nothing
            println(output, "$node_uri ctx:signature \"$(escape_string(node.signature))\" .")
        end
        
        if node.type !== nothing
            println(output, "$node_uri ctx:type \"$(escape_string(node.type))\" .")
        end
        
        # Write location information
        for (loc_key, loc_val) in node.location
            # Skip the file entry for brevity in output, unless it's the only location info
            if loc_key == :file && length(node.location) > 1
                continue
            end
            println(output, "$node_uri ctx:$(loc_key) \"$(escape_string(string(loc_val)))\" .")
        end
        
        # Add blank line between nodes for readability
        println(output, "")
    end
    
    # Convert relations to RDF
    for (src, rel, tgt) in kg.relations
        src_uri = "ctx:$(src)"
        tgt_uri = "ctx:$(tgt)"
        println(output, "$src_uri ctx:$(rel) $tgt_uri .")
    end
    
    return String(take!(output))
end

# Helper function to load an exported RDF file back into Julia (for verification)
export load_rdf_kg
function load_rdf_kg(filepath::String)
    # This is a stub - in a real implementation you would use a proper RDF library
    # like RDF.jl or a custom parser to read the RDF triples back into a KG structure
    @info "Loading RDF from $filepath"
    if !isfile(filepath)
        error("File not found: $filepath")
    end
    
    content = read(filepath, String)
    @info "Loaded $(count(c -> c == '\n', content)) lines from RDF file"
    return content
end