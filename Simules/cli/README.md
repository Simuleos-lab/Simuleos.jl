# Simules CLI

`Simules/cli` is a standalone Julia CLI surface for project-level Simuleos tooling.

## Run

```bash
./Simules/cli/bin/simules help
./Simules/cli/bin/simules stats
./Simules/cli/bin/simules stats /path/to/project
```

## Validate

```bash
julia --project=Simules/cli Simules/cli/test/runtests.jl
```
