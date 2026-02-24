# Simules CLI

`cli/` is a standalone Julia CLI surface for project-level Simuleos tooling.

The executable wrapper is `cli/bin/simos` (the help banner currently identifies the tool as `Simules CLI`).

## Run

```bash
./cli/bin/simos help
./cli/bin/simos stats
./cli/bin/simos stats /path/to/project
./cli/bin/simos stats --project /path/to/project
```

## Validate

```bash
julia --project=cli cli/test/runtests.jl
```
