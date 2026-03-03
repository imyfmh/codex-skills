---
name: frontend-dual-registry-install
description: Install frontend project dependencies with split public/internal registries. Use when a Node-based frontend project has a package.json and needs initialization or dependency installation, especially when internal packages use the geo-* or geostar-* prefix. Always trigger before running npm/pnpm install in engineered frontend repositories, always ask user to choose npm or pnpm first, and prefer escalated execution for registry access.
---

# Frontend Dual Registry Install

Execute dependency installation in two phases so public packages come from a public mirror and internal `geo-*` / `geostar-*` packages come from the internal registry.

## Preconditions

- Run in a project root containing `package.json`.
- Use for frontend engineered projects that need `node_modules` initialization or dependency install.
- Execute this skill before any direct `npm install`, `pnpm install`, `npm run dev` preparation, or similar bootstrap flow.

## Workflow

1. Ask the user which package manager to use: `npm` or `pnpm`.
2. Treat package manager confirmation as mandatory. Do not assume default.
3. Request escalated execution before running install commands, because network sandbox often blocks registry access.
4. Run the bundled script from the project root:
   - `bash <skill-path>/scripts/install_with_dual_registry.sh npm`
   - `bash <skill-path>/scripts/install_with_dual_registry.sh pnpm`
5. Run project commands (`npm run dev` / `pnpm dev`) only after all required internal dependency installation steps finish successfully.

## What the script does

1. Read `package.json` and remove every dependency entry whose package name starts with `geo-` or `geostar-` from:
   - `dependencies`
   - `devDependencies`
   - `optionalDependencies`
   - `peerDependencies`
2. Backup removed entries to `./.geo-internal-deps-backup.json` in current directory.
3. Delete lock file before installation:
   - `npm` => delete `package-lock.json`
   - `pnpm` => delete `pnpm-lock.yaml`
4. Install remaining dependencies from public registry:
   - `--registry=https://registry.npmmirror.com`
5. If backup file does not exist or is empty, stop without internal install.
6. If backup file has internal dependencies, install only those packages from internal registry, one package per command:
   - `--registry=http://172.17.0.155:8768`
7. If any internal install command fails, do not retry, stop immediately, and output exactly:
   - `内部依赖安装失败，请检查。`

## Notes

- Do not retry failed internal dependency installation.
- Enforce execution order: public install -> check temp file -> internal install (if needed) -> run project.
- Keep backup file for troubleshooting unless user asks to remove it.
