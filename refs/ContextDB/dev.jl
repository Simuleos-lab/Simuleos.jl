let
    using SimuleosContextDB
end

## --.- .- . -.- - . . . -.- . - -- - -- . .,.-. -
# parsing julia code into a knowledge graph

let
    ##### Parse a string

    # str = " function foo(x::Int32, n::Int32)
    #     return mod(x, n)
    # end "
    
    # println("Parsing code:")
    # println(str)
    # println("\n")
    
    # # Extract knowledge graph from code
    # kg = extract_kg(str)
    
    # # Print the resulting KG
    # print_kg(kg)

    # # export to RDF triple
    # export_kg_to_rdf(kg, "testout")


    ##### Read code from a file

    file_path = "src/testfile.jl"
    file_content = read(file_path, String)
    
    println("\nParsing code from file:")
    println(file_content)
    println("\n")
    
    # Extract knowledge graph from file content
    kg_from_file = extract_kg(file_content)
    
    # Print the resulting KG
    print_kg(kg_from_file)
    
    # Export to RDF triple
    export_kg_to_rdf(kg_from_file, "testout_from_file")
    

    ##### Additional examples: lambda expressions

    # expr1 = Meta.parse("(x -> x + 2)")
    # expr2 = Meta.parse("5")
    # expr3 = Expr(:call, expr1, expr2)
    
    # println("\n\nParsing lambda expression:")
    # println(expr1)

    # kg_lambda = extract_kg(string(expr1))
    
    # print_kg(kg_lambda)
end

## --.- .- . -.- - . . . -.- . - -- - -- . .,.-. -
# parsing ACE english into a knowledge graph

let
    # Parsing ACE English into a knowledge graph
    println("=== ACE Parser Demo ===")

    # Example ACE text
    ace_text = """
    There is an experiment I1x.
    I1x is a Markov-chain-Monte-Carlo-experiment.
    I1x estimates pi.

    There is a target-distribution t1.
    t1 is a uniform-distribution.
    t1 is-defined-on the unit-square.
    I1x has-target t1.

    There is a chain c1.
    c1 implements I1x.
    c1 has-number-of-iterations 100000.
    c1 has-burn-in 10000.
    c1 has-random-seed 42.

    There is a point p0.
    p0 is inside the unit-square.
    c1 starts-at p0.

    There is a proposal q1.
    q1 is a symmetric-Gaussian-proposal.
    q1 has-standard-deviation 0.05.
    c1 uses q1.

    Every iteration that is-part-of c1 has a current-point that is a point.
    Every iteration that is-part-of c1 has a proposed-point that is a point.
    If a proposed-point of an iteration that is-part-of c1 is inside the unit-square then c1 accepts the proposed-point.
    If a proposed-point of an iteration that is-part-of c1 is outside the unit-square then c1 rejects the proposed-point.

    There is a region d1.
    d1 is the unit-disc.
    d1 is-contained-in the unit-square.

    I1x visits points with c1.
    A visited-point is a point that is visited-by c1.

    There is a ratio r1.
    r1 is the fraction-of visited-points that are inside d1.
    I1x computes r1.

    There is a pi-estimate e1.
    e1 is derived-from r1.
    I1x computes e1.

    e1 has-value 3.1416.
    e1 has-standard-error 0.0020.
    There is a confidence-interval ci1.
    ci1 has-level 0.95.
    ci1 has-lower 3.1370.
    ci1 has-upper 3.1462.
    e1 has-confidence-interval ci1.

    """

    println("Original ACE text:")
    # println(ace_text)
    println()

    # Parse ACE text
    statements = parse_ace_text(ace_text)

    println("Parsed ACE statements:")
    for (i, stmt) in enumerate(statements)
        println("$i. $(stmt.subject) --$(stmt.predicate)--> $(stmt.object) [$(stmt.statement_type)]")
    end
    println()

    # Convert to RDF triples
    rdf_triples = statements_to_rdf(statements)

    println("RDF Triples:")
    for (i, triple) in enumerate(rdf_triples)
        println("$i. $(triple.subject) $(triple.predicate) $(triple.object)")
    end
    println()

    # Export to Turtle format
    turtle_output = export_to_turtle(rdf_triples)

    println("Turtle/RDF output:")
    println(turtle_output)
end