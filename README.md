## Raydrench

A Trenchbroom-style `.map` brush loader for [raylib-d](https://github.com/schveiguy/raylib-d), written in D.

Raydrench parses Valve220-format `.map` files (as exported by TrenchBroom), converts brushes into convex polygons, builds raylib `Model`s from them, and provides simple brush-based collision resolution.

## Features

- Parses `.map` files (entities, brushes, brush faces, Valve220 UVs)
- Converts brush planes into polygons via plane-intersection
- Automatically loads and caches textures (tries common raylib-supported formats)
- Builds renderable raylib meshes/models from parsed brushes
- Basic AABB/plane-based player collision resolution against brush geometry

## Requirements

- [DUB](https://code.dlang.org/) and a D compiler (DMD/LDC)
- [raylib-d](https://code.dlang.org/packages/raylib-d)
- raylib installed on your system

## Build

<details>

Build the library:

```sh
cd src
dub build
```

Build and run the example:

```sh
cd example
dub run
```
</details>

## Include in your project

<details>

### Add as a git submodule

```sh
git submodule add https://github.com/zariep-software/raydrench.git deps/raydrench
git submodule update --init --recursive
```

This drops the raydrench repo into `deps/raydrench` in your project, with `deps/raydrench/src` being the actual dub package (same as this repo's `src/` folder).

### Reference it in `dub.json`

Point the `raydrench` dependency at the local submodule path instead of fetching it from the DUB registry:

```json
"dependencies": {
  "raylib-d": "~>6.0.1",
  "raydrench": {
    "path": "deps/raydrench/src"
		}
	}
```
</details>