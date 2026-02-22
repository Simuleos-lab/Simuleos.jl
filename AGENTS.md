## Resources
- check notes/index for relevant notes
- check examples for minimal working examples
- check refs for project implementing similar/related ideas

## No backward compatibility
- do not keep code because of backward compatibility
- remove deprecated code, aliases, and old tests
- keep code clean and simple

## Module exports and imports
- do not do exports for internal modules
- always use explicit imports
- full qualified names in code
- use exports only in the top-level Simuleos module

## Live script sandboxing

When a live script (`dev/live/NNN-*.jl`) needs a Simuleos home and project, create them as subdirectories inside `dev/live/` itself — never touch the real home or the repo's own `.simuleos/`.

```julia
const LIVE_DIR = @__DIR__
const HOME_DIR = joinpath(LIVE_DIR, "home")
const PROJ_DIR = joinpath(LIVE_DIR, "proj")

# Clean slate
for d in (HOME_DIR, PROJ_DIR)
    isdir(d) && rm(d; recursive = true)
end

sim_init!(; bootstrap = Dict{String, Any}(
    "homePath" => HOME_DIR,
    "projPath" => PROJ_DIR,
))
```

Reference: `dev/live/501-record-and-read.jl`.

## Julia tooling
- run tests with the project flag: `julia --project`
- use Pkg to modify Project.toml and Manifest.toml — do not edit these files manually

