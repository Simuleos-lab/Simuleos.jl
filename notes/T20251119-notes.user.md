> This is a user design note

***
# NOTE
- extracted from disscusing `git` development phylosophy
- > being wrong is worse than being inconvenient
- > Git deliberately exposes its plumbing. If you touch the plumbing, you must be responsible for consequences.
    - we need to clearly define the plumming
    - and sepearated from the applications on top
    - also, the plumming must be usable by itself
- #TODO
- Disscuss with chatGPT about applaying `git` phylosophy on `Simuleaos` design

- How this applies to your own project
- Good insight from you:
- “Where should I, as a developer, stop implementing auto-recoveries?”
- Git’s philosophy suggests the answer:
    - Don’t guess user intent.
    - Don’t hide failures.
    - Make the rules explicit.
    - Document the contract and trust users to follow it.
- You can offer helper commands:
- `fix-worktree path/to/wt`
- But avoid silently fixing in the background.
- This mirrors Git’s approach:
- tools may help, but the core stays strict.

***
# NOTE
- A good way to prmopt the user to be aware of what is the context being recorded
- Is to error all the time a dict is tried to be transformed to json 
- And it have a non lite value.
- I mean, the user is responsable to eliminate any non lite value.
    - or promote non-lite -> to lite
- because this operation needs to be made to the same object, the filtering is 
- then integrated into the script workflow
- If at the end of all hooks what is remaining is not lite.
    - error
    - The hooks is responsable to `which/case` the scopes to deal 
        - with them context dependently.
- It is not that bad, 
    - there will be an Simuleos interface to check if a type is ok. 

***
# NOTE
- Lessons from Perkeep
    - Content-named DB
        - We need a ownership system using some krypto
        - when name hashing files, put info about the alg in the name
            - sha256-ab354aff65567554587
        - This can be really usefull for the json core DB
            - NO duplication
            - Easy merge of repositories
        - The ContextDB is more focus on themetadata than Perkeep
            - Perkeep has a built in system for storing arbitrary raw data
            - We only care for the metadata
                - If a node describing how to load data is broken  
                - Its ok, we still know a lot about what was there, thanks to the context
                - Context is lite, we can be more ambitious if we focus on that
                - We can extend the system to all data later....

***
#### NOTE
- https://docs.ipfs.tech/concepts/what-is-ipfs/
- Check ipfs for handling the global universal tree

***
#### NOTE
- https://book.keybase.io/docs/files/details
- Check the concept of universal filesystem

***
#### NOTE
- https://indieweb.org/PESOS
    - You have no initial control of your data
    - but you recolected and own it back.
- https://indieweb.org/POSSE
    - Yopu never loose control of your data.
    - You publish in your data in your own domain, then give permission to other to republish.
        - This is amazing, because I think is tottally doable.
        - All apps/companies must use this platform 
        - All tweets, email, etc.
            - You first publish the text in your shit, ad then tweeter can take it. 

***
#### NOTE
- Notes from this video
    - https://www.youtube.com/watch?v=PlAU_da_U4s&t=742s

- Content addressable files.
    - The index of the file in the system is a hash of its content.

- Unique files and version
    - Each version has its own hash given that they are different files
    - But at the same time, you just need to set clear that there is a relationship
        - between those files
        - They are versions of eachother
    - So, the version stuff is a higher abstraction than the file itself.
    - The file is just content



***
### NOTE
- Content addressable files.
    - The index of the file in the system is a hash of its content.

### NOTE
- There are two important components that deal with similar objects. 
- There is the `Scope`
    - which deal with the current representation of the state of the program
- There is the `Context`
    - which is a more general concept.
    - It is related with formalizing the description of a "moment"

- A question is if trying to have only one object or using only one.
- I think it makes sense that it is the SAME object. 


#NOTE
## What should it does
- Scope aware code
    - Tools for working with the scope
    - Scope dependent callbacks
        - Error if not triggered
    - Scope dependent filters
    - Type dependent collection
        - litescope

- Extremely flexible storing capacity.
- Implement a Dict like interface for storing.
- Storing must implement batching.
- Batching must be controlable but also ignored when possible.
- Implement an storage system that is iterable
    - A tape like system

- A convinient set of global state objects
    - like Plots.jl

- A context specific memorization mechanism
- A context specific hashing system

- Typescript like system for interfaces

- Thread/MultiProccessing save code
    - Using SimpleLockFiles

- Force minimal code annotation
    - ex: @init_block "label"

- Conveniant metadata for each stored entity
    - like storaged time

- It must be designed to separate the simulation code from the maintenence code
    - Ex: Use callbacks for refere out code for saving/catching

- the flow of the simulation must be respected as much as possible
    - Ex: You shouldn't need to create a loop just for storing

- Full implemented interface for dealing with the database
    - delete/filter/map/create

- Integration with git
