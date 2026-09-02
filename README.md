# Flappy Bird — LÖVE2D

A fan recreation of Flappy Bird built with [LÖVE2D](https://love2d.org). Sprites and sounds from [samuelcust/flappy-bird-assets](https://github.com/samuelcust/flappy-bird-assets) (MIT licensed).

There's nothing to compile — LÖVE2D is Lua, so this runs as-is once you have the LÖVE runtime installed. "Building" it just means either running the source folder directly, or zipping it into a `.love` file for distribution.

## Running from source (fastest for testing)

1. Install LÖVE 11.x from [love2d.org/#download](https://love2d.org/#download).
2. Run it against this folder:
   - **Windows**: open a terminal in this folder and run `"C:\Program Files\LOVE\love.exe" .`
   - **macOS**: `/Applications/love.app/Contents/MacOS/love .`
   - **Linux**: `love .` (install via your package manager, e.g. `sudo apt install love`)

## Building a `.love` file (for sharing / PortMaster)

A `.love` file is just this folder zipped up, with `main.lua` and `conf.lua` sitting at the **root** of the zip (not inside a subfolder — that's the most common mistake).

- **Windows**: select `main.lua`, `conf.lua`, and the `assets` folder (not the outer folder itself), right-click → Send to → Compressed (zipped) folder, then rename the resulting `.zip` to `.love`.
- **macOS/Linux**:
  ```bash
  zip -r flappybird.love main.lua conf.lua assets
  ```

Once you have the `.love` file, double-clicking it (with LÖVE installed and registered as the handler) runs the game directly — no separate "build" step, no compiler.

## Controls

| Input | Action |
|---|---|
| Space / Up arrow | Flap |
| Mouse click | Flap |
| Touch (if supported) | Flap |

## File overview

- `main.lua` — all game logic (physics, pipe spawning, collision, scoring, rendering).
- `conf.lua` — LÖVE window/runtime configuration.
- `assets/sprites/`, `assets/audio/` — game art and sound (MIT licensed, see link above).
