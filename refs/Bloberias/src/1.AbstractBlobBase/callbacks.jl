const _CALLBACKS = Dict{Tuple, Set{Function}}()

function _callback_reg(id::Tuple)
    return get!(_CALLBACKS, id) do
        Set{Function}()
    end
end

function register_callback!(fun::Function, id::Tuple)
    reg = _callback_reg(id::Tuple)
    push!(reg, fun)
    return nothing
end

function run_callbacks(id::Tuple)
    reg = _callback_reg(id)
    for fun in reg
        fun()
    end
    return nothing
end