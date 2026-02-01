datio(f::Function, s::Symbol, arg0, args...) = 
    _datio(f, Val(s), projpath(arg0, args...)) 
datio(s::Symbol, arg0, args...) = 
    _datio(Val(s), projpath(arg0, args...))

