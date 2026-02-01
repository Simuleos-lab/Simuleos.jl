# DataFileNames

[![Build Status](https://github.com/josePereiro/DataFileNames.jl/workflows/CI/badge.svg)](https://github.com/josePereiro/DataFileNames.jl/actions)

## Description

Just a package for pretty naming data files.
It was inspired on [DrWatson](https://github.com/JuliaDynamics/DrWatson.jl) `savename` utility.

The main functionality is exporting two methods `dfname` and its "inverse" `parse_dfname`.
A "dfname" is form from three parts:

* **head**: a chain of values

* **params**: a chain of key:values pairs

* **ext**: a file extension

The name is then form as head + params + ext, separated by reserved characters.
`dfname` will check if all the values and key:values pairs are valid (e.g: do not contain a reserved separator char).

## Usage

### dfname

We use the types and order of the arguments passed to `dfname` as a way to communicate with the "engine".
You can use a key:pair type to indicate the end of the `head` and the start of the `params`.
The key:pair types are `Dict`, `Pair` and `NamedTuple`.

```julia
using DatafileNames

# There are multiple ways that this work
file = dfname("file_head", (;ϵ = rand(), B = "text"), ".jls")
@show file # file = "file_head [B=text ϵ=7.57e-01].jls"

file = dfname("file_head", :ϵ => rand(), "B" => :text, ".jls")
@show file # file = "file_head [B=text ϵ=4.09e-01].jls"

file = dfname("file_head", Dict(:ϵ => rand(), "B" => :text), ".jls")
@show file # file = "file_head [B=text ϵ=3.61e-01].jls"

# You can even mix styles
file = dfname("file_head", Dict(:ϵ => rand()), "B" => :text, (;C = 1), ".jls")
@show file # file = "file_head [B=text C=1 ϵ=8.03e-01].jls"

# You can miss any part
file = dfname((;ϵ = rand(), B = "text"), ".jls")
@show file # file = "[B=text ϵ=3.56e-01].jls"

file = dfname("just_head")
@show file # file = "just_head"

file = dfname(".ext")
@show file # file = ".ext"

# To enforce a parameterless name to have a extension you must provide 
# the prefix 
file = dfname("head_text", ".jpg")
@show file # file = "head_text.jpg"

# Other wise is taken as other head value
file = dfname("head_text", "jpg")
@show file # file = "head_text jpg"

# If params are present this is not necessary
file = dfname("head_text", (;A = 1), "jpg")
@show file # file = "head_text [A=1].jpg"

# But having multiple values after (or in between)
# params is an error
file = dfname("just_head", (;A = 1), "non_pair", (;B = 2), "jpg")
# ERROR: LoadError: After the first key:value argument no single value is allowed (except the extension at the end) [...]

# Or having params which lead to the same key
file = dfname("just_head", (;A = 1), (;A = 2), "jpg")
# ERROR: LoadError: You have passed two keys that lead to the same string 'A'. Collisions are not allowed [...]
```

### parse_arg

As you can see, `Symbol` and `Strings` are parsed similar and `Float64` is represented in scientific notation.
To change that, overwrite the method `parse_arg` for the type of interest.
The only requirement is that it must returns an object compatible with the basic types
[`Float64`, `Int`, `Bool`, `String`, `Symbol`].
If returns a key:value type, both the `keys` and `values` must be basic types.

An example using a custom type

```julia
import DataFileNames: parse_arg # You must explicitly import the method first
struct Foo
    f::Float64
    i::Int
    s::String
end
parse_arg(f::Foo) = (;f.f, f.i, f.s)

foo = Foo(1.0, 1, "hi")
file = dfname("head", foo, (;A = 1), "png")
@show file # file = "head [A=1 f=1.00e+00 i=1 s=hi].png"

# Note that in this example the type is implicitly converted into a key:pair type (a `NamedTuple`) and so it must behave as one.
file = dfname("head", foo, "not_a_pair", "png")
# ERROR: LoadError: After the first key:value argument no single value is allowed (except the extension at the end). [...]
```

If the first argument is a `Vector{<:AbstractString}` its content
will be feed to a `joinpath` and the rest again to `dfname`.

```julia
file = dfname(["dir1", "dir2"], "my_cool_file", (;A = 1), ".jls")
@show file = # file = "dir1/dir2/my_cool_file [A=1].jls"
```

'Simple' tuples are hashed. This is useful for quick unique data based file names.

```julia
file = dfname("comment", (1,2,3), ".ext")
@show file = # file = "comment [hash=0x83d91fbc7a900a8f].ext"
```

To avoid such behavior (if you wanna use a vector as part of the name) use an empty string.

```julia
# Empty strings are ignored in the construction of the name but are relevant in the arguments structure. Now the vector is taken as an ordinary argument and `parse_arg(v::Vector{String})` must be implemented
file = dfname("", ["dir1", "dir2"], "my_cool_file", (;A = 1), ".jls")
# ERROR: LoadError: parse_arg(v::Vector{String}) not implemented. Type `?parse_arg` for help.
```

### parse_dfname

`parse_dfname` take an String representing a `dfname` and returns a `NamedTuple (;head, params, ext)` with the content of the name.
If the name is invalid (you can tested using `isvalid_dfname`) the tuple will have empty values.
It is important to notice that `parse_dfname` uses `basename` first to ignore the rest of the path.

```julia
file = dfname(["dir1", "dir2"], "my_cool_file", (;A = 1), ".jls")
@show file # file = "dir1/dir2/my_cool_file [A=1].jls"
head, params, ext = parse_dfname(file)
@show head, params, ext # (["my_cool_file"], Dict{String, Any}("A" => 1), ".jls")
file = dfname(head..., params, ext)
@show file # file = "my_cool_file [A=1].jls"
```
