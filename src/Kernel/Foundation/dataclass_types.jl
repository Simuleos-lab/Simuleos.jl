# ============================================================
# dataclass_types.jl — Core runtime DataClass types
# ============================================================

"""Abstract runtime base for all semantic class objects."""
abstract type SimuleosDataClass end

function _dataclass_string_dict(data::AbstractDict)::Dict{String, Any}
    out = Dict{String, Any}()
    for (k, v) in pairs(data)
        out[_to_string_key(k)] = v
    end
    return out
end

function _dataclass_symbol_dict(data::AbstractDict)::Dict{Symbol, Any}
    out = Dict{Symbol, Any}()
    for (k, v) in pairs(data)
        out[_to_symbol_key(k)] = v
    end
    return out
end

_dataclass_string_vec(data::AbstractVector)::Vector{String} =
    String[string(v) for v in data]

struct SrcSettingsAccessV1 <: SimuleosDataClass
    accessed::Dict{String, Any}
    timestamp::String
end

function SrcSettingsAccessV1(accessed::AbstractDict, timestamp::AbstractString)
    return SrcSettingsAccessV1(_dataclass_string_dict(accessed), String(timestamp))
end

struct SrcCodebaseV1 <: SimuleosDataClass
    git_commit::String
    git_branch::String
    git_dirty::Bool
    git_describe::String
end

function SrcCodebaseV1(
        git_commit::AbstractString,
        git_branch::AbstractString,
        git_dirty,
        git_describe::AbstractString,
    )
    return SrcCodebaseV1(
        String(git_commit),
        String(git_branch),
        Bool(git_dirty),
        String(git_describe),
    )
end

struct SrcRuntimeHostV1 <: SimuleosDataClass
    julia_version::String
    hostname::String
    os::String
    word_size::Int
    threads::Int
    timestamp::String
end

function SrcRuntimeHostV1(
        julia_version::AbstractString,
        hostname::AbstractString,
        os::AbstractString,
        word_size,
        threads,
        timestamp::AbstractString,
    )
    return SrcRuntimeHostV1(
        String(julia_version),
        String(hostname),
        String(os),
        Int(word_size),
        Int(threads),
        String(timestamp),
    )
end

struct SrcExecutionSiteV1 <: SimuleosDataClass
    src_file::String
    src_line::Int
    threadid::Int
    timestamp::String
end

function SrcExecutionSiteV1(
        src_file::AbstractString,
        src_line,
        threadid,
        timestamp::AbstractString,
    )
    return SrcExecutionSiteV1(
        String(src_file),
        Int(src_line),
        Int(threadid),
        String(timestamp),
    )
end

struct SrcSessionStateV1 <: SimuleosDataClass
    session_id::String
    labels::Vector{String}
    meta::Dict{String, Any}
end

function SrcSessionStateV1(
        session_id::AbstractString,
        labels::AbstractVector,
        meta::AbstractDict,
    )
    return SrcSessionStateV1(
        String(session_id),
        _dataclass_string_vec(labels),
        _dataclass_string_dict(meta),
    )
end

struct SnapContextV1 <: SimuleosDataClass
    settings::Union{Nothing, SrcSettingsAccessV1}
    source::Union{Nothing, SrcCodebaseV1}
    environment::Union{Nothing, SrcRuntimeHostV1}
    execution::Union{Nothing, SrcExecutionSiteV1}
    session_id::String
    labels::Vector{String}
end

function SnapContextV1(;
        settings::Union{Nothing, SrcSettingsAccessV1} = nothing,
        source::Union{Nothing, SrcCodebaseV1} = nothing,
        environment::Union{Nothing, SrcRuntimeHostV1} = nothing,
        execution::Union{Nothing, SrcExecutionSiteV1} = nothing,
        session_id::AbstractString = "",
        labels::AbstractVector = String[],
    )
    return SnapContextV1(
        settings,
        source,
        environment,
        execution,
        String(session_id),
        _dataclass_string_vec(labels),
    )
end

struct RecRefV1 <: SimuleosDataClass
    record_hash::String
    record_short::String
    writer::String
    timetag::String
    payload::Any
end

function RecRefV1(;
        record_hash::AbstractString = "",
        record_short::AbstractString = "",
        writer::AbstractString = "",
        timetag::AbstractString = "",
        payload = nothing,
    )
    return RecRefV1(
        String(record_hash),
        String(record_short),
        String(writer),
        String(timetag),
        payload,
    )
end
