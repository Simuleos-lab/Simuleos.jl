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
