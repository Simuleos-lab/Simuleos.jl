module SimosAPI

import ..Kernel
import ..WorkSession
import ..SQLiteIndex
import SQLite

# Module alias convention (shared by included subfiles)
const _Krn = Kernel
const _WS = WorkSession
const _SQLi = SQLiteIndex
const _API = SimosAPI
const _SQLite = SQLite

include("macro.jl")

end # module SimosAPI
