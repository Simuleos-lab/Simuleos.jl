## .-.- -. ... .,.-. - ,-. . ,., .,,.;; .- .-
using JSON3
using SHA

# function parse_and_hash_jsonl_raw(path::AbstractString)
#     ctx = sha256_ctx()
#     buf = Vector{UInt8}(undef, 0)   # reusable line buffer

#     open(path, "r") do io
#         while !eof(io)
#             empty!(buf)
#             # read one line into `buf` without making a new String
#             readuntil!(io, buf, UInt8('\n'))  # appends bytes to buf

#             # drop trailing newline if present
#             if !isempty(buf) && buf[end] == 0x0a
#                 pop!(buf)
#             end

#             # update hash with the exact bytes of this JSON record
#             update!(ctx, buf)

#             # parse lazily; JSON3.Object keeps views into `buf`
#             obj = JSON3.read(IOBuffer(buf))

#             #### process obj here (don’t store it long-term) ####
#             # e.g., access fields without allocating big Dicts:
#             # if haskey(obj, "a"); x = obj["a"]; end
#             #####################################################
#         end
#     end

#     return bytes2hex(finalize(ctx))
# end


## .-.- -. ... .,.-. - ,-. . ,., .,,.;; .- .-
# MARK: JSON io
function json_print(io::IOStream, data::Dict)
    str = String(JSON3.write(data))
    return write(io, str)
end
function json_println(io::IOStream, data::Dict)
    str = String(JSON3.write(data))
    return write(io, str, "\n")
end

## .-.- -. ... .,.-. - ,-. . ,., .,,.;; .- .-
# MARK: JSON jl sugar
macro json_str(s)
    return :(JSON.parse($s))
end

## .-.- -. ... .,.-. - ,-. . ,., .,,.;; .- .-
# From https://discourse.julialang.org/t/why-does-julia-not-support-json-syntax-to-create-a-dict/42873/29
_json(n) = n
_json(n::Symbol) = esc(n)

function _json(n::Expr)
    if n.head == :vect
        return Expr(:vect, map(_json, n.args)...)
    elseif n.head == :braces
        kv = []
        for f in n.args
            f isa Expr || error("not a valid JSON")
            f.args[1] == :(:) || error("not a valid JSON")
            k = f.args[2]

            typeof(k) ∈ (Symbol, String) || error("not a valid JSON")
            k = string(k)
            v = _json(f.args[3])
            push!(kv, :($k=>$v))
        end
        return :(Dict{String, Any}($(kv...)))
    else
        return esc(n)
    end
end

# macro json(n)
#     return _json(n)
# end

# @json({
#     "a" : {  # recursive...
#         "b" : 2, # accessing local variable
#         "e" : nothing,
#     }, 
#     "c": [1, 2.0, "mixed types"], # array
#     "d": rand() # expression
# })