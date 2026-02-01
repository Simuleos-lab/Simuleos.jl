## ------------------------------------------------------------
# gen proj test
_TO_REMOVE = []
for fun_flag in [true, false]

    plot = ProjAssistant.ImgTools.Plots.plot
    RTAG = string(rand(UInt))
    TopMod = Symbol("Top", RTAG)
    Sub1Mod = Symbol("Sub1")
    Sub2Mod = Symbol("Sub2")
    Sub3Mod = Symbol("Sub3")
    TopDir = joinpath(tempdir(), string(TopMod))
    rm(TopDir; force = true, recursive = true)
    push!(_TO_REMOVE, TopDir)
    try
        # ---------------------------------------------------------------------
        # verbose
        ProjAssistant.global_conf(:VERBOSE, fun_flag)

        # ---------------------------------------------------------------------
        # prepare test "project"
        @info("Test project", TopMod, TopDir)
        @eval module $(TopMod)

            import ProjAssistant
            if $(fun_flag); ProjAssistant.gen_top_proj(@__MODULE__, $(TopDir))
                else; ProjAssistant.@gen_top_proj dir=$(TopDir)
            end
            
            function __init__()
                if $(fun_flag); ProjAssistant.create_proj_dirs(@__MODULE__)
                    else; ProjAssistant.@create_proj_dirs
                end
            end

            module $(Sub1Mod)

                import ProjAssistant
                if $(fun_flag); ProjAssistant.gen_sub_proj(@__MODULE__)
                    else; ProjAssistant.@gen_sub_proj
                end

                module $(Sub2Mod)
                    
                    module $(Sub3Mod)

                        import Main.$(TopMod).$(Sub1Mod)
                        import ProjAssistant
                        
                        if $(fun_flag); ProjAssistant.gen_sub_proj(@__MODULE__)
                            else; ProjAssistant.@gen_sub_proj(parent=$(Sub1Mod))
                        end

                        function __init__()
                            if $(fun_flag); ProjAssistant.create_proj_dirs(@__MODULE__)
                                else; ProjAssistant.@create_proj_dirs
                            end
                            
                        end
                    end
                end # module $(Sub2Mod)

                function __init__()
                    if $(fun_flag); ProjAssistant.create_proj_dirs(@__MODULE__)
                        else; ProjAssistant.@create_proj_dirs
                    end
                    
                end
            end # module $(Sub1Mod)
        end

        Top = getproperty(Main, TopMod)
        Sub1 = getproperty(Top, Sub1Mod)
        Sub2 = getproperty(Sub1, Sub2Mod)
        Sub3 = getproperty(Sub2, Sub3Mod)

        ## ------------------------------------------------------------
        # Test
        @testset "gen_projects" begin

            ## ------------------------------------------------------------
            # static funs
            for Proj in [Top, Sub1, Sub3]
                for funname in (
                        :projdir,
                        :devdir, :datdir, :srcdir, :plotsdir, :scriptsdir, :papersdir,
                        :procdir, :rawdir, :cachedir, 
                    )
                    fun = getproperty(ProjAssistant, funname)

                    df = fun(Proj, "bla", (;A = 1), "jls")
                    @test ProjAssistant.isvalid_dfname(df)
                    @test df == fun(Proj, basename(df))
                end

            end
            
            @test procdir(Top) != datdir(Top)
            @test procdir(Sub1) == datdir(Sub1)
            @test procdir(Sub3) == datdir(Sub3)

            @test istop_proj(Top)
            @test !istop_proj(Sub1)
            @test !istop_proj(Sub3)

            ## ------------------------------------------------------------
            @info("dirtree")
            for dirfun in [
                    devdir, datdir, srcdir, plotsdir, scriptsdir, papersdir,
                    procdir, rawdir, cachedir
                ]
                @test dirfun(Sub1) == dirname(dirfun(Sub3))
            end

            ## ------------------------------------------------------------
            # save/load data
            for Mod in [Top, Sub1, Sub3]

                @info("save/load data", Mod)
                mkdir = true
                for (sfun, lfun) in [
                        (sprocdat, lprocdat), 
                        (srawdat, lrawdat), 
                        (sdat, ldat)
                    ]

                    dat0 = rand(10, 10)

                    for fargs in [
                                ("test_file", (;h = hash(dat0)), "jls"),
                                (["subdir"], "test_file", (;h = hash(dat0)), "jls"),
                            ]

                        cfile1 = sfun(Mod, dat0, fargs...; mkdir)
                        @test isfile(cfile1)
                        dat1 = lfun(Mod, fargs...)
                        @test all(dat0 .== dat1)
                        dat1 = lfun(Mod, cfile1)
                        @test all(dat0 .== dat1)
                        cfile2 = sfun(Mod, dat0, basename(cfile1); mkdir)
                        @test basename(cfile1) == basename(cfile2)
                        dat1 = lfun(Mod, cfile2)
                        @test all(dat0 .== dat1)
                    end
                    
                    @test lfun(Mod, "NOT_A_FILE", hash(tempname()), ".jls") do
                        true
                    end
                end # for (sfun, lfun)
            end # for Mod

            ## ------------------------------------------------------------
            # save/load cache
            for Proj in [Top, Sub1, Sub3]

                @info("save/load cache", Proj)

                dat0 = rand(10, 10)
                
                cid = (:TEST, :CACHE, hash(dat0))
                cfile = scache(Proj, dat0, cid)
                @test isfile(cfile)
                dat1 = lcache(Proj, cid)
                @test all(dat0 .== dat1)
                
                cfile = scache(Proj, dat0)
                @test isfile(cfile)
                dat1 = lcache(Proj, cfile)
                @test all(dat0 .== dat1)

            end

            ## ------------------------------------------------------------
            # sglob/lglob
            for Proj in [Sub1, Sub3]

                @info("sglob/lglob", Proj)

                gfile = globfile(Proj, :test, :glob)
                rm(gfile; force = true)
                @assert !isfile(gfile)

                # funs
                dat0 = rand(10,10)
                sglob(Proj, dat0, :test, :glob)
                @test isfile(gfile)

                dat1 = lglob(Proj, :test, :glob)
                @test all(dat0 .== dat1)

                # macros
                rm(gfile; force = true)
                @assert !isfile(gfile)
                
                dat0 = rand(10,10)
                @sglob Proj test.glob=dat0
                @test isfile(gfile)

                @lglob Proj dat1=test.glob
                @test all(dat0 .== dat1)

            end

            ## ------------------------------------------------------------
            # save imgs
            for Proj in [Top, Sub1, Sub3]

                @info("save imgs", Proj)
                figfile0 = plotsdir(Proj, "test", (;A = 1), ".png")

                p = plot(rand(100))
                figfile1 = sfig(Proj, p, "test", (;A = 1), ".png")
                @test figfile0 == figfile1
                @test isfile(figfile1)

                ps = map((_) -> plot(rand(100)), 1:10)
                figfile1 = sfig(Proj, ps, "test", (;A = 1), ".png")
                @test figfile0 == figfile1
                @test isfile(figfile1)

                figfile0 = plotsdir(Proj, "test", (;A = 1), ".gif")
                figfile1 = sgif(Proj, ps, "test", (;A = 1), ".gif")
                @test figfile0 == figfile1
                @test isfile(figfile1)

            end

        end

    finally
        rm.(_TO_REMOVE; force = true, recursive = true)
    end
end