#!/usr/bin/env bash
# workstation-secret: OPENROUTER_API_KEY

set -euo pipefail

checkout="$HOME/src/tog"
mkdir -p "$(dirname "$checkout")"

if [[ -d "$checkout/.git" ]]; then
  git -C "$checkout" pull --ff-only
elif [[ -e "$checkout" ]]; then
  echo "$checkout exists but is not a Git repository" >&2
  exit 1
else
  git clone https://github.com/mcyster/tog.git "$checkout"
fi

(
  cd "$checkout"
  direnv allow
  direnv exec . opencode service set env OPENROUTER_API_KEY "$OPENROUTER_API_KEY"
  direnv exec . opencode --version
)
