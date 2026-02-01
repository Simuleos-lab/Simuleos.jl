## DOING: Garbage Collection 

Because blobs are written eagerly:

* Some blobs may never be linked to a committed stage
* A future GC can safely remove blobs not referenced by any manifest

Garbage collection is explicitly **out of scope** for the MVP.


## DOING: Add a simignore
- a gitignore inspired file to exclude variable names
- can us regex over the names