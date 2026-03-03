# Codex Skills

A categorized collection of reusable Codex skills.

## Directory Layout

- `skills/frontend/dependency-install/frontend-dual-registry-install`
  - Install frontend dependencies with dual registries.
  - Split public packages and internal packages by prefix:
    - internal prefixes: `geo-`, `geostar-`
  - Required flow:
    1. Ask user to choose `npm` or `pnpm`
    2. Remove corresponding lock file
    3. Install public deps from `https://registry.npmmirror.com`
    4. Install internal deps one-by-one from `http://172.17.0.155:8768`
    5. Stop immediately on any internal install failure (no retry)

## Usage

Use the skill folder directly in Codex skills environment.
