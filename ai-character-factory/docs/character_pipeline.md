# Character pipeline

Copy `characters/_template/character_spec.json`, give it a unique ID, and choose one source mode:

- `meshy_text` — prompt to mesh, texture, remesh, rig, and motions;
- `meshy_image` — one URL in `source.image_urls`;
- `meshy_multi_image` — up to four views of the same character;
- `fixture` — local verification only, never used as a production generator.

Run:

```bash
python3 -m pipeline.orchestrator build characters/<hero>/character_spec.json
```

Meshy source modes consume credits. Current official pricing and availability must be checked before
large runs. The orchestrator requests a low-poly T-pose, PBR texture refine, target-polycount remesh,
humanoid rig, economical Swift text-to-motion clips, and one retargeted animation per contract.

Blender merges clip GLBs onto the main armature, normalizes transforms and height, places the feet at
Z=0, validates, renders front/back/side/MOBA previews, and exports one GLB. Godot receives the GLB,
generated stats scene, mapping, and loop metadata. `HeroAnimationController` constructs the
AnimationTree state machine at runtime.

The arena runs idle → run → attack → cast → hit → death twice: headless for deterministic logs and
under Xvfb for six PNG screenshots. Any process failure, missing PASS marker, runtime script error,
validation failure, or missing screenshot fails the build.
