# Automation gaps

## Meshy credential and paid path verification

`MESHY_API_KEY` is not present, so no authenticated Meshy request or credit-consuming generation
was executed. The official REST endpoints and official MCP package are wired, but Meshy remains
FAIL until `python3 scripts/tests/test_meshy.py` passes. This is the only required user action.

The Blender multi-clip merge was verified by importing a second rigged glTF, attaching its action
through NLA, exporting GLB, and re-importing the GLB. It has not yet been exercised with an actual
Meshy Animation API result because that also requires the key and credits.

## Semantic art quality

V1 automatically validates technical properties: readability, mesh/triangle budget, degenerate
topology, bounds, scale, ground contact, materials/textures, skeleton/bones, clips, durations, and
the animation contract. It cannot reliably decide subjective anatomy, silhouette quality, or
top-down art direction. Retry decisions cover measurable failures; subjective visual acceptance
still needs a future vision-scoring policy with project-specific thresholds.

## Non-manifold geometry

Non-manifold edge counts are reported but do not fail a build by themselves because layered game
clothing and open surfaces can be intentional. Degenerate geometry and triangle-budget overflow do
fail. A stricter per-character topology policy can be added to the spec when asset conventions are
known.

## Blender MCP

No Blender MCP is installed. Blender Python in background mode is the deterministic supported API
and covers every V1 operation. Adding a third-party MCP would expand shell/file authority without
improving the reproducible build path.
