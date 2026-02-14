# Core base primitives (all I0x)
# Kept separate so `types-I0x.jl` remains type-only.

const TAPE_FILENAME = "context.tape.jsonl"
const BLOB_EXT = ".jls"

# Convenience constructor for callers that only pass repository path.
GitHandler(path::String) = GitHandler(path, nothing)
