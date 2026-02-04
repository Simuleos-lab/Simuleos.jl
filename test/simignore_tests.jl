using Test
using Simuleos

@testset "Simignore" begin
    @testset "Rule validation" begin
        # Create a minimal session for testing
        session = Simuleos.Session(
            label = "test",
            root_dir = mktempdir(),
            stage = Simuleos.Stage(),
            meta = Dict{String, Any}()
        )

        # Missing :regex should error
        @test_throws ErrorException Simuleos.set_simignore_rules!(session, [
            Dict(:action => :exclude)
        ])

        # Invalid :regex type should error
        @test_throws ErrorException Simuleos.set_simignore_rules!(session, [
            Dict(:regex => "not a regex", :action => :exclude)
        ])

        # Missing :action should error
        @test_throws ErrorException Simuleos.set_simignore_rules!(session, [
            Dict(:regex => r"test")
        ])

        # Invalid :action value should error
        @test_throws ErrorException Simuleos.set_simignore_rules!(session, [
            Dict(:regex => r"test", :action => :invalid)
        ])

        # Invalid :scope type should error
        @test_throws ErrorException Simuleos.set_simignore_rules!(session, [
            Dict(:regex => r"test", :action => :exclude, :scope => 123)
        ])

        # Valid rule should work
        Simuleos.set_simignore_rules!(session, [
            Dict(:regex => r"^_", :action => :exclude)
        ])
        @test length(session.simignore_rules) == 1
    end

    @testset "_should_ignore - type filtering" begin
        session = Simuleos.Session(
            label = "test",
            root_dir = mktempdir(),
            stage = Simuleos.Stage(),
            meta = Dict{String, Any}()
        )

        # Modules are always ignored
        @test Simuleos._should_ignore(session, :Base, Base, "scope1") == true

        # Functions are always ignored
        @test Simuleos._should_ignore(session, :println, println, "scope1") == true

        # Regular values are not ignored by default (no rules)
        @test Simuleos._should_ignore(session, :x, 42, "scope1") == false
        @test Simuleos._should_ignore(session, :data, [1, 2, 3], "scope1") == false
    end

    @testset "_should_ignore - global rules" begin
        session = Simuleos.Session(
            label = "test",
            root_dir = mktempdir(),
            stage = Simuleos.Stage(),
            meta = Dict{String, Any}()
        )

        # Set global exclude rule for variables starting with _
        Simuleos.set_simignore_rules!(session, [
            Dict(:regex => r"^_", :action => :exclude)
        ])

        # _temp should be ignored
        @test Simuleos._should_ignore(session, :_temp, 1, "any_scope") == true

        # result should not be ignored
        @test Simuleos._should_ignore(session, :result, 1, "any_scope") == false

        # _private should be ignored
        @test Simuleos._should_ignore(session, :_private, "secret", "other_scope") == true
    end

    @testset "_should_ignore - scope-specific rules" begin
        session = Simuleos.Session(
            label = "test",
            root_dir = mktempdir(),
            stage = Simuleos.Stage(),
            meta = Dict{String, Any}()
        )

        # Set scope-specific rule
        Simuleos.set_simignore_rules!(session, [
            Dict(:regex => r"debug", :action => :exclude, :scope => "production")
        ])

        # debug_info should be ignored in "production" scope
        @test Simuleos._should_ignore(session, :debug_info, 1, "production") == true

        # debug_info should NOT be ignored in "development" scope
        @test Simuleos._should_ignore(session, :debug_info, 1, "development") == false

        # other vars not affected
        @test Simuleos._should_ignore(session, :result, 1, "production") == false
    end

    @testset "_should_ignore - last rule wins" begin
        session = Simuleos.Session(
            label = "test",
            root_dir = mktempdir(),
            stage = Simuleos.Stage(),
            meta = Dict{String, Any}()
        )

        # First exclude all _temp*, then include _temp_keep
        Simuleos.set_simignore_rules!(session, [
            Dict(:regex => r"^_temp", :action => :exclude),
            Dict(:regex => r"^_temp_keep", :action => :include)
        ])

        # _temp should be excluded (only first rule matches)
        @test Simuleos._should_ignore(session, :_temp, 1, "scope") == true

        # _temp_data should be excluded (only first rule matches)
        @test Simuleos._should_ignore(session, :_temp_data, 1, "scope") == true

        # _temp_keep should be included (second rule wins)
        @test Simuleos._should_ignore(session, :_temp_keep, 1, "scope") == false

        # _temp_keep_extra should be included (both rules match, second wins)
        @test Simuleos._should_ignore(session, :_temp_keep_extra, 1, "scope") == false
    end

    @testset "_should_ignore - mixed global and scope rules" begin
        session = Simuleos.Session(
            label = "test",
            root_dir = mktempdir(),
            stage = Simuleos.Stage(),
            meta = Dict{String, Any}()
        )

        # Global: exclude all _*
        # Scope-specific: include _debug in "dev" scope
        Simuleos.set_simignore_rules!(session, [
            Dict(:regex => r"^_", :action => :exclude),
            Dict(:regex => r"^_debug", :action => :include, :scope => "dev")
        ])

        # _temp excluded everywhere
        @test Simuleos._should_ignore(session, :_temp, 1, "dev") == true
        @test Simuleos._should_ignore(session, :_temp, 1, "prod") == true

        # _debug included in dev (scope rule wins)
        @test Simuleos._should_ignore(session, :_debug, 1, "dev") == false

        # _debug excluded in prod (only global rule matches)
        @test Simuleos._should_ignore(session, :_debug, 1, "prod") == true
    end
end
