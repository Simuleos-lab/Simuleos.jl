const SIMULEOS_DIR_NAME = ".simuleos"

# Shared base path helper (used by both home and project paths) (bootstrap SSOT)
_simuleos_dir(root::String)::String = joinpath(root, SIMULEOS_DIR_NAME)
