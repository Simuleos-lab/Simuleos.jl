## SimuleOs: workflows
- a conceptual description of important functionalities of SimuleOs
- for instance
    - scope recording
    - database reading
    - system manadgment 
        - eg: rm, gc, rename, archive, etc...

## Workflows: Scope Recording
-  Key workflow: embed simuleos macros to capture program scopes into .simuleos database
- Steps: init → session → record scopes (with labels/context) → commit → repeat
- Globals-based interface preferred (macros use implicit current_session)


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