# v7 DESIGN
# TODO: implement this
# - a blob is a dict node in the blobtree
# - the blobtree is just a JSON kind of struct
# - a frame is the blob that will be represented on disk
# - BlobHandlers are objects that interface operations on blobs
#   - #TODO: rename AbstractBlob to BlobHandlers
# - a blobpath is just a tuple of elements that define the path to retrive a blob in the blobtree
#   - the tuple can contain anything
#   - for instance (Bloberia, "frameid") represent a blob (a frame blob) in a Bloberia depot.
# - the path is resolved by _blobpath_I(...) method
#   - the method must return the blob's parent container and the blob's key
#   - for instance _blobpath_I(Bloberia, "frameid") returns (B.frames, "frameid")
# - there is not limits for the path _blobpath_I(obj, bla, bla, bla) can return just something else.
#   - but it should be consistant with the frame interface
#       - that is, it should be contained on the frames depot so serialization will capture the path. 
# - a _framepath_I(...) will return the path to the frame blob
#   - each handler should have only one frame/depot (#TAI)
#   - but handlers might share frame/depots. 

# v7 DESIGN
# - a blob is just a leave in the blobtree
# - the blobtree is analogous to a filetree, a blob would then be analogous to a file.
# - the other nodes are folders.
# - The objects (Bloberia, BlobBatch, etc) represent nodes on the tree.
# - for instance, a BlobBatch is a subnode of Bloberia which can have children blobs or folders. 
# - BlobBatch folders contains Blob blobs (files)...
# - The disk layout of the blobtree is implementation free.
#   - This allows us to convinient data structures (like batches)
# - so, you can refer to a blob by indexing node Objects
#   - ex: if B::Bloberia, B[["meta"]] is a blob in a Bloberia
#       - B/meta
#   - ex: if b::Blob, b[["meta"]] is a blob in the meta frame of a BlobBatch
#       - B/bb/meta/b
#   - ex: if bb::BlobBatch, bb[["meta"]] is a the meta blob
#       - B/bb/meta
# - blob are dictionaries
#   - b["meta", "key"] refers to B/bb/meta/b:key


# TODO:
# - implement reset!, which refresh the ram data as it is currently at disk

# v6 DESIGN Blobs frames interface
# getframe
# - first lock at blobs frame
# - then apply getframe(b.bb)
# getframe!
# - if applyed over the blob, means a blob frame
# load
# - load ondemand if missing 
#   - important: only is missing, no empty, to avoid loading empty stuff all the time

# v6 Automatic description of batch content
# - Add time stamp
# - add generating script src

# v6 DESIGN data point centric view (ContextDB)
# - a vblob can be viewed as an entry in a ContextDB was
# - you can have a search system for matching contexts
# - This indexing system act also as a validator that hte data 
# you are loading is the one you are refering too
#   - it should fail if more than one is found (ambiguity)
# - It also allows you to have multiple version of scripts
# storing data in the same Bloberia
# - The main problem is when a new context coord is introduced
# which is equivaent to say that before was constant
#   - back propagating new context should be implemented
# - I think the only part missing is a macro interface
#   - @blob! blob "frame" var = 1
#   - Probably we need a global interface
#       - @newblob! bb                 # create and select a blob
#       - @selframe! "frame"           # select a frame
#       - @blob! var = 1               # store (ram) a value in the blob
#       - @blob! bla = rand(10,10)     # store (ram) a value in the blob
#       - @context! blo = 1            # blob! a value but filter its type (?)

# v6 DESIGN dict-like interface
# - B["frame", "key1", "key2"]
# - B["frame", "key1/key2"]
# - The frame part is the only structure required by the file system
# - Then you can use a url id for accessing sub 'folders'

# v6 DESIGN herarchical struct
# - blob can access different frames 
#   - private: a particular uuid content on a bframe
#   - bb global: the bb bbframe
#   - B global: the B bbframe
# - that is, we only needs one type of blob
# - pro: data is accessible from a blob and it is compartmentailize
#   - only local and parent frames re accesible from a blob
# con?: B will have frame data (it already have meta)
# - frame type can be resolve at loading either from the file name, structure, or meta data serialized in the frame.
#   - I do prefer the serialize part (simplified filesys?)
# - con?: meta will be a reserved name for a frame
#   - It is a build in bbframe
# pro: a simple addres system
# - B/frame (a frame from the B)
# - bb/frame (a frame from the bb or B)
# - b/frame (a frame from b, bb or B)

