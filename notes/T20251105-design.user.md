* Existing objects:
    * Representation = Meaning + Matter
    * Record:
        * A whole data point.
        * I can include lite and non-lite data
    * Context
        * If it is lite, it can be used as Context
        * If extra context needs to be added, It must be lite
    * Artifact
        * If is the non-lite part of a Record
            * So, it needs extra lite fields to provide context

* **Context**
    * Context is not another storage layer; it’s a *projection* of that same data universe, selected according to explicit rules.
    * The projection is defined by constraints: lightweight, human-readable, and stable over time.
    * Context defined by its value type:
        * Every data point is conceptualized as a set of key–value pairs (like a JS object or dictionary).
        * Within any data point, all pairs whose values are *lite* (serializable, simple, human-readable) are considered **Context**.
        * This means Context is not separate data — it is the *lite subset* of an existing structure.
        * Non-lite values (heavy data, binary objects, system states) are part of the same data point but are not Context.
    * Context defined by its function:
        * The purpose of Context is to help answer any possible question about a data point.
        * It exists to describe and explain — to provide interpretability.
        * Examples of contextual questions include:
            * Which parameters were used?
            * What software or code version generated this data?
            * Who recorded or registered this?
            * When and under what conditions did it happen?
        * Some key–value pairs exist solely for this purpose: their only role is to provide human and analytical context, not raw information.
    * Context is not just type of data; it is a **stance toward data** — a deliberate act of description.
    * It emerges when the user or system decides to describe an issue, an event, or a moment.
    * It is reflexive: data about data, or data about the situation in which data arises.
    * The distinction between data and context is interpretative, but also structural.
    * Context exists to describe as precisely as possible an *issue*.
        * An issue can be anything: a simulation moment, an event, an experiment, or a dataset.
            * An issue is just the subject of a Context
            * An Issue can be fully describe by several Records
        * Example: when developing a model, each test iteration is an issue; its Contexts records parameters, notes, and meaning.
    * The Context is **forced to be lite**.
        * It must be serializable, small, and self-contained.
        * Non-lite data must be referenced, not embedded.
        * This technical rule doubles as a philosophical one: it forces explicit meaning and clarity.
        * Context represents **epistemic compression** — keeping only what’s necessary to reconstruct meaning, not the full event.
        * Instead of storing every detail, the user curates what is *contextually significant*.
        * The constraint of “lite” forces intentionality and selects only meaningful information.
        * It’s the result of conscious curation — the act of deciding what matters.
        * Automated extraction can help, but Context mainly exists when someone (human or algorithm) *decides to describe*.
        * Context can be created both at **priori** and at **posteriori** from the creation of an Issue.
    * Sometimes, data is **self-explanatory**.
        * 
        * In those cases, the Issue's data also instanciate Context.
    * When interpretation or additional explanation is required, Context becomes distinct.

    * Context formalizes **awareness**.
        * It’s how the system observes itself and expresses understanding of what it’s doing.
        * Each Context is a small act of self-description — an assertion of “this is what’s happening and why it matters.”
        * SimuleOs is therefore a simulation system that is *aware* of its own meaning.
    * The process of Context extraction **creates meaning**.
        * Deciding what belongs in the lite subset transforms data into structured knowledge.
        * The rule of “lite only” enforces a clean boundary between what is *semantic* and what is *raw*.
    * Context must be **future-proof**.
        * Readable, stable, interpretable even if raw data or code disappears.
        * Acts as a durable descriptor, capable of reconstructing or at least explaining what was once there.
    * Contexts are designed for **queryability and efficiency**.
        * Because they are small and structured, they can be indexed and searched rapidly.
        * Contexts are the handles by which larger data structures are found, compared, or reasoned about.
    * Context provides **human interpretability**.
        * It holds notes, symbolic labels, and meanings expressed by users or agents.
        * It bridges computation with comprehension
    * Context operates along a **semantic gradient**:
        * Raw data → direct record of reality or computation.
        * Derived data → processed or summarized results.
        * Context → descriptors and interpretations that give meaning.
        * The transition between them is fluid and determined by interpretation.
    * The **lite constraint** is central to the architecture.
        * It ensures that Contexts are portable, comparable, and verifiable.
        * Lite structures can be hashed, diffed, and versioned efficiently.
        * Enforcing this constraint keeps Contexts clean and durable.
    * Context enables **lineage and reproducibility**.
        * Each Context can reference others, forming a chain of meaning and causality.
        * Heavy data can change or move, but Contexts maintain the narrative of how one state led to another.
    * A Context must capable to uniquely index its parent Record 
        * for instance, all Context should be unique
    * The storage model is **content-addressable**.
        * Every Context or artifact is named by its content hash.
            * WIP
        * This guarantees immutability and traceability.
        * Non-lite blobs are linked, not stored inline, keeping the semantic and material layers distinct.
    * Context extraction is a **disciplinary mechanism**.
        * It obliges the user or system to confront what is essential.
        * It exposes ambiguity by making every piece of contextual information explicit.
    * Context is **the minimal sufficient description** of a situation.
        * It contains just enough to identify, interpret, and communicate the meaning of an event.
    * Context bridges **semantics and storage**.
        * It’s light enough to compute, rich enough to describe.
        * It connects the technical (data, code, environment) with the interpretive (purpose, reason, understanding).
    * A collection of Contexts forms a **map of understanding**.
        * Each Context marks a moment of awareness — a node of meaning in the system’s history.
        * Together they create a semantic topology: a network of how understanding evolves.
        * Even if raw data is lost, this map preserves the structure of knowledge.
    * Every piece of data has a potential Context, but only some Contexts are made explicit.
        * The explicit ones define the system’s consciousness of itself.
        * Making Context explicit transforms computation into reflection.
        * Context is never finished
         * Every new question about the data (Records) should add context

    * Context serves both **functional** and **philosophical** purposes.
        * Functionally: it supports reproducibility, efficient queries, lightweight persistence.
        * Philosophically: it embodies self-awareness, intentionality, and meaning.
    * Generating Context transforms a process into a narrative.
        * The system doesn’t just perform operations — it tells the story of what it did and why.
        * Context is aso logging
