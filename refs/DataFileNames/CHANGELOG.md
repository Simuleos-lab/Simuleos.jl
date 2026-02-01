# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Now is valid to pass several dirs in separate vectors: `dfname(["dir1"], ["dir2"], args...)`
- Methods `dfheads`, `dfparams`, `dfparam`, `dfext` added and exported.

### Fixed

- `tryparse_dfname` implemented without using `try` `catch`.

## [0.3.2] - 2021-07-8

### Fixed

- Improve thread safety.

## [0.3.0] - 2021-06-22

### Changed

- Improve extension detection. Now it will take that extension (if it is a valid `dfname`) differently
depending if it is a parametrized name or not. In the case of the former, it is just all after the right param body separator. On the other case it is the shortest matching extension pattern.

## [0.2.0] - 2021-06-22

- Start the `CHANGELOG`
- A first good implementation

[Unreleased]: https://github.com/josePereiro/UtilsJL/v0.2.0...HEAD
[0.3.2]: https://github.com/josePereiro/UtilsJL/releases/tag/v0.3.1
[0.3.0]: https://github.com/josePereiro/UtilsJL/releases/tag/v0.3.0
[0.2.0]: https://github.com/josePereiro/DataFileNames.jl/compare/v0.1.0...v0.2.0
[DataFileNames]: https://github.com/josePereiro/DataFileNames.jl
[DrWatson]: https://github.com/JuliaDynamics/DrWatson.jl