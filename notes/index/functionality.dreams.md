## TODO: add here a list of functionalities
- for instance, memoization, replay, diffing, etc.

# Tape Rewrite System
- Rewrite tape data for format changes, bug fixes, or consolidation
    - Consolidation: migrate from collection-optimized to storage-optimized (single format at a time,
    inline→deduplicated)
    - New tape must be functionally equivalent: aliases preserved, references maintained
    - Process: read old tape → process records → write new tape → reconstructing temp-old from new → validate
    temp-old with original old


## Resource Resolution System (RRS)
- we can centralize all requests of data on a Resource Resolution System
- you want a tape, a record, etc... you call the RRS
- the discovery mechanism is triggered by the type of the query
    - for instance, `TapeLocator` or something