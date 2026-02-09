## SimuleOs: workflows
- a conceptual description of important functionalities of SimuleOs
- for instance
    - scope recording
    - database reading
    - system manadgment 
        - eg: rm, gc, rename, archive, etc...

## Workflows: Scope Recording
- this is a key workflow in symuleos
- it involved the enbeding calles of simuleos macros for capturing programs scopes
- it aims to populate a database at the project's `.simuleos` folder
- steps draft
    - i. init simuleos
    - ii. init recording session
    - iii. record/stage scopes
        - including labels and context
    - iv. commit stage
    - v. repeat if necessary
- here the globals based interface is the more natural one
    - we can have a global `current_session` object which is used by the macros
    - this way, we don't need to pass the session object around


## Workflows: Data base reading
- we can read the database for retriving data from scope recording
- this data can be use as init data for performing further computations
    - or for ploting
- here the functional interface is more natural
    - we can have functions like `load_tape(session::Session, tapeid::String, ...)`
    - this way, we can have multiple sessions at the same time if needed
    - and we can also have more control over the data loading process
- step draft
    - i. init simuleos
    - ii. load session
    - iii. load tape/scope
    - iv. use data for further computations
    - v. repeat if necessary


## SimuleOs: sim_init
- this is the entry point of the system
- it deal with the minimal global configuration
- for instance
    - scan for a project
    - load settings
    - init key objects
        - like SimOs
- we should keep it simple and light
- we might call it on `using Simuleos` by default
- Users needs to call it at least one explicitly at an empty project
- All workflows must start by this call
    - implicitly or explicitly