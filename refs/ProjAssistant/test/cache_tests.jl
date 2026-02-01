function cache_tests()
    
    @info "cache_tests"
    ProjAssistant.global_conf(:CACHE_DIR, tempdir())
    N = 15
    dat0 = rand(N)

    cfile = ProjAssistant.cfname("my_dat", N)
    cfile = ProjAssistant.scache(dat0, cfile)
    @test isfile(cfile)
    dat1 = ProjAssistant.lcache(cfile)
    @test all(dat0 .== dat1)
    ProjAssistant.delcache("my_dat", N)
    @test !isfile(cfile)

    cfile = ProjAssistant.scache(dat0, "my_dat", N)
    dat1 = ProjAssistant.lcache("my_dat", N)
    @test all(dat0 .== dat1)
    ProjAssistant.delcache("my_dat", N)
    @test !isfile(cfile)
    
    cfile = ProjAssistant.scache(() -> dat0, "my_dat", N)
    dat1 = ProjAssistant.lcache("my_dat", N)
    @test all(dat0 .== dat1)
    ProjAssistant.delcache(cfile)
    @test !isfile(cfile)
    
    cfile = ProjAssistant.scache(() -> dat0)
    dat1 = ProjAssistant.lcache(cfile)
    @test all(dat0 .== dat1)
    ProjAssistant.delcache(cfile)
    @test !isfile(cfile)
    
    cfile = ProjAssistant.scache(dat0)
    dat1 = ProjAssistant.lcache(cfile)
    @test all(dat0 .== dat1)
    ProjAssistant.delcache(cfile)
    @test !isfile(cfile)

end
cache_tests()