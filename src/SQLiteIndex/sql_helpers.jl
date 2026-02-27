# ------------------------------------------------------------
# SQLite helpers
# ------------------------------------------------------------

_sqlite_exec(db::SQLite.DB, sql::AbstractString) = (SQLite.DBInterface.execute(db, String(sql)); nothing)
_sqlite_exec(db::SQLite.DB, sql::AbstractString, params) = (SQLite.DBInterface.execute(db, String(sql), params); nothing)

struct _SQLiteIndexDriftError <: Exception
    message::String
end
Base.showerror(io::IO, err::_SQLiteIndexDriftError) = print(io, err.message)

function _with_sqlite_transaction(f::Function, db::SQLite.DB)
    _sqlite_exec(db, "BEGIN IMMEDIATE")
    try
        f()
        _sqlite_exec(db, "COMMIT")
    catch
        try
            _sqlite_exec(db, "ROLLBACK")
        catch
        end
        rethrow()
    end
    return nothing
end

_string_or_nothing(x) = x isa AbstractString ? String(x) : (isnothing(x) ? nothing : string(x))

function _int_or_nothing(x)
    x isa Integer && return Int(x)
    return nothing
end

function _bool_int_or_nothing(x)
    x isa Bool && return x ? 1 : 0
    return nothing
end

_sqlite_nullable_text(x) = (ismissing(x) || isnothing(x)) ? nothing : String(x)
_sqlite_nullable_int(x) = (ismissing(x) || isnothing(x)) ? nothing : Int(x)

# ------------------------------------------------------------
# SQLite row/query helpers (internal)
# ------------------------------------------------------------

function _sqlite_materialize_row(row)::Dict{Symbol, Any}
    return Dict{Symbol, Any}(Symbol(name) => value for (name, value) in pairs(row))
end

function _sqlite_all_dicts(db::SQLite.DB, sql::AbstractString, params = ())
    rows = Dict{Symbol, Any}[]
    for row in SQLite.DBInterface.execute(db, String(sql), params)
        push!(rows, _sqlite_materialize_row(row))
    end
    return rows
end

function _sqlite_one_or_nothing(db::SQLite.DB, sql::AbstractString, params = ())
    rows = _sqlite_all_dicts(db, sql, params)
    isempty(rows) && return nothing
    length(rows) == 1 || error("Expected 0 or 1 row, got $(length(rows)).")
    return rows[1]
end

function _sqlite_table_exists(db::SQLite.DB, table_name::AbstractString)::Bool
    row = _sqlite_one_or_nothing(db,
        "SELECT 1 AS ok FROM sqlite_master WHERE type = 'table' AND name = ?",
        (String(table_name),),
    )
    return !isnothing(row)
end
