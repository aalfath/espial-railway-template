# Changelog

Each entry is one version of this Railway template. Breaking changes are listed first.

## 0.0.42-1 (2026-11-24)

First release of the template.

* Espial 0.0.42 (`jonschoning/espial:0.0.42@sha256:52501164589ccb65c42ffb33c2f042a86042e3c1e3d9313f6560dc9c83b7901b`).
* Static BusyBox 1.37.0 (`busybox:1.37.0-musl`) added for the start script and `railway ssh`.
* Start script: database migration, owner account from `ESPIAL_USERNAME`/`ESPIAL_PASSWORD` before the port opens, session key kept on the volume, runtime threads from the CPU quota, non-zero exit when Espial stops.
