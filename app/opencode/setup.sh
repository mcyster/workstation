#!/usr/bin/env bash
# Install opencode for the developer user (the managed serve daemon needs it),
# plus an opencode-link helper that prints a one-time pairing link for the
# browser using the workstation's public IP.
# Runs as root on the workstation.
set -euo pipefail

if [[ ! -x /home/developer/.opencode/bin/opencode ]]; then
  sudo -u developer bash -lc 'curl -fsSL https://opencode.ai/v2/install | bash' >/dev/null
fi

install -d -o developer -g developer /home/developer/scripts
cat > /home/developer/scripts/opencode-link <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
public_ip="$(curl -s --max-time 5 -H 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)"
[[ -n "$public_ip" ]] || public_ip="$(curl -s --max-time 5 https://api.ipify.org)"
exec /home/developer/.opencode/bin/opencode pair --url "https://$public_ip:8444"
SCRIPT
chown developer:developer /home/developer/scripts/opencode-link
chmod 755 /home/developer/scripts/opencode-link

if ! grep -q 'HOME/scripts' /home/developer/.bashrc; then
  # shellcheck disable=SC2016
  printf '\n# Workstation helper scripts\nexport PATH="$HOME/scripts:$PATH"\n' >> /home/developer/.bashrc
fi