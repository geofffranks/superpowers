# Polytoken Tool Mapping

Use Polytoken's native tools when a Superpowers skill requests an action:

- Invoke a skill → `skill`; translate `superpowers:<name>` to `<name>`.
- Ask the human partner a blocking structured question → `ask_user_question`.
- Read a file → `file_read`.
- Create or overwrite a file → `file_write`.
- Make a targeted edit → `file_edit_search_replace`.
- Delete a file → `shell_exec` with the narrowest appropriate removal command.
- Find files by path → `glob`.
- Search file contents → `grep`.
- Run a shell command once → `shell_exec`.
- Wait for an idempotent readiness condition → `shell_monitor`.
- Dispatch a subagent → `subagent` with the requested type. Skills name specific types (`implementer`, `reviewer`, `validator`, `researcher`); use the named type, and fall back to `general-purpose` only when no type is specified. (implementer/researcher/code-reviewer are preferentially routed through the `clod-subagent` MCP tool — see the dispatching skill; this harness `subagent` path is the fallback.)
- Track dispatched work → `job_status`, `job_block`, `job_result`, or `job_cancel`.
- Create or update todos → `todo_create`, `todo_update`, and `todo_complete`.
- Fetch a URL → `web_fetch`.
- Search the web → `web_search` when a provider is configured.

Subagent definitions (`implementer`, `reviewer`, `validator`) carry their own methodology; the skill's prompt-template files are dispatch recipes that pass task-specific context, not standalone prompts. Use the named subagent type and fill the template's placeholders.
