## DOING
- 4. Implement a real JMESPath.jl — full spec, register as a package, use it in Simuleos. More work, but it becomes a standalone contribution.
- And register on General.

## DOING
> `scope.bind`
- Scope here is also an historical remanent
- `bind` should work with anything that have variables into them
-- but lets discuss this later, lets focus on `hydrate`

> # Or combine: hydrate + bind in one step
- this sound nice, but lets discuss it later
- ignore

## DOING
- I want to create files with a context tag
- a hash (8 digits) with point to a context record on simuleos
- from there, we can rebuilt the context associated/registered with this items
- for instance, think about producing plots....


## DOING
- at sqlite sequential update
- we can extract even more context from trying to deserialize blobs
- like dict kesys and data types
- this is an extremely cold path, so, it should be ok...

## DONE
Read jsonl line by line, filter the line and later parse... this is faster...

## DOING 
- I want to mine my previous Simulations to extract usage cases patterns for SimuleOs...
- This way I can define the core features and design of SimuleOs based on real needs and use cases, rather than just theoretical ideas.
- I can also identify common workflows, pain points, and opportunities for automation that SimuleOs can address.
- I must create a skill and collect new data for this purpose, and then analyze it to derive insights for SimuleOs design.

## DOING: Connect setttings with stack system
- for instance `config.json` files..

## DOING: Check variable masking
- what if a global and local variable have the same name?
- propused-solution: append local after global at scope capturing time

## DOING: Garbage Collection 

Because blobs are written eagerly:

* Some blobs may never be linked to a committed stage
* A future GC can safely remove blobs not referenced by any manifest

Garbage collection is explicitly **out of scope** for the MVP.


## DONE: Add a simignore
- a gitignore inspired file to exclude variable names
- can us regex over the names-