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
- Dispatch a subagent → `subagent` with the requested type; use `general-purpose` when the skill requests a generic worker or reviewer.
- Track dispatched work → `job_status`, `job_block`, `job_result`, or `job_cancel`.
- Create or update todos → `todo_create`, `todo_update`, and `todo_complete`.
- Fetch a URL → `web_fetch`.
- Search the web → `web_search` when a provider is configured.

Subagents receive task-specific prompt files by content or explicit file reference; Superpowers reviewer and implementer Markdown files are prompts, not Polytoken subagent types.
