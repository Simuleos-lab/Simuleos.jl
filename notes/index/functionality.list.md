## TODO: add here a list of functionalities
- for instance, memoization, replay, diffing, etc.

# Tape Rewrite System
- sometimes we nedd to rewrite the data from a tape
- usage case:
    - new tape format
    - bug fix in tape format
    - consolidation
        - a first tape version might be optimized for quick collection
        - but, later on, we may want to optimize for storage space
        - importantly, this is not an index
        - it is not for having both formats at the same time
        - but, rather, for having one format at a time
        - and being able to migrate from one format to another
        - for instance, the initial format may store all data inline
        - with no de-duplication
- important, the new tape must be functionally equivalent to the old tape
    - that include be an alias for the old one
    - links/references must be preserved
- any rewrite system must:
    - read the old tape
    - process each record
    - write a new tape
    - validate: reproduce old tape from new tape


## Resource Resolution System (RRS)
- we can centralize all requests of data on a Resource Resolution System
- you want a tape, a record, etc... you call the RRS
- the discovery mechanism is triggered by the type of the query
    - for instance, `TapeLocator` or something