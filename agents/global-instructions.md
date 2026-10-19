# Personal instructions

## Browser tooling

Select by the coding-agent host, not its model provider:

- **Claude Code and Codex:** prefer built-in methods. Use `agent-browser` or
  `playwright-cli` only when the user explicitly requests that CLI or skill.
- **Pi:** select either skill automatically by the immediate activity:
  - **Research → `agent-browser`:** gather external information through browser
    interaction, including rendered documentation and other products' behavior.
  - **Engineering → `playwright-cli`:** inspect, reproduce bugs in, debug, or
    validate the application under development; author or maintain Playwright
    tests. An existing test suite is not required for UI investigation.

Explicit tool requests take precedence. Classify each activity, not the whole
assignment: reading framework docs is research even during an engineering task.
Keep ordinary search and text retrieval on the existing search/text tools when
browser interaction is unnecessary. Read the selected skill before using its CLI.
