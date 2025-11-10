%% Note Body --------------------------------------------------- %%

%% Write here %%

#NOTE 
- Good contexnt https://adactio.com/articles/1522/

#NOTE
- Use 'modeling' in the name of the ContextNode
    - In some ways describing so precisly something is in fact modeling
    - So, this objects are just a modeling units.
        - MetaModel
        - ModelBlob
        - modlob
        - BlobModel

***
#NOTE
1. Write a script
2. run it
    2.1 state 0
    2.2 state 1
    2.3 state 2
        2.3.1 Describe state 2
        2.3.2 Use the same encoding as the programming language

***
#NOTE
# Obsidian Integration of out of vault files

At first can be just md notes
We can deal with the problem of input
    We can add the notes to Obsidian as a syblink
    But, in the background make a backup of the notes into the vault.
        This is important because we can then, at the same time, have the file content in the vault repo, etc...

***
#DESIGN
So, Im forcing the programmer/tools to produce a text encoded database that has layers.
Each layer take an initial tree and do an operation with it.
There will be a set of builtin Tree standards 
    The tooling in Simuleos and beyond will use such standard
    So, they will be faviour in this system.
    That is why it needs to be simple and as less opinative as convenient. 

***
#THINKING 
The problem of the two data types

There is a data type that is the ContextData
The ContextData is restricteted to be lite and human readable.
But not all data is like that
    Think on a matrix or a C mapped object
This other data BinData, is considered form-free

But one of the main application of ContextData is that it describes the current enviroment.
In a conveniant way. 
So, at the momment we want to store a BinData (or Data in general)
We can produce the ContextData that describes the enviroment which characterize BinData

***
#TODO 
A BinData node is a ContextNode that describes how to load the Data.
For instance
```json
{
    "__type__": "BinNode",
    "load.path": "A/RELATIVE/PATH.json"
    "blobs": {
    
    }
}
```
    In this case no info about the loading is suggested other than the extemssion. 
    It can be enough for many apps.
        Just trusting the source common sense.
        Of course there will be populat conventions. 
    You can be more detailed...

***
#NOTE
But how we know a node is a BinNode.
There is a "__type__" magic key that tells you that
By default is a "ContextData" or "AnyData"

***
#NOTE
There will be a "__labels__" too.
Which returns a vector of just computed labels. 

***
#NOTE
So, All the DB is just a bunch of jsons. 
- implementation will provide the tooling for loading/linking bin data
- The ContextTree is not opinative
- You can add as much context as you want to aid the loading
```julia
{
    "__type__": "BinNode"
    "load.path": "A/RELATIVE/PATH.jld"
    "Project.toml": "..."
}
```

***
#NOTE
Untyped data at input state.
- You can keep it on ram in the julia runtime
- but hashed or filtered or `nothing`it
```json
{
    // Non-Context type by default 
    // - degrade to nothing
    "complex.model": null, 
    "param.x.value": 12.34
},
{
    // Non-Context type by default 
    // - or to a ContextNode describing it
    "complex.model": {
        "value": null, 
        "julia.type": "MetNet{Float64}"
    }, 
    "param.x.value": 12.34
    
}
```

%% Tags ------------------------------------------------------- %%
#Vault/notebook 
#Editor/josePereiro
