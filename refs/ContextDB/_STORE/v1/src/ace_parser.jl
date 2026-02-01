export parse_ace_text, parse_ace_sentence, statements_to_rdf, 
       export_to_turtle, ACEStatement, ACETriple

# Structure to represent parsed ACE statements
struct ACEStatement
    subject::String
    predicate::String
    object::String
    statement_type::Symbol  # :fact, :rule, :question, :existential
end

struct ACETriple
    subject::String
    predicate::String
    object::String
end

# Enhanced ACE grammar patterns
const ACE_PATTERNS = [
    # Existential statements: "There is a/an X", "There is X Y"
    r"^there\s+is\s+an?\s+([a-zA-Z0-9\-_]+)\s+([a-zA-Z0-9\-_]+)\.?$"i => :existential_typed,
    r"^there\s+is\s+an?\s+([a-zA-Z0-9\-_]+)\.?$"i => :existential_simple,
    
    # Simple facts: "Every X is a Y", "X is Y", "X is a Y"
    r"^every\s+([a-zA-Z0-9\-_]+)\s+is\s+a\s+([a-zA-Z0-9\-_]+)\.?$"i => :universal_fact,
    r"^([a-zA-Z0-9\-_]+)\s+is\s+a\s+([a-zA-Z0-9\-_]+)\.?$"i => :instance_fact,
    r"^([a-zA-Z0-9\-_]+)\s+is\s+the\s+([a-zA-Z0-9\-_]+)\.?$"i => :definite_fact,
    r"^([a-zA-Z0-9\-_]+)\s+is\s+([a-zA-Z0-9\-_]+)\.?$"i => :property_fact,
    
    # Complex relationships with composite predicates
    r"^([a-zA-Z0-9\-_]+)\s+([a-zA-Z0-9\-_]+)\s+([a-zA-Z0-9\-_]+)\.?$"i => :complex_relationship,
    
    # Property values: "X has Y Z", "X has-property value"
    r"^([a-zA-Z0-9\-_]+)\s+(has-[a-zA-Z0-9\-_]+)\s+([a-zA-Z0-9\.\-_]+)\.?$"i => :property_value,
    
    # Conditional rules with complex conditions
    r"^if\s+(.+)\s+then\s+(.+)\.?$"i => :conditional_rule,
    
    # Complex statements with "that" clauses
    r"^every\s+([a-zA-Z0-9\-_]+)\s+that\s+([a-zA-Z0-9\-_\s]+)\s+has\s+an?\s+([a-zA-Z0-9\-_]+)\s+that\s+is\s+an?\s+([a-zA-Z0-9\-_]+)\.?$"i => :complex_universal,
    
    # Derivation and computation statements
    r"^([a-zA-Z0-9\-_]+)\s+is\s+derived-from\s+([a-zA-Z0-9\-_]+)\.?$"i => :derivation,
    r"^([a-zA-Z0-9\-_]+)\s+(computes|visits|implements)\s+([a-zA-Z0-9\-_]+)\.?$"i => :action_relationship,
    
    # Containment and spatial relationships
    r"^([a-zA-Z0-9\-_]+)\s+is-contained-in\s+the\s+([a-zA-Z0-9\-_]+)\.?$"i => :containment,
    r"^([a-zA-Z0-9\-_]+)\s+is\s+(inside|outside)\s+the\s+([a-zA-Z0-9\-_]+)\.?$"i => :spatial_relationship
]

"""
Parse ACE text into structured statements
"""
function parse_ace_text(text::Union{String, SubString{String}})::Vector{ACEStatement}
    statements = ACEStatement[]
    
    # Split text into sentences, handling multiple line breaks
    sentences = split(strip(text), r"[.!?]+")
    
    for sentence in sentences
        sentence = String(strip(sentence))
        isempty(sentence) && continue
        
        statement = parse_ace_sentence(sentence)
        if statement !== nothing
            push!(statements, statement)
        end
    end
    
    return statements
end

"""
Parse a single ACE sentence
"""
function parse_ace_sentence(sentence::Union{String, SubString{String}})::Union{ACEStatement, Nothing}
    sentence = strip(sentence)
    
    for (pattern, type) in ACE_PATTERNS
        m = match(pattern, sentence)
        if m !== nothing
            return create_ace_statement(m, type)
        end
    end
    
    @warn "Could not parse ACE sentence: $sentence"
    return nothing
end

