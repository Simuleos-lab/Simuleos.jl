let
    P = Project0(ProjFlows)
    globproj!(P)
    fn_args = (["dev"], "test", ".jls")
    fn = projpath(fn_args...)
    try
        # write
        _didexec = false
        ref = datio(:write!, fn_args...) do
            _didexec = true
            :write!
        end
        @test _didexec
        @test !isempty(ref.cache)
        @test !isempty(ref.file)
        @test ref[] == :write!
        @test ref[] == :write!
        
        # read
        _didexec = false
        ref = datio(:read, fn_args...) do
            _didexec = true
            :read
        end
        @test !_didexec
        @test !isempty(ref.cache)
        @test !isempty(ref.file)
        @test ref[] == :write!
        @test ref[] == :write!
        
        # get
        # f() if !isfile
        _didexec = false
        ref = datio(:get, fn_args...) do
            _didexec = true
            :get
        end
        @test !_didexec
        @test !isempty(ref.cache)
        @test !isempty(ref.file)
        @test ref[] == :write! # file exist
        rm(fn; force = true)
        @assert !isfile(fn)
        _didexec = false
        ref = datio(:get, fn_args...) do
            _didexec = true
            :get
        end
        @test _didexec
        @test !isfile(ref)
        @test !isempty(ref.cache)
        @test isempty(ref.file)
        @test ref[] == :get

        # get!
        # isfile ? read : !write
        _didexec = false
        ref = datio(:get!, fn_args...) do
            _didexec = true
            :get!
        end
        @test _didexec
        @test !isempty(ref.cache)
        @test !isempty(ref.file)
        @test ref[] == :get!
        _didexec = false
        ref = datio(:get!, fn_args...) do
            _didexec = true
            get2!
        end
        @test !_didexec
        @test !isempty(ref.cache)
        @test !isempty(ref.file)
        @test ref[] == :get!
        @test ref[] == :get!
        @test ref.data == :get!

        # destructuring
        rm(fn; force = true)
        _didexec = false
        path, val = datio(:get!, fn_args...) do
            _didexec = true
            :get3!
        end
        @test _didexec
        @test path == fn
        @test val == :get3!

        # dry
        # maybe write and always cache
        _didexec = false
        ref = datio(:dry, fn_args...) do
            _didexec = true
            :dry
        end
        @test _didexec
        @test !isempty(ref)
        @test isempty(ref.file)
        @test ref[] == :dry

    finally
        rm(fn; force = true)
    end
end
