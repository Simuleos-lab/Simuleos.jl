using Test
using Simuleos
using UUIDs

function _empty_stage()::Simuleos.Kernel.ScopeStage
    return Simuleos.Kernel.ScopeStage()
end

function _test_worksession()::Simuleos.Kernel.WorkSession
    return Simuleos.Kernel.WorkSession(;
        session_id = uuid4(),
        labels = ["test"],
        stage = _empty_stage(),
        metadata = Dict{String, Any}(),
        simignore_rules = Dict{Symbol, Any}[],
    )
end

function _is_kept_after_filters(
        worksession::Simuleos.Kernel.WorkSession,
        name::Symbol,
        value,
        scope_label::AbstractString
    )::Bool
    scope = Simuleos.Kernel.SimuleosScope(
        [String(scope_label)],
        Dict{Symbol, Any}(name => value),
        Dict{Symbol, Any}()
    )
    filtered = Simuleos.WorkSession.apply_capture_filters(scope, worksession)
    return haskey(filtered.variables, name)
end

@testset "Simignore" begin
    @testset "Rule validation" begin
        worksession = _test_worksession()

        # Missing :regex should error
        @test_throws ErrorException Simuleos.WorkSession.set_simignore_rules!(worksession, [
            Dict(:action => :exclude)
        ])

        # Invalid :regex type should error
        @test_throws ErrorException Simuleos.WorkSession.set_simignore_rules!(worksession, [
            Dict(:regex => "not a regex", :action => :exclude)
        ])

        # Missing :action should error
        @test_throws ErrorException Simuleos.WorkSession.set_simignore_rules!(worksession, [
            Dict(:regex => r"test")
        ])

        # Invalid :action value should error
        @test_throws ErrorException Simuleos.WorkSession.set_simignore_rules!(worksession, [
            Dict(:regex => r"test", :action => :invalid)
        ])

        # Invalid :scope type should error
        @test_throws ErrorException Simuleos.WorkSession.set_simignore_rules!(worksession, [
            Dict(:regex => r"test", :action => :exclude, :scope => 123)
        ])

        # Valid rule should work
        Simuleos.WorkSession.set_simignore_rules!(worksession, [
            Dict(:regex => r"^_", :action => :exclude)
        ])
        @test length(worksession.simignore_rules) == 1
    end

    @testset "apply_capture_filters - type filtering" begin
        worksession = _test_worksession()

        # Modules are always ignored
        @test _is_kept_after_filters(worksession, :Base, Base, "scope1") == false

        # Functions are always ignored
        @test _is_kept_after_filters(worksession, :println, println, "scope1") == false

        # Include rules do not override baseline Module/Function filtering
        Simuleos.WorkSession.set_simignore_rules!(worksession, [
            Dict(:regex => r"^Base$", :action => :include),
            Dict(:regex => r"^println$", :action => :include)
        ])
        @test _is_kept_after_filters(worksession, :Base, Base, "scope1") == false
        @test _is_kept_after_filters(worksession, :println, println, "scope1") == false

        # Regular values are not ignored by default (no rules)
        Simuleos.WorkSession.set_simignore_rules!(worksession, Dict{Symbol, Any}[])
        @test _is_kept_after_filters(worksession, :x, 42, "scope1") == true
        @test _is_kept_after_filters(worksession, :data, [1, 2, 3], "scope1") == true
    end

    @testset "apply_capture_filters - global rules" begin
        worksession = _test_worksession()

        # Set global exclude rule for variables starting with _
        Simuleos.WorkSession.set_simignore_rules!(worksession, [
            Dict(:regex => r"^_", :action => :exclude)
        ])

        # _temp should be ignored
        @test _is_kept_after_filters(worksession, :_temp, 1, "any_scope") == false

        # result should not be ignored
        @test _is_kept_after_filters(worksession, :result, 1, "any_scope") == true

        # _private should be ignored
        @test _is_kept_after_filters(worksession, :_private, "secret", "other_scope") == false
    end

    @testset "apply_capture_filters - scope-specific rules" begin
        worksession = _test_worksession()

        # Set scope-specific rule
        Simuleos.WorkSession.set_simignore_rules!(worksession, [
            Dict(:regex => r"debug", :action => :exclude, :scope => "production")
        ])

        # debug_info should be ignored in "production" scope
        @test _is_kept_after_filters(worksession, :debug_info, 1, "production") == false

        # debug_info should NOT be ignored in "development" scope
        @test _is_kept_after_filters(worksession, :debug_info, 1, "development") == true

        # other vars not affected
        @test _is_kept_after_filters(worksession, :result, 1, "production") == true
    end

    @testset "apply_capture_filters - last rule wins" begin
        worksession = _test_worksession()

        # First exclude all _temp*, then include _temp_keep
        Simuleos.WorkSession.set_simignore_rules!(worksession, [
            Dict(:regex => r"^_temp", :action => :exclude),
            Dict(:regex => r"^_temp_keep", :action => :include)
        ])

        # _temp should be excluded (only first rule matches)
        @test _is_kept_after_filters(worksession, :_temp, 1, "scope") == false

        # _temp_data should be excluded (only first rule matches)
        @test _is_kept_after_filters(worksession, :_temp_data, 1, "scope") == false

        # _temp_keep should be included (second rule wins)
        @test _is_kept_after_filters(worksession, :_temp_keep, 1, "scope") == true

        # _temp_keep_extra should be included (both rules match, second wins)
        @test _is_kept_after_filters(worksession, :_temp_keep_extra, 1, "scope") == true
    end

    @testset "apply_capture_filters - mixed global and scope rules" begin
        worksession = _test_worksession()

        # Global: exclude all _*
        # Scope-specific: include _debug in "dev" scope
        Simuleos.WorkSession.set_simignore_rules!(worksession, [
            Dict(:regex => r"^_", :action => :exclude),
            Dict(:regex => r"^_debug", :action => :include, :scope => "dev")
        ])

        # _temp excluded everywhere
        @test _is_kept_after_filters(worksession, :_temp, 1, "dev") == false
        @test _is_kept_after_filters(worksession, :_temp, 1, "prod") == false

        # _debug included in dev (scope rule wins)
        @test _is_kept_after_filters(worksession, :_debug, 1, "dev") == true

        # _debug excluded in prod (only global rule matches)
        @test _is_kept_after_filters(worksession, :_debug, 1, "prod") == false
    end

    @testset "capture filter registry api" begin
        worksession = _test_worksession()
        wsmod = Simuleos.WorkSession

        wsmod.capture_filter_register!(worksession, "drop-debug", [
            Dict(:regex => r"^debug", :action => :exclude)
        ])
        wsmod.capture_filter_register!(worksession, Dict(
            "keep-debug-result" => [
                Dict(:regex => r"^debug_result$", :action => :include)
            ]
        ))

        wsmod.capture_filter_bind!(worksession, ["label1", "label2"] => ["drop-debug", "keep-debug-result"])
        wsmod.capture_filter_bind!(worksession, "label1", ["keep-debug-result"])

        @test worksession.capture_filter_bindings["label1"] == ["drop-debug", "keep-debug-result"]
        @test worksession.capture_filter_bindings["label2"] == ["drop-debug", "keep-debug-result"]

        snap = wsmod.capture_filters_snapshot!(worksession)
        @test isempty(snap.global_rules)
        @test haskey(snap.filters, "drop-debug")
        @test snap.label_to_filters["label2"] == ["drop-debug", "keep-debug-result"]

        wsmod.set_simignore_rules!(worksession, [
            Dict(:regex => r"^_", :action => :exclude)
        ])
        snap2 = wsmod.capture_filters_snapshot!(worksession)
        @test length(snap2.global_rules) == 1

        @test_throws ErrorException wsmod.capture_filter_register!(worksession, "bad", [
            Dict(:regex => r"x", :action => :exclude, :scope => "prod")
        ])
        @test_throws ErrorException wsmod.capture_filter_bind!(worksession, "label3", ["missing-filter"])

        wsmod.capture_filters_reset!(worksession)
        @test isempty(worksession.simignore_rules)
        @test isempty(worksession.capture_filter_defs)
        @test isempty(worksession.capture_filter_bindings)
    end
end
