# Workstation

A workstation is a persistent Ubuntu VM on Google Compute Engine. It is not tied to a code repository. First boot creates a `developer` user and installs Git, Nix, direnv, and nix-direnv. Clone projects, install tools, and run agents inside it as you would on a local computer.

## Google Cloud project setup

Complete these steps in a browser. Use a Google account that can manage billing and IAM for the project.

### 1. Create a project

Open [Create a project](https://console.cloud.google.com/projectcreate). A project groups the workstation's VMs, disks, credentials, and billing.

Choose a project name, such as `My Development Workstations`. Choose a globally unique Project ID, such as `mcyster-dev`. Project IDs cannot be changed after creation. This guide calls that ID `PROJECT`. You can reuse an existing project instead.

### 2. Enable billing

Open [Google Cloud Billing](https://console.cloud.google.com/billing). Select the project and associate it with a billing account. Compute Engine requires billing.

Create a [budget alert](https://console.cloud.google.com/billing/budgets) to monitor costs. Budget alerts send notifications. They do not impose a spending limit.

### 3. Open Cloud Shell

Open [Google Cloud Shell](https://console.cloud.google.com/?cloudshell=true). Cloud Shell is a browser-based terminal with `gcloud` already installed. No local software is required.

Replace `PROJECT` with the Project ID and run:

```sh
gcloud config set project PROJECT
gcloud billing projects describe PROJECT
```

The billing check should report `billingEnabled: true`.

### 4. Bootstrap GitHub authentication

GitHub Actions uses Workload Identity Federation. It can manage the workstation without storing a Google Cloud service-account key.

In Cloud Shell, replace `OWNER` with the GitHub account or organization that owns the repository, then run:

```sh
git clone https://github.com/OWNER/workstation.git
cd workstation

bash infra/workstation/github-gcloud-identity \
  --project PROJECT \
  --repo OWNER/workstation
```

The script enables the required APIs and creates the Google Cloud service account, permissions, identity provider, and a limited role for writing workstation password secrets. It prints values for `WORKSTATION_GCLOUD_SERVICE_ACCOUNT` and `WORKSTATION_GCLOUD_WORKLOAD_IDENTITY_PROVIDER`.

In GitHub, open **Repository → Settings → Secrets and variables → Actions**. Add these repository settings:

**Variables**

- `WORKSTATION_GCLOUD_PROJECT`: the Project ID, such as `mcyster-dev`.
- `WORKSTATION_GCLOUD_ZONE`: optional; defaults to `us-central1-a`.

**Secrets**

- `WORKSTATION_GCLOUD_SERVICE_ACCOUNT`: the service account value printed by the script.
- `WORKSTATION_GCLOUD_WORKLOAD_IDENTITY_PROVIDER`: the identity provider value printed by the script.

The bootstrap script is idempotent, but review existing IAM configuration before using it in an established project.

### 5. Create the workstation

Open the repository's [GitHub Actions page](https://github.com/mcyster/workstation/actions). Select **Workstation**, choose **Run workflow**, set the action to `create`, and run it. The default name is `main`, and browser access is enabled by default.

After the workflow succeeds, open its summary. The summary shows the browser URL and a password link to Google Cloud Secret Manager.

## GitHub workflow

Use **Actions → Workstation → Run workflow** to run `configure`, `start`, `stop`, `web-terminal`, `opencode`, `list`, or `destroy` after setup. `web-terminal` and `opencode` set up or repassword browser access. The summary links to Secret Manager but never prints the password. The **environment** field accepts a comma-separated list (for example `tog, devbase`); each is applied in order, and each runs against its own GitHub Environment.

## Local CLI

As an alternative to the browser workflow, install and authenticate the Google Cloud CLI locally:

```sh
gcloud auth login
gcloud config set project PROJECT
gcloud config set compute/zone us-central1-a
```

The included Nix development shell provides `gcloud` and adds `scripts/` to `PATH`. With Nix and direnv installed, run `direnv allow` to load it automatically.

```sh
scripts/workstation create main --machine-type e2-standard-2 --web-terminal
scripts/workstation configure main --environment "tog, devbase"
scripts/workstation list
scripts/workstation shell main
scripts/workstation config-ssh main
scripts/workstation stop main
scripts/workstation start main
scripts/workstation web-terminal main
scripts/workstation destroy main
```

Override `--project` and `--zone` per command, or use `gcloud` configuration. `create` leaves existing machines unchanged; `start` preserves the disk. `destroy` removes the VM and boot disk; interactive CLI runs ask for confirmation, while the GitHub action uses `--yes`.

`list` includes the browser URL and Secret Manager password link for each workstation with browser access enabled. The GitHub Actions summary renders the same links.

After upgrading an existing installation to per-workstation secrets, rerun `github-gcloud-identity`, then run `web-terminal` once for each existing workstation. This creates its named secret and makes the password link available in `list`.

SSH keys are managed by gcloud. Once `config-ssh` has run, standard `ssh`, `scp`, and `rsync` can be used.

## Project environments

An optional project environment is a version-controlled script at `environments/NAME.sh`. The name must match the GitHub Environment used by the workflow. For example, the GitHub Environment `tog` maps to `environments/tog.sh`.

Declare required GitHub Environment secrets at the top of the script:

```bash
#!/usr/bin/env bash
# workstation-secret: OPENCODE_API_KEY
# workstation-secret: TOG_GITHUB_TOKEN

set -euo pipefail

# Clone projects, install tools, authenticate clients, and run direnv here.
```

Each directive must contain one GitHub secret name, with up to 16 secrets per environment. The workflow exports only the declared values while the script runs. It does not write them to disk or include them in command arguments. The script decides whether and how a tool should persist its credentials.

Declare which browser apps the project needs at the top of the script, one per line:

```bash
# workstation-app: web-terminal
# workstation-app: opencode
```

Applying the environment enables each declared browser app behind Caddy ([Browser access](#browser-access)) using the workstation's shared browser-apps password. `tog` declares `opencode`, so a tog-configured workstation gets the OpenCode web UI without extra flags.

The script runs as `developer` with `HOME=/home/developer`. It also receives `WORKSTATION_NAME` and `WORKSTATION_ENVIRONMENT`. Make the script idempotent so it can be applied repeatedly.

Create a GitHub Environment with the same name and add the declared secrets to it. Then select that environment when running `create` or `configure` in GitHub Actions. `create` provisions the workstation before applying the environment. `configure` reapplies it to an existing running workstation.

Pass multiple environments as a comma-separated list, either in the workflow's **environment** field or to `--environment` on the CLI. Environments are applied in the order given and each environment's script runs with `WORKSTATION_ENVIRONMENT` set to its own name. GitHub Actions runs one configure job per environment (a matrix), with each job bound to that environment's GitHub Environment so its secrets stay scoped. Duplicates are ignored.

The local CLI reads declared secrets from its current environment:

```sh
OPENCODE_API_KEY=... scripts/workstation create main --environment tog
OPENCODE_API_KEY=... scripts/workstation configure main --environment tog
```

Environment scripts are trusted code with access to the secrets they declare. Protect the corresponding GitHub Environment and review script changes before running them.

## Browser access

Browser apps are served through **Caddy**, which terminates TLS (self-signed) and requires HTTP basic auth with a single shared browser-apps password:

- **Web terminal** — code-server on `https://EXTERNAL_IP:8443`
- **OpenCode** — the opencode web UI on `https://EXTERNAL_IP:8444`

Enable them with `web-terminal` or `opencode`, or when creating:

```sh
scripts/workstation create main --web-terminal
scripts/workstation create main --opencode
scripts/workstation web-terminal main
scripts/workstation opencode main
```

Browse to either URL and accept the self-signed certificate warning. Both apps run plain on localhost; Caddy terminates TLS and authenticates the browser with a bcrypt hash, so Caddy's password gate stores only a hash. The plaintext password is kept in the Google Cloud Secret Manager secret `workstation-NAME-web-terminal-password`. The workflow identity can create this secret and append versions, but cannot read its values. Use Secret Manager in the Google Cloud console to see the active password.

opencode keeps its own sign-in. Its in-page username/password prompt is affected by a known upstream auth loop ([#19920](https://github.com/anomalyco/opencode/issues/19920)), so sign in with a one-time pairing link instead — it sets a 30-day session cookie and skips the broken prompt entirely:

```sh
scripts/workstation opencode-link main
# open the printed link within 5 minutes; Caddy still asks for workstation + the shared password first
```

`start` rotates the password after a stopped VM resumes; `web-terminal` and `opencode` rotate it on demand. `create` without those flags keeps both ports closed. Browser access is public on ports 8443 and 8444 when enabled; protect the Google Cloud project and Secret Manager permissions and avoid leaving expensive API credentials in unattended sessions. Consider narrowing the firewall source range when practical.

### Public certificate via a domain (optional)

Pass `--domain HOSTNAME` to any browser-access command to use a real, public Let's Encrypt certificate instead of the self-signed one:

```sh
scripts/workstation web-terminal main --domain main.workstation.example.com
scripts/workstation opencode main --domain main.workstation.example.com
```

Caddy requests the certificate automatically. To make that work the CLI:

- creates or updates an **A record** for `HOSTNAME` pointing at the workstation's external IP with a **60-second TTL**, and
- opens firewall ports **80** (ACME challenge) and **443** (HTTPS).

The Google Cloud DNS zone for the hostname is auto-detected in the project; pass `--dns-zone ZONE` to name it explicitly, or `--no-dns` to manage DNS yourself (and create the A record manually). Port-8443/8444 links keep working alongside the public URL. The workstation still stores only the bcrypt hash; the plaintext password stays in Secret Manager, and the certificate is issued by Let's Encrypt to a domain you own.

If your DNS lives elsewhere — no Google Cloud DNS zone in the project, as with ZoneEdit — the CLI can update **ZoneEdit Dynamic DNS** with a per-domain token:

```sh
ZONEEDIT_DYN_USER=your-user \
ZONEEDIT_DYN_TOKEN=your-dyn-token \
scripts/workstation web-terminal main --domain main.workstation.cyster.com
```

The CLI calls `https://api.cp.zoneedit.com/dyn/generic.php` with the workstation's external IP. In ZoneEdit first: add a **Dynamic record** for host `main.workstation` (short TTL), then enable its **DYN Authentication Token** (the token is used as the password, your account password is never sent). The hostname needs to exist as a Dynamic record before updates take effect.

Alternatively give the workstation a **static IP** and set the A record once — no API and no token needed, and the record stays valid across `stop`/`start` because the address no longer changes:

```sh
scripts/workstation static-ip main                       # reserve and attach a fixed IP
scripts/workstation web-terminal main --domain main.workstation.example.com --no-dns
```

`--no-dns` skips the CLI's record updates; you create the A record once in the provider's console. In every case Caddy still obtains and renews the Let's Encrypt certificate through port 80.

## Provisioning and ownership

- `scripts/workstation`: instance lifecycle, firewall, SSH, and password rotation.
- `infra/workstation/setup`: idempotent first-boot host provisioning, attached as a GCE startup script.
- `infra/workstation/browser-apps`: Caddy TLS terminator, per-app systemd services, and bcrypt password hashing.
- `infra/workstation/idle-shutdown`: auto-shutdown watchdog installed on every managed workstation.
- `infra/workstation/github-gcloud-identity`: workload identity, service account, and Secret Manager setup.
- `.github/workflows/workstation.yml`: manual action, using Workload Identity Federation.

VMs have names `workstation-NAME` and the label `managed-workstation=true`. The CLI refuses to destroy an instance without its ownership label. Workstations are independent of tog and do not clone any repository automatically.

## Idle shutdown

Workstations power themselves off after being continuously idle, so a forgotten workstation stops accruing compute charges. The watchdog is installed on every workstation whenever setup or a management command runs, and also explicitly via:

```sh
scripts/workstation idle-shutdown main
```

A workstation counts as **in use** while any of these hold:

- an active SSH connection (port 22),
- an active web terminal or OpenCode browser connection (ports 8443 and 8444),
- sustained CPU load at or above the vCPU count (long builds and agent jobs).

When none of these hold for `WORKSTATION_IDLE_HOURS` (default 4) it runs a graceful `systemctl poweroff`, which stops the VM the same way `stop` does: the disk is preserved and `start` resumes it. Checking starts only 15 minutes after boot (`WORKSTATION_BOOT_GRACE_MIN`) so provisioning and updates finish first.

To tune the idle window or boot grace on a running workstation, edit `/etc/default/workstation-idle-shutdown` and restart the timer:

```sh
sudo systemctl disable --now workstation-idle-shutdown.timer
sudo systemctl enable --now workstation-idle-shutdown.timer
```

To disable auto-shutdown, `sudo systemctl disable --now workstation-idle-shutdown.timer`. The next management command that runs setup (`create`, `configure`, `web-terminal`, or `start` on a web-terminal workstation) reinstalls it.

## Costs and recovery

Stopping avoids running compute charges, but the disk still costs money. Destroy deletes the disk permanently. There are no automatic backups, snapshots, or restores. Password recovery requires only GitHub Actions access to run the `web-terminal` action and Google Cloud Secret Manager access to read the new password.
