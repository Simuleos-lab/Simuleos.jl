using Test
using Simuleos

@testset "Simignore" begin
    @testset "Rule validation" begin
        # Create a minimal recorder for testing
        recorder = Simuleos.Kernel.SessionRecorder(
            label = "test",
            stage = Simuleos.Kernel.Stage(),
            meta = Dict{String, Any}()
        )

        # Missing :regex should error
        @test_throws ErrorException Simuleos.Recorder.set_simignore_rules!(recorder, [
            Dict(:action => :exclude)
        ])

        # Invalid :regex type should error
        @test_throws ErrorException Simuleos.Recorder.set_simignore_rules!(recorder, [
            Dict(:regex => "not a regex", :action => :exclude)
        ])

        # Missing :action should error
        @test_throws ErrorException Simuleos.Recorder.set_simignore_rules!(recorder, [
            Dict(:regex => r"test")
        ])

        # Invalid :action value should error
        @test_throws ErrorException Simuleos.Recorder.set_simignore_rules!(recorder, [
            Dict(:regex => r"test", :action => :invalid)
        ])

        # Invalid :scope type should error
        @test_throws ErrorException Simuleos.Recorder.set_simignore_rules!(recorder, [
            Dict(:regex => r"test", :action => :exclude, :scope => 123)
        ])

        # Valid rule should work
        Simuleos.Recorder.set_simignore_rules!(recorder, [
            Dict(:regex => r"^_", :action => :exclude)
        ])
        @test length(recorder.simignore_rules) == 1
    end

    @testset "_should_ignore - type filtering" begin
        recorder = Simuleos.Kernel.SessionRecorder(
            label = "test",
            stage = Simuleos.Kernel.Stage(),
            meta = Dict{String, Any}()
        )

        # Modules are always ignored
        @test Simuleos.Recorder._should_ignore(recorder, :Base, Base, "scope1") == true

        # Functions are always ignored
        @test Simuleos.Recorder._should_ignore(recorder, :println, println, "scope1") == true

        # Regular values are not ignored by default (no rules)
        @test Simuleos.Recorder._should_ignore(recorder, :x, 42, "scope1") == false
        @test Simuleos.Recorder._should_ignore(recorder, :data, [1, 2, 3], "scope1") == false
    end

    @testset "_should_ignore - global rules" begin
        recorder = Simuleos.Kernel.SessionRecorder(
            label = "test",
            stage = Simuleos.Kernel.Stage(),
            meta = Dict{String, Any}()
        )

        # Set global exclude rule for variables starting with _
        Simuleos.Recorder.set_simignore_rules!(recorder, [
            Dict(:regex => r"^_", :action => :exclude)
        ])

        # _temp should be ignored
        @test Simuleos.Recorder._should_ignore(recorder, :_temp, 1, "any_scope") == true

        # result should not be ignored
        @test Simuleos.Recorder._should_ignore(recorder, :result, 1, "any_scope") == false

        # _private should be ignored
        @test Simuleos.Recorder._should_ignore(recorder, :_private, "secret", "other_scope") == true
    end

    @testset "_should_ignore - scope-specific rules" begin
        recorder = Simuleos.Kernel.SessionRecorder(
            label = "test",
            stage = Simuleos.Kernel.Stage(),
            meta = Dict{String, Any}()
        )

        # Set scope-specific rule
        Simuleos.Recorder.set_simignore_rules!(recorder, [
            Dict(:regex => r"debug", :action => :exclude, :scope => "production")
        ])

        # debug_info should be ignored in "production" scope
        @test Simuleos.Recorder._should_ignore(recorder, :debug_info, 1, "production") == true

        # debug_info should NOT be ignored in "development" scope
        @test Simuleos.Recorder._should_ignore(recorder, :debug_info, 1, "development") == false

        # other vars not affected
        @test Simuleos.Recorder._should_ignore(recorder, :result, 1, "production") == false
    end

    @testset "_should_ignore - last rule wins" begin
        recorder = Simuleos.Kernel.SessionRecorder(
            label = "test",
            stage = Simuleos.Kernel.Stage(),
            meta = Dict{String, Any}()
        )

        # First exclude all _temp*, then include _temp_keep
        Simuleos.Recorder.set_simignore_rules!(recorder, [
            Dict(:regex => r"^_temp", :action => :exclude),
            Dict(:regex => r"^_temp_keep", :action => :include)
        ])

        # _temp should be excluded (only first rule matches)
        @test Simuleos.Recorder._should_ignore(recorder, :_temp, 1, "scope") == true

        # _temp_data should be excluded (only first rule matches)
        @test Simuleos.Recorder._should_ignore(recorder, :_temp_data, 1, "scope") == true

        # _temp_keep should be included (second rule wins)
        @test Simuleos.Recorder._should_ignore(recorder, :_temp_keep, 1, "scope") == false

        # _temp_keep_extra should be included (both rules match, second wins)
        @test Simuleos.Recorder._should_ignore(recorder, :_temp_keep_extra, 1, "scope") == false
    end

    @testset "_should_ignore - mixed global and scope rules" begin
        recorder = Simuleos.Kernel.SessionRecorder(
            label = "test",
            stage = Simuleos.Kernel.Stage(),
            meta = Dict{String, Any}()
        )

        # Global: exclude all _*
        # Scope-specific: include _debug in "dev" scope
        Simuleos.Recorder.set_simignore_rules!(recorder, [
            Dict(:regex => r"^_", :action => :exclude),
            Dict(:regex => r"^_debug", :action => :include, :scope => "dev")
        ])

        # _temp excluded everywhere
        @test Simuleos.Recorder._should_ignore(recorder, :_temp, 1, "dev") == true
        @test Simuleos.Recorder._should_ignore(recorder, :_temp, 1, "prod") == true

        # _debug included in dev (scope rule wins)
        @test Simuleos.Recorder._should_ignore(recorder, :_debug, 1, "dev") == false

        # _debug excluded in prod (only global rule matches)
        @test Simuleos.Recorder._should_ignore(recorder, :_debug, 1, "prod") == true
    end
end
