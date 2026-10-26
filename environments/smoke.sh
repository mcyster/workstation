#!/usr/bin/env bash
# workstation-secret: WORKSTATION_SMOKE_SECRET

set -euo pipefail

: "${WORKSTATION_SMOKE_SECRET:?missing WORKSTATION_SMOKE_SECRET}"
echo "Configured $WORKSTATION_ENVIRONMENT on $WORKSTATION_NAME"
