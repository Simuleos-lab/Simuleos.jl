#=
TODO/ test this packages
- Check memmory usage

Certainly! Here are several Julia packages and community discussions where hashing is employed for purposes like deduplication, content-based identification, or ensuring reproducibility of data structures such as matrices:

---

### 🔐 Julia Packages Utilizing Hashing

1. **[ContentHashes.jl](https://juliapackages.com/p/contenthashes)**
   Provides a generic object hashing implementation that hashes the exact content of objects, ensuring that two distinct objects with the same content produce the same hash. This is particularly useful for deduplication without implementing custom `Base.hash` methods.&#x20;

2. **[StableHashTraits.jl](https://juliapackages.com/p/stablehashtraits)**
   Aims to compute stable hashes of any Julia value using trait-based dispatch. The stability ensures that the hash remains consistent across Julia versions and sessions, which is essential for reproducibility.&#x20;

3. **[Nettle.jl](https://github.com/JuliaCrypto/Nettle.jl)**
   A Julia wrapper around the Nettle cryptographic library, providing access to various hashing algorithms like MD5, SHA1, and SHA2. Useful for cryptographic applications requiring secure hashing functions.&#x20;

---

### 🧠 Community Discussions and Use Cases

4. **[Efficiently Finding Duplicate Columns in a Matrix](https://discourse.julialang.org/t/how-to-efficiently-find-columns-of-the-matrix-which-are-the-same/105873)**
   Discussion on using hashing to identify duplicate columns in a matrix efficiently. By computing hash values for each column, one can quickly detect duplicates without exhaustive comparisons.&#x20;

5. **[Entity Resolution and Duplicate Data Handling](https://discourse.julialang.org/t/entity-resolution-duplicate-data-in-julia/33860)**
   Explores strategies for deduplication and record linkage in datasets, highlighting the role of hashing in identifying and eliminating exact duplicates.&#x20;

6. **[Alternatives to `Base.hash`](https://discourse.julialang.org/t/alternatives-to-base-hash/79154)**
   A discussion on the limitations of Julia's built-in `hash` function for certain applications and the exploration of alternative hashing methods that provide stable and collision-resistant hashes.&#x20;

---

### 📦 Additional Packages and Tools

7. **[SHA.jl](https://juliapackages.com/p/sha)**
   A native Julia implementation of SHA1, SHA2, and SHA3 hashing algorithms. Suitable for applications requiring cryptographic hash functions within Julia.&#x20;

8. **[Hashids.jl](https://juliapackages.com/p/hashids)**
   A Julia port of the Hashids algorithm, which generates short, unique, non-sequential ids from numbers. While not directly used for content hashing, it's useful for creating obfuscated identifiers.

9. **[AutoHashEquals.jl](https://github.com/andrewcooke/AutoHashEquals.jl)**
   Automatically implements `hash` and `==` methods for composite types, facilitating consistent hashing and equality checks without manual implementation.

10. **[BloomFilters.jl](https://github.com/johnmyleswhite/BloomFilters.jl)**
    Implements Bloom filters in Julia, a probabilistic data structure that uses hashing to test whether an element is a member of a set, allowing for efficient deduplication checks with a tunable false-positive rate.

---

These packages and discussions should provide a solid foundation for implementing efficient and reproducible hashing strategies in your Julia projects, especially for tasks like matrix deduplication and content-based identification. If you have specific requirements or need further assistance with any of these tools, feel free to ask!

=#

## --- . -. -- .- - - - .. . . . .- - -. . -. . 
# INTERFACE: create an string hash for identifing a blob
st_blob_hash_I(obj::Any) = _hash_object_sha(obj)

# DO NOT REIMPLEMENT THIS ONE
st_blob_hash(obj::Any) = st_blob_hash_I(obj)

## --- . -. -- .- - - - .. . . . .- - -. . -. . 
#MARK: _hash_object_sha
# order do not matter
function _hash_object_sha(obj::AbstractSet)
    io = IOBuffer()

    hashes = Vector{String}(undef, length(obj))
    i = 1
    for x in obj
        hashes[i] = _hash_object_sha(x)
        i += 1
    end
    sort!(hashes)

    for h in hashes
        write(io, h)
    end

    seekstart(io)
    return bytes2hex(SHA.sha1(io))
end

# order do not matter
function _hash_object_sha(obj::AbstractDict)
    io = IOBuffer()
    pair_hashes = Vector{Tuple{String,String}}(undef, length(obj))
    i = 1
    for (k, v) in obj
        pair_hashes[i] = (_hash_object_sha(k), _hash_object_sha(v))
        i += 1
    end
    sort!(pair_hashes, by = x -> x[1])  # sort by hashed key
    
    for (hk, hv) in pair_hashes
        write(io, hk)
        write(io, hv)
    end
    seekstart(io)
    return bytes2hex(sha1(io))
end

function _hash_object_sha(obj::String)
    length(obj) < 40 && return obj
    return bytes2hex(sha1(obj))
end

function _hash_object_sha(obj::Number)
    string(hash(obj))
end

# fall back (general obj)
function _hash_object_sha(obj)
    io = IOBuffer()
    serialize(io, obj)
    seekstart(io)
    return bytes2hex(sha1(io))
end
