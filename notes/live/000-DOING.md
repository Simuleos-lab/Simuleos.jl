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