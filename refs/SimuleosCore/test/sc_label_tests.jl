import SimuleosCore: _gen_st_label_key, sc_is_labelkey
import SimuleosCore: @sc_label
                        

@testset "SimuleosScopeCore.label" begin
    # Test _gen_st_label_key
    @test typeof(_gen_st_label_key("foo")) == Symbol
    @test startswith(string(_gen_st_label_key("foo")), "sc_label_")

    # Test sc_is_labelkey
    @test !sc_is_labelkey("blu_label_abc")
    @test sc_is_labelkey("sc_label_abc")
    @test !sc_is_labelkey("label_abc")

    # Test sc_label macro
    @testset "sc_label macro" begin
        # The macro should create a variable with a name starting with sc_label_
        @sc_label "mylabel"
        sym = _gen_st_label_key("mylabel")
        @show isdefined(Main, sym) 
        return
        
    end

    # # Test _st_clear_mod_labels! macro
    # @testset "_st_clear_mod_labels! macro" begin
    #     @sc_label("anotherlabel")
    #     # Clear labels
    #     @_st_clear_mod_labels!(Main)
    #     # All sc_label_ variables should be set to ""
    #     for n in names(Main)
    #         if startswith(string(n), "sc_label_")
    #             @test getfield(Main, n) == ""
    #         end
    #     end
    # end
end