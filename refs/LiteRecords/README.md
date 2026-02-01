# LiteRecords

- **LiteRecords.jl** is a Julia implementation of the **The Tara Project** specs.
- It defines a minimal, predictable interface for lite record manipulation.
- It focuses on flexible but simple dictionary-like operations.
- It avoids imposing additional semantics on top of the TaraSON representation.
- The goal is to provide a clean substrate for systems like **LiteTapes** and **ContextRecorders**.

## Usage

`LiteRecord` is a lightweight container that behaves like a dictionary and guarantees TaraSON compatibility.

### Creating a LiteRecord

```julia
using LiteRecords

# Empty record
r = LiteRecord()

# Construct from Dict
r = LiteRecord(Dict("a" => 1, "b" => 2))

# Construct from pairs
r = LiteRecord(["x" => 42, "y" => 99])

# Construct from NamedTuple
r = LiteRecord((foo = "bar", spam = 123))
````

### Basic Operations

```julia
# Setting and getting values
r["a"] = 1
r["b"] = 2
@show r["a"]      # 1

# Check if a key exists
@show haskey(r, "a")  # true

# Delete a key
delete!(r, "a")

# Get with default
val = get(r, "missing", 0)  # returns 0 if not found

# Merge with another Dict or record
merge!(r, Dict("z" => 100))
```

### Iteration

`LiteRecord` supports the standard Julia iteration interface and yields `Pair{String,Any}` objects:

```julia
for (k, v) in r
    println("key=$k, value=$v")
end

for kv in r
    @show kv  # kv is a Pair
end
```

You can also obtain `keys`, `values`, and `pairs`:

```julia
ks = keys(r)
vs = values(r)
ps = pairs(r)
```

### Convenience Helpers

Optional helpers for positional access:

```julia
nth = lite_nthkey(r, 1)     # get the first key
nthp = lite_nthpair(r, 1)   # get the first key=>value pair
```

### Extending LiteRecords

To define a custom lite container, implement `record_dict(::YourType)`:

```julia
struct MyLiteRecord <: AbstractLiteRecord
    store::Dict{String,Any}
end

record_dict(x::MyLiteRecord) = x.store

# MyLiteRecord now inherits dictionary-like behavior
mb = MyLiteRecord(Dict("foo" => 1))
@show mb["foo"]  # works like LiteRecord
```

This allows specialized record types to reuse the full Tier-0 interface.