# v6 DISIGN seek and load referencing
# - I can use a uuid for identifing each object in the B
# - a link can just be uuid, then B[?, uuid] will trigger a search and 
# retrive the object. 

# v6 DESIGN handling ram/disk versions
# - most standard operations should be done in the ram version only, 
#   at least there is a good reason to do it also in the disk version.
# - The ram version is a 'stage' space
# - the main trade offs are disk reading cost and ram/disk syncronization.
# - some ram only opperations:
#   - isempty, empty!, setindex!, length, ...
# - some ram and disk opperations:
#   - delete!, hasframe, serialized! (sync), etc
# - disk/ram syncronization
#   - serialize! (ram -> disk)
#   - force_load! (disk -> ram)
#   - ondemand_load! (disk -> ram if ram is missing)
#   - delete! (delete both ram and disk)

# v6 DESIGN
# - create 'base' interface
#   - base is built for precitiona and experessivity. 
#   - clear simgle porpuse methods/tools
#   - for instance:
#      - only reimplement Basa.X methods that do presiscesly 
#        what it is intended. like Base.show
#      - contains as few defaults as possible.
# - create 'sugar' interface
#   - 'sugar' is built for conviniency 
#   - contain the shortcuts and more opinative implementations

# v6 DESIGN
# - lock all serializations and deserializations of frames.

# v6 DESIGN
# - Create a callback interface for files events
# - usage case:
#   - create a refresh/track frames interface
#   - let say Im mostly interesting on having the last version of a frame 

# v6 DESIGN 
# - create a merge interface
#   - merge new data -> ram = U(ram, new data) but ram overwrites
#   - merge ram -> new data ...
#   - merge ram -> disk ...
#   - merge disk -> ram ...
#   - merge new data -> ram -> disk ...


# DONE: create relative references..
# - DONE given a batch find blob/value (relative paths)
#   - this way I do not need to store the full path to the batch
#   - syntax ideas: bb[ref]
# - DONE also for avoiding reloading frames...
#   - for this maybe we need a new object, ej: RefCacher
#   - syntax ideas: rc[ref]
#   - if the ref does not point to the cached batch it loads it...
#   - otherwise it reuse the cached one
#   - the cache size can be configured. 

# IDEA/DONE: Generalize a BlobBatch
# - A BlobBatch can have a vector frame or a random access frame interface
#   - It is just an extention of the meta frame capability

# IDEA
# - Think about a different interface to access the ram version and the disk version.
# - The current interface is just a default which might be too opinative.
# - Make it explicit first and then create the defaults. 

# DONE: foreach_rablobs

# DEPRECATED: put blobbatches groups into folders?

# DONE: create bloberia(::AbstractBlob), etc kind of accessor interfaces

# DONE: BlobyRef
# - An object containuing all data for pointing to a BlobyObject/Val
# - Its main goald is to be cheap to serialized
# - It must serialized the expected return type

# TODO: Work on type stability

# DONE: Dry the code: a lot of code repetition

# TODO: Define/Document the load on demand behaviour 
#   - load if it is missing on ram
#   - for reloading you must empty the cache
#   - maybe have a blob(::Blob) method for shadow copy

# OLD --.- - -- - -- - -

# DEPRECATED/DONE: create a multifile dBlob system
# - Ex: blob!(B, "globals", "ecoli_core", "net0") will create/load "ecoli_core.globals.net0.jls" file
# - blob!(B, "globals", "ecoli_core", "net0.elep0")
# - blob!(B, "globals", "ecoli_core") will create/load all files matching
# - a dBlob might target multiple files
# - One complexity is that at setindex/serialization you must decide where to write the new data
# - The goal is to create a frame-like structure to separate heavy objs into diferent files but handle it from a single blob object.

# DONE:
# - Make random blobs hold its content
# - that is, move it away from Bloberias
# - otherwise you can not load other rablobs at the same time
# think about dBlob as a batch of a single blob, so it needs to have batch+blob functionality



# IDEAS v1:

# 1. Definition of Context

# 1.1 Computation/Problem point of view
# - The context is the parameters that affects the computation at hand.
# - The implementation details shouldn't be included

