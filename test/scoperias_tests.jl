using Test
using Simuleos

const SimuleosScope = Simuleos.Kernel.SimuleosScope

global __scoperia_global_value = 11
global __scoperia_collision = :global
global __scoperia_global_module = Simuleos.Kernel
global __scoperia_global_function = string

@testset "Scoperias capture macro" begin
    let __scoperia_local_value = 22, __scoperia_collision = :local
        scope = Simuleos.Kernel.@scope_capture

        @test scope isa SimuleosScope
        @test isempty(scope.labels)

        @test Simuleos.Kernel.hasvar(scope, :__scoperia_local_value)
        @test Simuleos.Kernel.hasvar(scope, :__scoperia_global_value)

        @test scope.variables[:__scoperia_local_value] isa Simuleos.Kernel.InMemoryScopeVariable
        @test scope.variables[:__scoperia_local_value].value == 22
        @test scope.variables[:__scoperia_local_value].src == :local

        @test scope.variables[:__scoperia_global_value].value == 11
        @test scope.variables[:__scoperia_global_value].src == :global

        @test scope.variables[:__scoperia_collision].value == :local
        @test scope.variables[:__scoperia_collision].src == :local

        @test !Simuleos.Kernel.hasvar(scope, :__scoperia_global_module)
        @test !Simuleos.Kernel.hasvar(scope, :__scoperia_global_function)
    end
end

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
