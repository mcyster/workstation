#!/usr/bin/env bash
# Install the code-server web-terminal app and its localhost config.
# Runs as root on the workstation.
set -euo pipefail

ensure_shebang() {
  printf '#!/bin/sh\nexec /usr/lib/code-server/bin/code-server "$@"\n' > /usr/bin/code-server
  chmod 755 /usr/bin/code-server
}

if [[ ! -x /usr/lib/code-server/bin/code-server ]]; then
  curl -fsSL https://code-server.dev/install.sh | sh >/dev/null
fi
ensure_shebang

conftig=/home/developer/.config/code-server/config.yaml
install -d -m 0700 -o developer -g developer "$(dirname "$conftig")"
printf 'bind-addr: 127.0.0.1:8080\nauth: none\ncert: false\ndisable-telemetry: true\n' > "$conftig"
chown developer:developer "$conftig"
chmod 600 "$conftig"