# wrap-sqlite

> A drop-in shim for `better-sqlite3` that maps to `node:sqlite` (Node.js built-in)

## Why?

`better-sqlite3` requires a native addon (compiled C++). `node:sqlite` is built directly into Node.js ≥ 22.5. This package lets you swap out `better-sqlite3` for zero native dependencies, using only the Node.js built-in.

## Transparency

This code was YOLO'd with Claude