# 1.2 Script point of view
# - Here context are just all variables that are present at the moment of saving the data.
# - It is irrelevant if those variables are relevant for the calculation or not. 
# - FAVORITE: This is the more general, giving that must of the time, one must explicitly 
# have the parameters of a computation contain in variables. 
#     - Additionally, it is not dificult to extend the interface for including custom types.
#     - For instance, custom types might be rolled out and store only its 'lite' typed fields.

# 1.3 Context as a path on the data base
# - Here for instance, the order of the context is important.

# 1.4 Mixed

# 1.41 Context as a Tree
# - The context is just a directed tree...
# - In this case order might matter
# - A context is totally defined by the subtree that is unique to it. 

# 1.42 Context as a key value collection
# - PREFERED beacuse its simplicity
# - In this order might not matter
# - Context is just a Dict like structure
# - A context is defined by the key-value pair subset which is unique to it.

# 2. Context definition interface

# 2.1 Automatic vs manual context definition

# - All by default
#     - I can use all available 'lite' typed (Numbers, short strings, etc) variables as context.
#     - I can have a configurable 'ignore'/'include' stratergy.

# - Manual declaration of context
#     - inline macros.
#     - Have a context registry, keep the symbols to track.

# - Mix approach 
#     - have all the above functionalities.
#     - have a 'localcontext' function which extract the context given the available variables.

# 3. Context Batches, Frames and Batches definition. 

# - All this mess is for performance reasons.
# - Data can be consived as a continuos OrderedDict{uuid, ContextBlob} structure.
# - But, for performance reasons this data is splitted first in batches (each one containing a given number of Blobs).
# - Each batch is at the same time splitted in frames, but this spliting is not in the same dimention. Each blob of the batch is divided in frames, each one containing the same field of all of them.
# - That is, in a batch we will have:
#     frame12: [blob123.fields12, blob124.fields12, blob125.fields12, ....]
#     frame4:  [blob123.fields4 , blob124.fields4 , blob125.fields4 , ....]
# - Additionally, we can have a META_FRAMEID field for each batch to store extra lite data of the whole batch.
# - This way in memory is typically loaded as maximum a whole batch, but potentialy, only a few frames of the batch itself.
# - A blob is a 'key' => 'value' structure
# - each context is identifyed by an universaly unique identifier.

# 4. Writing/Input interafce

# - Must have staging

# 5. Reading/output interface.

# - IMPORTANT: Do not make it complicated... simplicity is important for reusing...

# 5.1 Query
# - Pattern matching based
# - Should use multi threading
# - Mush have Product Query capabilities (ej: collect A => 1:3, B => [-1, 2])
# - Should always work on contexts. Opionally also non-lite data. 

# 5.2 Get
# - Given a precise location, load it.

# 5.3 Iterator
# - Itarate all blobs batch after batch...

# 5.4 QueryRes
# - Use the iteration interface to find all matching contexts/data...
# - Returns a new object that can be iterated, but this time only over the 
# batches that have at least hit...

# 6. Disk layout

# ---- db                                 (root dir)
#     |--- config.jls                     (optional  [Dict])
#     |--- meta.jls                       (optional [Dict])
#     |--- 0...<<h=0x86ff87788a342>>      (batch of group '0')
#         |--- meta.jls                   (batch meta data [Dict])
#         |--- ctx.frame.jls              (reserved frame for context data [Vector{Dict}])
#         |--- 0.frame.jls                (default data frame with name '0' [Vector{Dict}])
#         |--- bla.frame.jls              (data frame with name 'bla' [Vector{Dict}])
#     |--- bla...<<h=0x761aff765a578>>      (batch of group 'bla')



# 7. (Des)Serialization
# - frames are serialized Dict objects
# - At deserializing they are wrapped into an ContextBlob (if necessary)
# - All query/get operations (ej: haskey) are performed on the loaded frames.
# - That is, frames should be loaded explicitly, except default frames which are loaded on demand.

# 9. Utils

# 9.1 PinFiles

# 9.2 Repair capabilities & diagnostics

# 9.3 Implement Iterator interface

# 9.3.1 'foreach' blob
# - Add :break, :continue interface
# - return last value of the function

# 9.3.2 for blob in db/batch/frame


# # TO IMPLEMENT FIRST

# - Main input form: push to a loaded batch
# - Main output form: iter each batch/blob
# - Basically, BlobBatches with Context objects

# =#