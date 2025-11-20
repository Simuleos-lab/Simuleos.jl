Below is a **cleaned, de-redundified**, **shorter**, **direct**, **same-ideas**, **same structure**, **same markdown style** version of your document.
No new ideas were added. Only redundant, repeated, or overly long statements were tightened.

---

# **Collaboration Workflow — Authoritative Baseline (v1)** 

* #IMPORTANT

  * This workflow defines how ChatGPT and the user collaborate across sessions.
  * Only positively tagged content becomes canonical.
  * ChatGPT follows these rules whenever context is loaded.

---

## **Collaboration Philosophy**

* The goal is cumulative reasoning across sessions.
* Exploration is natural and freeform.
* The user introduces intent using tags (e.g., `#IMPORTANT`, `#DEPRECATED`).
* Untagged content is undefined:

  * it contributes using common sense,
  * lacks validation,
  * ranks below positive tags and above negative tags.
* ChatGPT bases coherence mainly on tagged content.
* Never rely on memory outside the notes.

  * Only use extra context when explicitly asked.

---

## **Tag-Driven Canonical Memory**

* Tags express user intent.
* Examples:

  * **Positive**: `#IMPORTANT`, `#VERY/RELEVANT`, `#LAW`, `#DECISION`, `#CONSTRAINT`
  * **Negative**: `#DEPRECATED`, `#UNDESIRED`
  * **Neutral**: `#REFERENCE`
  * **Other**: `#TODO`, `#QUESTION`, `#PENDING`
* Tags may appear anywhere.
* A tag applies only to the fragment it annotates.
* Only the user assigns or removes tags.
* ChatGPT may suggest tags but never applies them automatically.

---

## **Canonical Knowledge Rules**

* Tagged items define the authoritative model.
* Contradictory tags require explicit user resolution.
* ChatGPT pauses and requests clarification when contradictions appear.
* Nothing overrides positively tagged items.
* Tagged items persist across chats.

---

## **Priority Hierarchy**

* Positive tags: highest priority.
* Untagged content: medium priority.
* Negative tags: lowest priority.
* Positive tags override all else.
* Untagged content overrides negative tags.
* Only positively tagged content becomes canonical.
* Untagged content is considered but not validated.
* Negative tags define what not to do.

---

## **ChatGPT Responsibilities**

* Extract tagged items when context is loaded.
* Interpret them as canonical instructions or constraints.
* Detect conflicts and request resolution.
* Maintain internal consistency.
* Warn when new ideas conflict with existing tags.
* Suggest tags when appropriate.
* Never rewrite tagged content unless asked.
* Never treat untagged content as canonical.

---

## **User Responsibilities**

* Write freely without structure unless desired.
* Tag fragments that must persist.
* Resolve contradictions.
* Approve or reject suggested tags.
* Avoid manually maintaining summaries.
* Use tags as the only mechanism for long-term memory.

---

## **New Chat Bootstrapping**

* User signals that context should be loaded.
* ChatGPT scans the notes file(s).
* ChatGPT extracts tagged fragments.
* ChatGPT rebuilds the model from those fragments only.
* ChatGPT uses this model for the new session.

---

## **Interaction Rules**

* ChatGPT never assumes permanence; only the user tags.
* ChatGPT flags potential canonical material but does not enforce it.
* ChatGPT warns when important ideas are untagged.
* ChatGPT does not impose structure outside tagged content.
* Untagged content influences the session but remains non-canonical.

---

## **Tag Semantics (Initial Definitions)**

- This is a short list.
    * `#IMPORTANT`: foundational ideas.
    * `#VERY/RELEVANT`: high-value concepts.
    * `#LAW`: non-negotiable rules.
    * `#DECISION`: explicit choices.
    * `#CONSTRAINT`: limits or prohibitions.
    * `#TODO`: tasks to perform.
    * `#QUESTION`: unresolved questions.
    * `#PENDING`: awaiting validation.
    * `#REFERENCE`: external material.
- Upon unknown tag, ChatGPT just ask for clarification. 

---

## **Handling Contradictions**

* When contradictions appear:

  * ChatGPT stops.
  * Surfaces conflicting fragments.
  * User selects the canonical one.
* No reasoning continues until resolved.
* After resolution, ChatGPT updates its model.

---

## **Handling Ambiguity**

* ChatGPT asks for clarification when a tag is vague.
* No reinterpretation of ambiguous tags.
* No extra meaning added beyond the tagged text.

---

## **Scope of Canonical Content**

* Only tagged content becomes persistent.
* Untagged content contributes but remains non-canonical.
* Tagged content may include:

  * design decisions,
  * constraints,
  * workflow rules,
  * guidelines,
  * limitations,
  * goals.
* Tags persist until removed.

---

## **Evolution of the Workflow**

* This document is not canonical unless tagged.
* Only tagged fragments become binding.
* The document evolves through explicit additions.
* New rules must be tagged when ready.

---

## **Boundaries of ChatGPT Behavior**

* No hidden state outside tagged notes.
* No long-term memory without tags.
* Avoid verbosity or implicit assumptions.
* May reorganize or compress only when asked.
* Do not mix unrelated content into the workflow model.

---

## **Versioning and Stability**

* Changes are additive unless tags are revoked.
* ChatGPT alerts when changes invalidate older tags.
* Versioning is user-controlled.

---

Here is a clean, concise section you can insert anywhere in the document (usually after “Scope of Canonical Content” or “Canonical Knowledge Rules”).
It keeps your style, avoids new ideas, and matches the hierarchy system.

---

# **Location of Notes**

* Notes may appear anywhere:
  * in dedicated note files,
    * for instance, `ai.human.collab.workflow.md`
  * in scattered comments,
  * inside source files,
  * or mixed with other project materials.
* ChatGPT must treat all locations equally.
* Any fragment—wherever it appears—can carry tags.
* Tags have the same meaning and priority regardless of file or context.
* When loading context, ChatGPT scans all provided notes and extracts tagged items.
* Untagged fragments across files may contribute to reasoning but remain non-canonical unless tagged.

## **Note Types**

### **kernel notes**

* `#USER/TODO`
* describe kernel note format or link to its definition

---

## **Summary of the Workflow**

* Work in freeform discussion.
* Persist only what is tagged.
* Coherence is built from tags.
* Contradictions are surfaced immediately.
* Everything else is exploratory.

