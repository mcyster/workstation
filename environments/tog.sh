#!/usr/bin/env bash
# workstation-secret: OPENROUTER_API_KEY

set -euo pipefail

checkout="$HOME/tog/main"
mkdir -p "$(dirname "$checkout")"

if [[ -d "$checkout/.git" ]]; then
  git -C "$checkout" pull --ff-only
elif [[ -e "$checkout" ]]; then
  echo "$checkout exists but is not a Git repository" >&2
  exit 1
else
  git clone https://github.com/mcyster/tog.git "$checkout"
fi

if [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
  curl -fsSL https://opencode.ai/v2/install | bash
fi
export PATH="$HOME/.opencode/bin:$PATH"
opencode service set env OPENROUTER_API_KEY "$OPENROUTER_API_KEY"
opencode --version

(
  cd "$checkout"
  direnv allow
)
