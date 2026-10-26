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

opencode_environment="$HOME/.config/workstation/opencode.env"
mkdir -p "$(dirname "$opencode_environment")"
umask 077
printf 'export OPENROUTER_API_KEY=%q\n' "$OPENROUTER_API_KEY" > "$opencode_environment"
if ! grep -Fq '.config/workstation/opencode.env' "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<'BASHRC'

# Workstation OpenCode environment
if [ -f "$HOME/.config/workstation/opencode.env" ]; then
  . "$HOME/.config/workstation/opencode.env"
fi
BASHRC
fi

opencode service set env OPENROUTER_API_KEY "$OPENROUTER_API_KEY"
opencode --version

(
  cd "$checkout"
  direnv allow
)
