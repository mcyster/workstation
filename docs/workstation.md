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

## Apps

Workstations are described by a declarative app registry in `apps.json`. Each app name maps to optional capabilities:

- **`env`** — a `.env` file: the repository secret `WORKSTATION_ENV_<APP>` (value = file content) is written to `~/.env.<app>` (0600) and sourced before setup runs.
- **`service`** — a supervised browser app: systemd unit, port, and Caddy site ([Browser access](#browser-access)) generated from those fields.
- **`environment` + `setup`** — a configurable environment: `app/<name>/setup.sh` runs at `configure`.

| App | env | service | setup |
| --- | --- | --- | --- |
| `code` | ✓ | `:8443` | `app/code/setup.sh` |
| `opencode` | ✓ | `:8444` | `app/opencode/setup.sh` |
| `tog` | ✓ | — | `app/tog/setup.sh` (environment) |

- Service apps install at `create` (web terminal and opencode by default) and rotate together behind one shared browser-apps password.
- `configure NAME...` runs the environment app's setup script (e.g. `app/tog/setup.sh`) as `developer`, with `WORKSTATION_ENVIRONMENT`/`WORKSTATION_NAME` set and the env files already materialized and sourced. Scripts should be idempotent.
- Select environments in the workflow's **environment** field or with `--environment` on the CLI (comma-separated, applied in order, duplicates ignored). GitHub Actions runs one configure job per environment in a matrix.

### Pushing env file values

Keep the raw values (and any repository holding them, such as a private `secrets` repo) only on your machine, never on a workstation; `env-sync` there produces `~/.env.<app>`. Upload them to GitHub repository secrets with:

```sh
scripts/workstation-secrets-push                # all apps, repo-level
scripts/workstation-secrets-push opencode tog  # just those apps
scripts/workstation-secrets-push --dir ~/secrets   # read ~/secrets/.env.<app>
```

The tool reads `~/.env.<APP>` (or `--dir`/`.env.<APP>`), uploads only files whose fingerprint changed (so repeated runs are no-ops), never prints values, and requires confirmation. It needs the GitHub CLI (`gh`), included in the development shell.

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

Browse to either URL and accept the self-signed certificate warning. Both apps run plain on localhost; Caddy terminates TLS and authenticates the browser, so the workstation stores only a bcrypt hash of the password. The plaintext password is kept in the Google Cloud Secret Manager secret `workstation-NAME-web-terminal-password`. The workflow identity can create this secret and append versions, but cannot read its values. Use Secret Manager in the Google Cloud console to see the active password.

opencode keeps its own sign-in, whose username/password prompt has a known upstream auth loop ([#19920](https://github.com/anomalyco/opencode/issues/19920)). Sign the browser in with a **one-time pairing link** instead — from your laptop:

```sh
scripts/workstation opencode-link main --project PROJECT --zone ZONE
```

or from inside the workstation (web terminal at `:8443`), as `developer`:

```sh
~/.opencode/bin/opencode pair --url https://EXTERNAL_IP:8444
```

Open the printed link within 5 minutes (single use); Caddy asks for `workstation` + the shared password once more, then opencode signs the browser in with a 30-day session cookie. Rotating the browser-apps password signs opencode sessions out.

`start` rotates the password after a stopped VM resumes; `web-terminal` and `opencode` rotate it on demand. `create` without those flags keeps both ports closed. Browser access is public on ports 8443 and 8444 when enabled; protect the Google Cloud project and Secret Manager permissions and avoid leaving expensive API credentials in unattended sessions. Consider narrowing the firewall source range when practical.

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
