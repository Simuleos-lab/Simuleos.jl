## Simuleos State
- Simuleos is a state machine which operate with a a state which comprhened 
    - RunTime
        - SimOs
    - Disk
        - project folder
            - ./.simuleos
        - user home folder
            - ~/.simuleos
- The Core should provide objects/interfaces to manage the state
- At runtime, we prefer a lazy approach to avoid synchronization issues
- In the cases when performance require catching, we take a best effort policy
    - we prefer simplicity over syncronicity


## Simuleos Core Interface
- All must run on a functional interface
- We have two general workflows
    - functional
        - input -> function -> output
        - we can carry the context on objects
            - eg: `load_tape(S::Session, tapeid::String, ...)`
    - global state
        - context comes from global state
            - eg: `load_tape(tapeid::String, ...)`
                - load tape from global `current_session`
- Issue: how to diffirentiate between the two interfaces
    - function names
    - dispatch
    - modules
        - `OS.load_tape(tapeid::String, ...)`
    - mixure

