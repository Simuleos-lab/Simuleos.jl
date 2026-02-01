## -. .. . .- - - - -- .- .-. - -.. .- .- .- - .-.
#  MARK: Tests
function rand_date(start::Date, stop::Date)
    days = Dates.value(stop - start)   # number of days in range
    return start + Day(rand(0:days))   # pick a random offset
end

## -. .. . .- - - - -- .- .-. - -.. .- .- .- - .-.
function _rand_dict(depth; max_depth=5, max_keys=10)
    d = Dict{String, Any}()
    nkeys = rand(1:max_keys)
    for i in 1:nkeys
        key = randstring(rand(3:8))  # random string key
        value = _rand_value(depth; 
            max_depth=max(max_depth-1, 5), 
            max_keys=max(max_keys-1, 10)
        )
        d[key] = value
    end
    return d
end

# helper: random values, sometimes nested
function _rand_value(depth; max_depth, max_keys)
    choice = rand(1:5)
    # choice = 5
    if choice == 1
        return rand(-1000:1000)  # integer
    elseif choice == 2
        return rand()            # float
    elseif choice == 3
        return randstring(rand(3:10))  # string
    elseif choice == 4
        return string(rand_date(Date(2000,1,1), today()))
    elseif choice == 5 && depth < max_depth
        return _rand_dict(depth+1; max_depth=max_depth, max_keys=max_keys)  # nested dict
    else
        return nothing  # fallback if too deep
    end
end

rand_dict(;max_depth=3, max_keys=5) = _rand_dict(0; max_depth, max_keys)

