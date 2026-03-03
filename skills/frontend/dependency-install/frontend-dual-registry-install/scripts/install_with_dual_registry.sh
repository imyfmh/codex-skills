#!/usr/bin/env bash
set -euo pipefail

MANAGER="${1:-}"

if [[ -z "$MANAGER" ]]; then
  echo "Usage: $0 <npm|pnpm>"
  exit 1
fi

if [[ "$MANAGER" != "npm" && "$MANAGER" != "pnpm" ]]; then
  echo "Unsupported package manager: $MANAGER"
  echo "Expected: npm or pnpm"
  exit 1
fi

if [[ ! -f package.json ]]; then
  echo "package.json not found in current directory"
  exit 1
fi

TMP_FILE="./.geo-internal-deps-backup.json"
PUBLIC_REGISTRY="https://registry.npmmirror.com"
INTERNAL_REGISTRY="http://172.17.0.155:8768"
LOCK_FILE=""

if [[ "$MANAGER" == "npm" ]]; then
  LOCK_FILE="package-lock.json"
else
  LOCK_FILE="pnpm-lock.yaml"
fi

if [[ -f "$LOCK_FILE" ]]; then
  rm -f "$LOCK_FILE"
  echo "Removed lock file: $LOCK_FILE"
fi

# 1) Extract and remove geo-*/geostar-* dependencies from package.json.
node - <<'NODE'
const fs = require('fs');
const path = require('path');

const pkgPath = path.resolve(process.cwd(), 'package.json');
const tmpPath = path.resolve(process.cwd(), '.geo-internal-deps-backup.json');

const pkgRaw = fs.readFileSync(pkgPath, 'utf8');
const pkg = JSON.parse(pkgRaw);
const sections = ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies'];

const removed = {};
let removedCount = 0;

for (const section of sections) {
  const deps = pkg[section];
  if (!deps || typeof deps !== 'object') continue;

  const names = Object.keys(deps).filter(
    (name) => name.startsWith('geo-') || name.startsWith('geostar-')
  );
  if (!names.length) continue;

  removed[section] = {};
  for (const name of names) {
    removed[section][name] = deps[name];
    delete deps[name];
    removedCount += 1;
  }

  if (Object.keys(pkg[section]).length === 0) {
    delete pkg[section];
  }
}

fs.writeFileSync(pkgPath, `${JSON.stringify(pkg, null, 2)}\n`, 'utf8');

if (removedCount > 0) {
  const backup = {
    createdAt: new Date().toISOString(),
    removed,
  };
  fs.writeFileSync(tmpPath, `${JSON.stringify(backup, null, 2)}\n`, 'utf8');
  console.log(`Removed ${removedCount} internal dependency entries and wrote backup file.`);
} else {
  if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath);
  console.log('No geo-*/geostar-* dependencies found.');
}
NODE

# 2) Install public dependencies.
echo "Installing public dependencies with $MANAGER from $PUBLIC_REGISTRY ..."
if [[ "$MANAGER" == "npm" ]]; then
  npm install --registry="$PUBLIC_REGISTRY"
else
  pnpm install --registry="$PUBLIC_REGISTRY"
fi

# 3) Install internal geo-*/geostar-* dependencies only when backup exists and has content.
if [[ ! -s "$TMP_FILE" ]]; then
  echo "No internal geo-*/geostar-* dependencies backup file found. Skip internal install."
  exit 0
fi

node - <<'NODE'
const fs = require('fs');
const path = require('path');

const tmpPath = path.resolve(process.cwd(), '.geo-internal-deps-backup.json');
if (!fs.existsSync(tmpPath) || fs.statSync(tmpPath).size === 0) {
  process.exit(0);
}

const backup = JSON.parse(fs.readFileSync(tmpPath, 'utf8'));
const sections = ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies'];
let total = 0;
for (const section of sections) {
  const deps = backup?.removed?.[section] || {};
  total += Object.keys(deps).length;
}

if (total === 0) {
  process.exit(0);
}
NODE

read_specs() {
  local section="$1"
  node -e '
const fs = require("fs");
const section = process.argv[1];
const backup = JSON.parse(fs.readFileSync(".geo-internal-deps-backup.json", "utf8"));
const deps = (backup && backup.removed && backup.removed[section]) || {};
for (const [name, version] of Object.entries(deps)) {
  process.stdout.write(`${name}@${version}\n`);
}
' "$section"
}

install_one_internal() {
  local spec="$1"
  local flag="$2"

  echo "Installing internal package: $spec"
  if [[ "$MANAGER" == "npm" ]]; then
    if [[ -n "$flag" ]]; then
      npm install "$flag" "$spec" --registry="$INTERNAL_REGISTRY"
    else
      npm install "$spec" --registry="$INTERNAL_REGISTRY"
    fi
  else
    if [[ -n "$flag" ]]; then
      pnpm add "$flag" "$spec" --registry="$INTERNAL_REGISTRY"
    else
      pnpm add "$spec" --registry="$INTERNAL_REGISTRY"
    fi
  fi
}

install_section_specs() {
  local section="$1"
  local flag="$2"
  local specs=()
  mapfile -t specs < <(read_specs "$section")

  if [[ ${#specs[@]} -eq 0 ]]; then
    return 0
  fi

  for spec in "${specs[@]}"; do
    if ! install_one_internal "$spec" "$flag"; then
      echo "内部依赖安装失败，请检查。"
      exit 1
    fi
  done
}

install_section_specs dependencies ""
install_section_specs devDependencies "-D"
install_section_specs optionalDependencies "-O"
install_section_specs peerDependencies "--save-peer"

echo "Internal geo-*/geostar-* dependency installation completed."
