# ------------------------------------------------------------------
_load(file) = endswith(file, ".jls") ? deserialize(file) : FileIO.load(file)

# ------------------------------------------------------------------
_save(file, dat) = endswith(file, ".jls") ? serialize(file, dat) : FileIO.save(file, dat)