"""
Create ACE statement from regex match
"""
function create_ace_statement(m::RegexMatch, type::Symbol)::ACEStatement
    if type == :existential_typed
        # "There is a X Y" -> Y rdf:type X, and we create entity Y
        entity = String(m.captures[2])
        entity_type = String(m.captures[1])
        return ACEStatement(normalize_entity(entity), "rdf:type", normalize_entity(entity_type), :existential)
    elseif type == :existential_simple
        # "There is a X" -> X rdf:type Thing
        entity = m.captures[1]
        return ACEStatement(normalize_entity(entity), "rdf:type", "Thing", :existential)
    elseif type == :universal_fact
        # "Every X is a Y" -> X subClassOf Y
        return ACEStatement(normalize_entity(m.captures[1]), "rdfs:subClassOf", normalize_entity(m.captures[2]), :fact)
    elseif type == :instance_fact || type == :definite_fact
        # "X is a Y" or "X is the Y" -> X rdf:type Y
        return ACEStatement(normalize_entity(m.captures[1]), "rdf:type", normalize_entity(m.captures[2]), :fact)
    elseif type == :property_fact
        # "X is Y" -> X hasProperty Y
        return ACEStatement(normalize_entity(m.captures[1]), "hasProperty", normalize_entity(m.captures[2]), :fact)
    elseif type == :complex_relationship
        # "X predicate Y" -> X predicate Y
        subject = normalize_entity(m.captures[1])
        predicate = normalize_predicate(m.captures[2])
        object = normalize_entity(m.captures[3])
        return ACEStatement(subject, predicate, object, :fact)
    elseif type == :property_value
        # "X has-property value" -> X hasProperty value
        subject = normalize_entity(m.captures[1])
        predicate = normalize_predicate(m.captures[2])
        object = m.captures[3]  # Keep values as-is
        return ACEStatement(subject, predicate, object, :fact)
    elseif type == :derivation
        # "X is derived-from Y" -> X derivedFrom Y
        return ACEStatement(normalize_entity(m.captures[1]), "derivedFrom", normalize_entity(m.captures[2]), :fact)
    elseif type == :action_relationship
        # "X computes Y" -> X computes Y
        subject = normalize_entity(m.captures[1])
        predicate = normalize_predicate(m.captures[2])
        object = normalize_entity(m.captures[3])
        return ACEStatement(subject, predicate, object, :fact)
    elseif type == :containment
        # "X is-contained-in the Y" -> X containedIn Y
        return ACEStatement(normalize_entity(m.captures[1]), "containedIn", normalize_entity(m.captures[2]), :fact)
    elseif type == :spatial_relationship
        # "X is inside/outside the Y" -> X spatialRelation Y
        spatial_relation = m.captures[2] == "inside" ? "inside" : "outside"
        return ACEStatement(normalize_entity(m.captures[1]), spatial_relation, normalize_entity(m.captures[3]), :fact)
    elseif type == :complex_universal
        # Complex universal statements - simplified handling
        subject = normalize_entity(m.captures[1])
        object = normalize_entity(m.captures[4])
        return ACEStatement(subject, "hasComplexProperty", object, :fact)
    elseif type == :conditional_rule
        # Simple rule parsing
        condition = strip(m.captures[1])
        conclusion = strip(m.captures[2])
        return ACEStatement(condition, "implies", conclusion, :rule)
    end
    
    error("Unknown statement type: $type")
end

"""
Normalize entity names: convert hyphenated names to CamelCase or keep as-is
"""
function normalize_entity(entity::Union{String, SubString{String}})::String
    # Convert hyphenated names to CamelCase for classes, keep lowercase for instances
    if occursin(r"^[a-z][a-z0-9]*$", entity)
        # Simple lowercase names (likely instances) - keep as-is
        return entity
    elseif occursin("-", entity)
        # Hyphenated names - convert to CamelCase
        parts = split(entity, "-")
        return join([titlecase(part) for part in parts])
    else
        return entity
    end
end

"""
Normalize predicate names: convert to camelCase
"""
function normalize_predicate(predicate::Union{String, SubString{String}})::String
    if occursin("-", predicate)
        parts = split(predicate, "-")
        if length(parts) > 1
            return parts[1] * join([titlecase(part) for part in parts[2:end]])
        end
    end
    return predicate
end

"""
Convert ACE statements to RDF triples
"""
function statements_to_rdf(statements::Vector{ACEStatement})::Vector{ACETriple}
    triples = ACETriple[]
    
    for stmt in statements
        if stmt.statement_type in [:fact, :existential]
            # Create namespace-aware URIs
            subject_uri = create_uri(stmt.subject)
            predicate_uri = create_predicate_uri(stmt.predicate)
            object_uri = create_object_uri(stmt.object, stmt.predicate)
            
            push!(triples, ACETriple(subject_uri, predicate_uri, object_uri))
        elseif stmt.statement_type == :rule
            # For rules, create a simple implication triple
            push!(triples, ACETriple(stmt.subject, "implies", stmt.object))
        end
    end
    
    return triples
end

"""
Create URI for entities
"""
function create_uri(entity::String)::String
    return "ex:$entity"
end

"""
Create predicate URI
"""
function create_predicate_uri(predicate::String)::String
    if predicate == "rdf:type"
        return "rdf:type"
    elseif predicate == "rdfs:subClassOf"
        return "rdfs:subClassOf"
    else
        return "ex:$predicate"
    end
end

"""
Create object URI, handling literals vs entities
"""
function create_object_uri(object::String, predicate::String)::String
    # Check if object is likely a literal value (number, decimal, etc.)
    if occursin(r"^\d+(\.\d+)?$", object)
        return "\"$object\"^^xsd:decimal"
    elseif occursin(r"^\".*\"$", object)
        return object
    else
        return create_uri(object)
    end
end

"""
Export RDF triples to Turtle format
"""
function export_to_turtle(triples::Vector{ACETriple})::String
    turtle_content = """
@prefix ex: <http://example.org/> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

"""
    
    for triple in triples
        turtle_content *= "$(triple.subject) $(triple.predicate) $(triple.object) .\n"
    end
    
    return turtle_content
end
