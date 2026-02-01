#=
Hi, I just include the show_error_hints part from #39089
Further relevant discussion in [discourse](https://discourse.julialang.org/t/help-with-register-error-hint/56140/4)
=#

function showerror(io::IO, ex::UndefVarError)
    print(io, "UndefVarError: $(ex.var) not defined")
    Experimental.show_error_hints(io, ex)
end

Experimental.register_error_hint(UndefVarError) do io::IO, ex::UndefVarError
    if ex.var in [:UTF16String, :UTF32String, :WString, :utf16, :utf32, :wstring, :RepString]
        println(io)
        print(io, """
            `$(ex.var)` has been moved to the package LegacyStrings.jl:
            Run Pkg.add("LegacyStrings") to install LegacyStrings on Julia v0.5-;
            Then do `using LegacyStrings` to get `$(ex.var)`.""")
    end
end

# Test
@test contains(sprint(Base.showerror, UndefVarError(:UTF16String)), "LegacyStrings")