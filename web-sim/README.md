# Buzz Route 3D sim

Static three.js scene of the Georgia Tech campus with a replay of recorded Stinger bus GPS (Blue buses are synthetic). `data.js` is a classic script (works from `file://`); three.js loads from a CDN.

```bash
cd web-sim && python -m http.server 8080   # http://localhost:8080
```

- `?embed=1` hides all page chrome (scene only).
- `?demo=1` feeds a fixture trip (Student Center to Klaus) and auto-starts the walker.
- Host protocol (plan.show, walk.start, sim.pick, ...): see `docs/contracts/sim_bridge_v0.md`.
- Walker is a simple figure (head, torso, swinging arms and legs); it idles while waiting and sits on the bus marker while riding. `prefers-reduced-motion` cuts the camera instead of flying.
- Rendering pauses while the page is hidden. Solar, materials and energy UI are removed (hidden, code guarded).
