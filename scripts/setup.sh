#!/bin/sh

set -e

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

cd "$PROJECT_ROOT"

echo "Installing packages..."
sh scripts/install-packages.sh

echo "Generating network..."
sh scripts/generate-network.sh

echo "Setup complete."
