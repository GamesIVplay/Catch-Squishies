#!/bin/sh

set -e

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

pesde x 1axen/blink -- .config/blink/init.blink --yes
