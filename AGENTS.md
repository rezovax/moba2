# MOBA2 agent instructions

These rules apply to every AI agent working in this repository. Treat them as
project requirements, not suggestions.

## Current scope

- The active product is the Godot 4.7 client in `client/`.
- The future authoritative server must live outside `client/`. Do not create
  server code or networking architecture until a task explicitly requires it.
- The current entry scene is `client/scenes/bootstrap/main.tscn`.
- Keep the client runnable after every completed change.

## Sources of truth

- `client/project.godot` owns engine and project settings.
- `.gdlintrc` owns GDScript lint limits and naming rules.
- `tools/check_gdscript_quality.py` owns additional anti-slop rules.
- `tools/check.sh` is the mandatory local quality gate.
- Do not weaken, bypass, suppress, or exclude files from these checks merely to
  make generated code pass. Fix the design or implementation instead.

## Required workflow

1. Before non-trivial work, search GBrain for MOBA2 decisions and established
   patterns.
2. Use CodeGraph for structural questions such as definitions, callers,
   callees, flows, and impact. Use text search only for literal content.
3. Inspect the affected scene, script, resource, and project settings before
   editing. Preserve unrelated user changes.
4. Make the smallest cohesive change that fully solves the task.
5. Run `./tools/check.sh` before reporting completion.
6. For gameplay or visual changes, run the affected scene. Capture and inspect
   a screenshot when visual correctness is part of the task.
7. Report the validation commands and results. Never claim something was
   tested when it was only inspected.

## Project organization

- Group files by feature. Mirror scene and script paths where practical, for
  example `scenes/combat/` and `scripts/combat/`.
- Put reusable code in `client/scripts/`; do not embed non-trivial scripts in
  `.tscn` files.
- Store editable resources as text (`.tscn` and `.tres`) when possible.
- Put assets under a type-specific directory in `client/assets/`.
- Put automated client tests under `client/tests/`.
- Treat `client/addons/` as vendored code. Do not edit an addon unless the task
  explicitly upgrades or fixes that integration.
- Never commit `client/.godot/`, imported caches, local logs, or generated
  screenshots.

## Architecture rules

- Prefer small, feature-focused scenes and composition over deep inheritance.
- A node owns its children and may call them directly. Use signals for events
  crossing ownership boundaries; do not create signal chains without need.
- Keep gameplay state, presentation, and UI responsibilities separate.
- Use typed `Resource` classes for reusable configuration and game data.
- Add an Autoload only for genuinely process-wide state or services. Do not use
  globals as a shortcut around clear ownership.
- Define player actions in InputMap. Do not hardcode physical keys in gameplay
  code.
- Put deterministic movement and collision logic in `_physics_process()` and
  frame-dependent presentation in `_process()`.
- Avoid per-frame allocations, repeated tree searches, and unnecessary work in
  `_process()` or `_physics_process()`.
- The future server will be authoritative for competitive game state. Do not
  design security-sensitive rules that trust only the client.

## GDScript rules

- Use explicit static types for constants, fields, parameters, local variables,
  return values, arrays, dictionaries, signals, and resources.
- Do not use `:=`; inferred declarations are errors in this project.
- Avoid `Variant`. At engine or serialization boundaries, validate and convert
  it immediately to a concrete type.
- Follow Godot naming conventions enforced by `.gdlintrc`: `PascalCase` for
  classes and enums, `snake_case` for functions and variables, and
  `UPPER_SNAKE_CASE` for constants and enum members.
- Use one leading underscore for private members and intentionally unused
  callback parameters.
- Use typed `@onready` references or exported typed references. Avoid repeated
  string-based node lookups and brittle absolute NodePaths.
- Handle returned `Error` values and nullable results explicitly.
- Comments must explain intent, invariants, or tradeoffs. Do not narrate obvious
  syntax or leave speculative prose in production code.
- No dead code, duplicate helpers, speculative abstractions, placeholder APIs,
  or copy-pasted variants.

## Mandatory anti-slop limits

Production GDScript must satisfy all of the following:

- Cyclomatic complexity: at most 5 per function (Radon rank A).
- Function branches: at most 5.
- Function statements: at most 20.
- Function arguments: at most 4.
- Function returns: at most 3.
- Public methods per class: at most 8.
- Class size: at most 250 lines.
- File size: at most 350 lines.
- Line length: at most 100 characters.
- `@warning_ignore`, gdlint suppression directives, placeholder `pass`, and
  `TODO`/`FIXME`/`HACK`/`XXX` markers are forbidden.
- Every configured Godot warning is an error.

If a limit is exceeded, split responsibilities or simplify control flow. Do not
change the threshold unless the user explicitly asks to change project policy.

## Tests and correctness

- Add or update tests for behavior changes, regressions, state transitions, and
  edge cases when a test harness exists for the affected area.
- Prefer deterministic tests. Do not depend on wall-clock timing, random seeds,
  external services, or frame races without controlling them.
- A scene merely opening is not sufficient validation for gameplay behavior.
- Do not replace real dependencies with mocks when an integration or scene test
  is required to prove the behavior.
- A task is complete only when relevant checks pass with no warnings or errors.

## Godot MCP

This repository uses `@yanhuifair/godot-mcp`; its editor plugin lives at
`client/addons/godot-mcp/`.

- Never guess a tool name. Call `search_tools` with a focused keyword first.
- Call `get_status` before operations that require a live editor or runtime.
- On `EDITOR_NOT_REACHABLE` or `RUNTIME_NOT_REACHABLE`, call `get_status` once,
  follow its repair hint, and do not blindly retry the same command.
- Prefer file tools for deterministic source edits. Use `editor_*` tools only
  for live editor state and `runtime_*` tools only while the game is running.
- Read a scene before mutating its tree so parent paths and node types are known.
- Keep live scene mutations undoable. Use `editor_undo` when asked to revert an
  editor operation.
- After live changes, save the scene and verify the resulting files and runtime
  behavior.

## Completion checklist

Before saying a task is done, confirm all applicable items:

- The requested behavior is implemented, not stubbed.
- Architecture and ownership remain clear.
- GDScript is explicitly typed and contains no suppressions or placeholders.
- Relevant tests were added or updated.
- `./tools/check.sh` passed.
- The affected scene or project was run when runtime behavior changed.
- Visual output was inspected when presentation changed.
- No generated files, unrelated edits, or secrets were introduced.
