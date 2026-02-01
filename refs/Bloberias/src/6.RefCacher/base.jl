## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
# Constructor

RefCacher() = RefCacher(Dict())

## --.--. - .-. .- .--.-.- .- .---- ... . .-.-.-.- 
import Base.empty!
Base.empty!(rc::RefCacher) = empty!(rc.depot_cache)