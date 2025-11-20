
## JIT compresion

- great, but, what about the cases in which I have a lot of iteration which share must of the context... let say all parameters are the same but one?
- what is a smple approach to that?
- maybe we can have also an evolution on the data base
- we can have a raw layer
    - where we waranty just recording all the user wants
    - nut once reached a limit, we reprocess this raw version into a more compacted version
    - just like incremental compiling, where we first run a lees optimized code, like JIT