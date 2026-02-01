# ---.>._- - -. -->>> -- -_.... < - 
import Base.getindex
getindex(scv::SimuleosScopeVariable) = scv.val

# ---.>._- - -. -->>> -- -_.... < - 
import Base.hash
function Base.hash(scv::SimuleosScopeVariable, h::UInt = UInt(0))
    h = hash(:SimuleosScopeVariable, h)
    h = hash(scv.key, h)
    h = hash(scv.val, h)
    h = hash(scv.src, h)
    return h
end