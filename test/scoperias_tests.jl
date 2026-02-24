using Test
using Simuleos

const SimuleosScope = Simuleos.Kernel.SimuleosScope

@testset "Scoperias filter_rules" begin
    base_scope = SimuleosScope(
        ["dev"],
        Dict{Symbol, Any}(
            :alpha => 1,
            :beta => 2,
            :gamma => 3
        ),
        Dict{Symbol, Any}()
    )

    rules = [
        Dict{Symbol, Any}(:regex => r"^a", :action => :exclude),
        Dict{Symbol, Any}(:regex => r"^a", :action => :include)
    ]
    filtered = Simuleos.Kernel.filter_rules(base_scope, rules)
    @test Simuleos.Kernel.hasvar(filtered, :alpha)
    @test Simuleos.Kernel.hasvar(base_scope, :alpha)

    scoped_rules = [
        Dict{Symbol, Any}(:regex => r"^b", :scope => "prod", :action => :exclude)
    ]
    filtered_dev = Simuleos.Kernel.filter_rules(base_scope, scoped_rules)
    @test Simuleos.Kernel.hasvar(filtered_dev, :beta)

    prod_scope = SimuleosScope(
        ["prod"],
        Dict{Symbol, Any}(
            :alpha => 1,
            :beta => 2
        ),
        Dict{Symbol, Any}()
    )
    filtered_prod = Simuleos.Kernel.filter_rules(prod_scope, scoped_rules)
    @test !Simuleos.Kernel.hasvar(filtered_prod, :beta)
    @test Simuleos.Kernel.hasvar(filtered_prod, :alpha)

    exclude_rule = [Dict{Symbol, Any}(:regex => r"^g", :action => :exclude)]
    filtered_exclude = Simuleos.Kernel.filter_rules(base_scope, exclude_rule)
    @test !Simuleos.Kernel.hasvar(filtered_exclude, :gamma)

    runtime_scope = SimuleosScope(
        ["dev"],
        Dict{Symbol, Any}(
            :x => 1,
            :f => string,
            :kmod => Simuleos.Kernel
        ),
        Dict{Symbol, Any}()
    )
    filtered_runtime = Simuleos.Kernel.filter_rules(runtime_scope, Dict{Symbol, Any}[])
    @test Simuleos.Kernel.hasvar(filtered_runtime, :x)
    @test !Simuleos.Kernel.hasvar(filtered_runtime, :f)
    @test !Simuleos.Kernel.hasvar(filtered_runtime, :kmod)

    include_runtime_rules = [
        Dict{Symbol, Any}(:regex => r"^f$", :action => :include),
        Dict{Symbol, Any}(:regex => r"^kmod$", :action => :include)
    ]
    filtered_runtime_include = Simuleos.Kernel.filter_rules(runtime_scope, include_runtime_rules)
    @test !Simuleos.Kernel.hasvar(filtered_runtime_include, :f)
    @test !Simuleos.Kernel.hasvar(filtered_runtime_include, :kmod)
end

@testset "Scoperias show" begin
    scope = SimuleosScope(
        ["s1", "s2"],
        Dict{Symbol, Any}(
            :x => 42,
            :y => [1, 2, 3]
        ),
        Dict{Symbol, Any}()
    )
    scope.metadata[:step] = 1
    scope.variables[:blobv] = Simuleos.Kernel.BlobScopeVariable(
        :local,
        "Dict",
        Simuleos.Kernel.BlobRef("0123456789abcdef")
    )
    scope.variables[:voidv] = Simuleos.Kernel.VoidScopeVariable(:global, "Any")
    scope.variables[:hashv] = Simuleos.Kernel.HashedScopeVariable(:local, "Vector{Int64}", "abcdef1234567890abcdef1234567890abcdef12")

    compact = sprint(show, scope)
    pretty = sprint(io -> show(io, MIME"text/plain"(), scope))

    @test occursin("SimuleosScope(labels=", compact)
    @test occursin("variables (5):", pretty)
    @test occursin("metadata:", pretty)
    @test occursin("blob:", pretty)
    @test occursin("void", pretty)
    @test occursin("hash:", pretty)
end
