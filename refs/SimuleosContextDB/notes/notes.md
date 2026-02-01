## Note

- `ContextNode{KT, VT, DT}`
    - A supertype of the julia standard `Dict` interface

- On top of `Dict` the node will implement a flexible value resolution system. 
    - Flexible because you can change it or implement a custom one. 
        - Like julia `Vector` indexing interface. 

## Note

- `DefaultDict{String,Any}(Missing)` is a dict that will return Missing upon finding a non existing key.
- This way we can implement a dictionary where you can Chain key queries
- Also, If we create a typed default return `KeyMissingToken` we can overwrite some cool operators as `||` or `&&` so we can write
    - `dict["bla"]["blo"]["blu"] || 123`
        - This will return `123` is any key misses
    - `dict["bla", "blo", "blu"] || 123`
        - This is maybe better becase we can let the basic interface as the julia standard `Dict`
    - This is actualy a SimuleosBase.jl package

- Or alternatively, I should just extend the base Dict interface witha. full querying language.
    - `dict["bla"]`
        - Typical standard interface
    - `dict[r"^bla"]` or `dict["bla:blo:blu"]` for a nested search
    - you can actually change the indexing/quering protocole if you want!
