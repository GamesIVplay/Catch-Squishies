#!/bin/sh

set -e

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -d "network" ]; then
	echo "Network folder missing. Run: sh scripts/generate-network.sh"
	exit 1
fi

if [ ! -d "roblox_packages" ]; then
	echo "Packages folder missing. Run: sh scripts/install-packages.sh"
	exit 1
fi

pesde x pesde/rojo -- sourcemap default.project.json -o sourcemap.json
pesde x pesde/rojo -- serve default.project.json
