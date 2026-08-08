#!/bin/sh

set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

cd "$PROJECT_ROOT"

echo "Checking shell scripts..."
find scripts -type f -name "*.sh" -exec sh -n {} \;

echo "Checking formatting..."
pesde x pesde/stylua -- --check src

echo "Running Selene..."
pesde x pesde/selene -- src

echo "Building project..."
pesde x pesde/rojo -- build default.project.json --output "/tmp/$(basename "$PROJECT_ROOT").rbxlx"

echo "Checks passed."
