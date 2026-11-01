#!/usr/bin/env bash
# Install opencode for the developer user (the managed serve daemon needs it).
# Runs as root on the workstation.
set -euo pipefail

if [[ ! -x /home/developer/.opencode/bin/opencode ]]; then
  sudo -u developer bash -lc 'curl -fsSL https://opencode.ai/v2/install | bash' >/dev/null
fi