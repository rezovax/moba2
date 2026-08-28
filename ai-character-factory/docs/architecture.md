# Architecture

The orchestrator owns a build ledger and invokes three replaceable adapters:

```text
character_spec.json
  → spec validation
  → Meshy REST jobs and per-stage checkpoints
  → Blender background normalization, validation, render, GLB export
  → Godot asset copy/import, generated hero scene, AnimationTree contract
  → headless behavior test + Xvfb screenshot test
  → report.json
```

REST is the production Meshy interface because it is deterministic and usable outside an agent
session. The official Meshy MCP exposes the same API for Codex exploration. Blender is only a
background Python backend. Godot uses textual scenes/scripts and CLI import/testing; MCP adds live
inspection but is not a build dependency.

Every Meshy task writes its task ID immediately. Retries reuse an active successful task and create
a replacement only after a terminal failure. Motion and animation clips have separate checkpoints,
so one failed clip does not repeat model generation, texturing, remesh, or rigging.

The Godot framework separates movement, health, combat, abilities, targeting, animation, status
effects, audio, and VFX. `HeroBase` owns its children. Cross-component death/damage events use
signals. Future server authority is deliberately outside this client-only test project.
