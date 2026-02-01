# Mon Dec  2 22:33:59 CST 2024
# DataFlow: 
# - different versions of data must be deal with cached ids...
# - then they can be linked to a global interface
# - batches names must be simple
# - differentiation between batches must be achived by comparing context 
# - context are lite variables, ex: stored on 'meta'

# Context resolution 
# - DO NOT USE FILE NAMES AS CONTEXT RESOLVERS
#   - A single string is not enought
#   - Use a key => value struct and matching interfaces
#   - See ContextDB
# - or just use @litescope

# - A close context interface
#   - A context must be use as id only if it is completed
#   - One you match it once, it will complaints if you try to update it
#       - ex: ERROR: context was already used! Update are closed!, see 'open!'

# - A problem is that storing all scope is nice, but then it is 
#   bad for hashing the context.
# - Not all parameters are relevant for the computation...

try
    println("Hello")
catch err;
    err isa InterruptException || rethrow(err)
end
