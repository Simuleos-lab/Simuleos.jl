***

## -- .. - .-- .-. . .... -- -- -- .. ...
# TODO/ Not for this package necessarily
- create a set of tools for aiding typical simulation workflows
- Use as deps, Bloberias, Scoperia...
- It must include
  - A tape/tree data trace
      - I must be able to visit data as it was produced
  - bookmarks
      - A named address in the data struct
  - scope hash test
      - I want to know if I already visitted a given scope
      - This is a base for reloading/skipping repeated computation
  - scoped-based and data-based addressing
      - I must be able to read/write to an address built from an scope or an object
  - A full battery of scope tools: filters, validators, etc..
  - The engine must force a minimal amoung of docummentation or metadata. 
      - For instance, force @init_block() 
  - local context
      - A hash of the local scope comprising only :primitive values
      - This force code documentation
          - use of labels or explicit varianbles
      - The system must detect supersets
          - For instance, If I add a local variable but nothing else changes...
  - rolling batching 
      - Data is captured sequencially but a new batch is created after
      - a number of blobs are stored...
      - ex: @blobkbatch "tag" -> 
          20250527-2308039-0d748c34


## Project Goals
- Ok, It seems that too much useful workflows depend on the storing infrastructure of a simulation pipeline. 
- So, althought we can have independent packages, I think will must converge into a single storage interface. 
- For instance, this project is a good test of the scope-based interface as a clean, self-docummenting, recording method. 
- But, we need more than just recording.
- We need caching

## Per scope config
  - #DONE: 90%
- Using labels, we can name/mark/id scopes
- So, the same as the per-scope-hooks we must have a pre-scope-config

## Redundant Scopes
  - #DONE: 10%
- Each Scope is fully hashed, so, we can detect if it is already en the tape
- So, we can just store a link (the hash), instead of the whole Scope.
- Maybe i can run deeper checks (like subset tests) in the current batch.
  - This will reduce a little the amount of redundant and shadowed scopes.

## Conditianal hooks
    - #DONE: 100%
- It should be possible to defined scoped hooks.
- One way to address it to add a rexeg to each hook
- This will be a trigger regex, if a matching label is present in the context, it will be taken into consideration. 

## Bookmarks
    - #DONE: 0%
- Simple labels but which position in the tape is register in a manifest
- it will create an scope (mustly empty) which only purpuse is to occupy an space in the tape.
- This is for aiding searching

## Tare inteface
- It is marking existing variables as non-trakcable...
- For instance, I can do it at the bigining of a session.

***
## Interfaced scope
- because an scope is a key valued object, you can implement a type system similar to JS
- Usage case: extract a Partial from the current scope.
  - You can define the Partial outside the scope code so increasing clarity

***
## Problem
- Im doing batching with the scopes so context searching  becomes fast
- But, what to do with the blobs? 
- I should not have all blobs of a batch loaded in ram.
- The scope batch is assumed to be lite, the blobs not.
- Recording the instantaneously into memory, will create potential unused blobs if the scope batch is not finally stored/committed.

### Solution 1
- Maybe we can have a configuration of the db that is not search friendly, but it is recording friendly. 
- After recording, we can transform the db and 'compress/proccess' it
- For instance, I can group blobs into similar sized batches. 
- Search should work on any format.
- This is nice because I can implement (and test) first the record frindly format.

### Solution 2
- A single format 
- But the search/record friendly change is controlled by the batch size
- The user set the `commit/flush` frequency.
- between commits, all is stored on ram, including the blobs
- The user is responsible to define a appropiate ferquency. 

***
## Disk storage - blobs 
- Blobs are objects that are not directly recorded into an scope.
- In the scope, a hash is stored instead of the value. 
- The hash must be sufficient to resolve the storage file. 

***