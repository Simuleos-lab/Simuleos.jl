## The index workflow

The project utilizes automated agents to assist in maintaining the design index. The roles are clearly defined:
    - Agents: Discover and report potential index candidates. They are read-only and never modify the index directly. Their reports are ephemeral and printed to the chat.
    - User: The human developer is the sole author of the index. They review the agent's reports, decide what to include, and are responsible for writing the final index entries.
This division of labor ensures that the human developer remains in control of the project's design and architectural direction.