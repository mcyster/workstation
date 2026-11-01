# Workstation

A workstation is a NixOS virtual machine on Google Compute Engine. It is a
persistent, remotely hosted development environment reachable from a browser or
through SSH, independent of any code repository or agent framework.

NixOS is the operating system on the VM and Nix flakes are the mechanism that
configures the workstation and installs software. The repository holds the
flake, the NixOS modules, and a thin Google Cloud lifecycle manager around it.

## Architecture

Responsibilities are separated into four layers.

### 1. Base NixOS workstation

`nixos/base.nix` and `nixos/gce.nix` define a minimal NixOS image for Google
Compute Engine: a `developer` user with passwordless sudo, SSH with GCE-injected
keys, Nix with flakes, Git, the GitHub CLI, direnv with nix-direnv, basic
utilities, serial-console recovery, and automatic garbage collection. The image
is generic and has no project-specific logic.

`nix build .#packages.x86_64-linux.gceImage` produces the GCE-compatible disk
image (`.raw.tar.gz`). The `gce.nix` module imports nixpkgs'
`google-compute-image` module, so the image and the running system share the
same disk layout, boot loader, and guest agent.

### 2. Workstation extensions

`nixos/extensions/*.nix` are ordinary NixOS modules that compose optional
capabilities:

- `opencode.nix` — the OpenCode web service (`opencode serve`).
- `browser-terminal.nix` — a terminal in the browser (ttyd).
- `caddy.nix` — Caddy reverse proxy with HTTPS and password authentication.
- `idle-shutdown.nix` — shut the workstation down after it stays idle.

`nixos/configuration.nix` imports the base modules and enables all extensions.
This is the complete workstation configuration exposed as
`nixosConfigurations.workstation`. Adding a capability is a normal NixOS module
import; there is no application registry, dependency mechanism, or setup
lifecycle.

### 3. Project development environments

Projects are ordinary Git repositories with their own flakes. For example:

```sh
gh repo clone mcyster/tog
cd tog
direnv allow
```

The repository's `flake.nix` and `.envrc` define its own development
dependencies. The workstation contains no tog-specific installation or build
logic and does not install project toolchains globally.

### 4. Google Cloud orchestration

`scripts/workstation`, `infra/workstation/*`, and the GitHub Actions workflow
manage the instance lifecycle and Google Cloud resources. They create and
destroy instances, start and stop them, manage disks and the base image, enable
browser access, rotate passwords, and store them in Secret Manager — through
GitHub Actions or the CLI. Cloud lifecycle operations are separate from NixOS
configuration.

## Google Cloud project setup

Complete these steps in a browser. Use a Google account that can manage billing
and IAM for the project.

### 1. Create a project

Open [Create a project](https://console.cloud.google.com/projectcreate). A
project groups the workstation's VMs, disks, images, and credentials.

Choose a project name, such as `My Development Workstations`. Choose a globally
unique Project ID, such as `mcyster-dev`. Project IDs cannot be changed after
creation. This guide calls that ID `PROJECT`. You can reuse an existing project
instead.

### 2. Enable billing

Open [Google Cloud Billing](https://console.cloud.google.com/billing). Select
the project and associate it with a billing account. Compute Engine requires
billing. Create a [budget alert](https://console.cloud.google.com/billing/budgets)
to monitor costs. Budget alerts send notifications; they do not impose a
spending limit.

### 3. Open Cloud Shell

Open [Google Cloud Shell](https://console.cloud.google.com/?cloudshell=true).
Cloud Shell is a browser-based terminal with `gcloud` already installed.

Replace `PROJECT` with the Project ID and run:

```sh
gcloud config set project PROJECT
gcloud billing projects describe PROJECT
```

The billing check should report `billingEnabled: true`.

### 4. Bootstrap GitHub authentication

GitHub Actions uses Workload Identity Federation, so it can manage the
workstation without storing a Google Cloud service-account key.

In Cloud Shell, replace `OWNER` with the GitHub account or organization that
owns the repository, then run:

```sh
git clone https://github.com/OWNER/workstation.git
cd workstation

bash infra/workstation/provision \
  --project PROJECT \
  --repo OWNER/workstation
```

The script provisions the static Google Cloud infrastructure and is the source
of truth for it: required APIs, the service account, IAM, a storage bucket for
NixOS base images, the password-secret role, and the browser-access firewall
rule. It is idempotent. After this one-time bootstrap, all infrastructure
changes go through the repository — reviewed in pull requests and applied by the
**Infra** GitHub Actions workflow — so nothing is ever provisioned by ad-hoc
commands or hidden inside instance lifecycle scripts.

In GitHub, open **Repository → Settings → Secrets and variables → Actions**. Add
these repository settings:

**Variables**

- `WORKSTATION_GCLOUD_PROJECT`: the Project ID, such as `mcyster-dev`.
- `WORKSTATION_GCLOUD_ZONE`: optional; defaults to `us-central1-a`.

**Secrets**

- `WORKSTATION_GCLOUD_SERVICE_ACCOUNT`: the service account value printed by the
  script.
- `WORKSTATION_GCLOUD_WORKLOAD_IDENTITY_PROVIDER`: the identity provider value
  printed by the script.

The bootstrap script is idempotent, but review existing IAM configuration
before using it in an established project.

### 5. Create the workstation

Open the repository's [GitHub Actions page](https://github.com/mcyster/workstation/actions).
Select **Workstation**, choose **Run workflow**, set the action to `create`, and
run it. The default name is `main`, and browser access is enabled by default.

Creating a workstation builds the minimal base image on the runner (only when
its content changes; the image is cached in your GCE project), uploads it,
boots the instance, applies the full workstation flake, and sets up browser
access. After the workflow succeeds, open its summary. The summary shows the
browser URL and Secret Manager links for the website and recovery passwords.

## Using the workstation

Sign in to your user account once, from the browser terminal or SSH. Git
identity and GitHub authentication are personal, user-level settings and are
kept out of the Nix store:

```sh
git config --global user.name "Your Name"
git config --global user.email you@example.com
gh auth login        # use the device flow in the browser terminal
opencode auth login  # configure model providers for OpenCode
```

OpenCode and other developer tools share the user's Git and GitHub
configuration through `~/.config/gh` and `~/.gitconfig`.

Clone any repository with a Nix flake and work inside its development
environment:

```sh
gh repo clone mcyster/tog
cd tog
direnv allow
```

Project-provided CLIs are available in any interactive shell on the
workstation (SSH or the browser terminal): NixOS loads the direnv hook into
interactive bash, so entering a checkout with `direnv allow` puts that
project's tools on `PATH` from then on. OpenCode's web service runs in the
`developer` session, so it sees the user's Git/GitHub configuration and provider
credentials; per-project environmental tooling is used through the terminal as
above.

## GitHub workflow

Use **Actions → Workstation → Run workflow** to run `configure`, `start`,
`stop`, `web-terminal`, `list`, `recover`, or `destroy` after setup.

- `configure` re-applies the workstation flake to a running instance with a
  normal `nixos-rebuild switch`. This is how software and service changes in
  the flake reach a workstation; no new VM image is required.
- `web-terminal` enables browser access or issues a new website password and a
  new recovery password.
- `start` and `stop` preserve the disk.
- `list` shows every managed instance with its browser URL and Secret Manager
  links.
- `destroy` deletes the VM and boot disk permanently.

The workflow summary links to Secret Manager but never prints a password.

## Local CLI

As an alternative to the browser workflow, install and authenticate the Google
Cloud CLI locally and use the included development shell (provides `gcloud`
and adds `scripts/` to `PATH`):

```sh
gcloud auth login
gcloud config set project PROJECT
gcloud config set compute/zone us-central1-a
direnv allow
```

```sh
scripts/workstation create main --web-terminal
scripts/workstation configure main
scripts/workstation list
scripts/workstation shell main
scripts/workstation config-ssh main
scripts/workstation stop main
scripts/workstation start main
scripts/workstation web-terminal main
scripts/workstation recover main
scripts/workstation destroy main
```

`create` and `recover` build the base NixOS image, so they require a Linux
machine with Nix and flakes; run them from this repository. Other commands work
from any machine with `gcloud`. Override `--project`, `--zone`,
`--machine-type`, and `--boot-disk-size` per command. `create` leaves existing
machines unchanged; `start` preserves the disk; `destroy` asks for confirmation
(the GitHub action passes `--yes`).

`list` and the GitHub Actions summary include the browser URL and Secret Manager
password links for each workstation with browser access enabled.

SSH keys are managed by gcloud; once `config-ssh` has run, standard `ssh`,
`scp`, and `rsync` work as `developer`.

## Browser access

Browser access is a Caddy HTTPS reverse proxy in front of the OpenCode web
service and the browser terminal, authenticated with HTTP basic auth.

- `https://EXTERNAL_IP` — OpenCode web interface.
- `https://EXTERNAL_IP/terminal` — terminal in the browser.

The certificate is self-signed; accept the warning in your browser. All
services bind to localhost and only Caddy is exposed on HTTPS port 443. The GCE
firewall rule `workstation-web` (opened when browser access is enabled) is the
outer gate; NixOS also keeps an internal firewall. Sign in with username
`opencode` and the current website password.

Hashes live in `/var/lib/workstation` (outside the Nix store), and plaintext
passwords live only in Google Cloud Secret Manager secrets
`workstation-NAME-web-password` and `workstation-NAME-recovery-password`. The
workflow identity can create these secrets and append versions but cannot read
them; use Secret Manager in the console to see the active password. `start`
rotates the passwords after a stopped VM resumes; `web-terminal` rotates them
on demand.

## Remote recovery

A failed `nixos-rebuild switch` keeps the previous generation bootable, so the
workstation cannot permanently brick itself:

- **Generations.** The boot menu keeps the last 8 system generations. From the
  GCE serial console, pick an earlier entry to roll back.
- **Serial console.** Instances are created with the serial console enabled and
  a login console on `ttyS0`. The `recovery` password (in
  `workstation-NAME-recovery-password`) lets `root` log in
  out-of-band from Google Cloud.
- **Rescue instance.** `scripts/workstation recover main` (or the `recover`
  action) boots a fresh instance from the known-good base image and attaches
  your original disk so you can copy files off, before losing anything.
- **Recreate.** Because the whole workstation is declared in the flake,
  destroying and creating a new one reproduces the same system from the cached
  base image.

The minimal base image is always recreatable from the flake, so there is always
a known-good image to boot from.

## Repository layout

- `flake.nix`, `flake.lock` — the workstation flake and its pinned inputs.
- `nixos/base.nix` — base workstation configuration.
- `nixos/gce.nix` — Google Compute Engine platform configuration and image.
- `nixos/configuration.nix` — the complete workstation (enables extensions).
- `nixos/extensions/` — optional workstation modules.
- `scripts/workstation` — instance lifecycle, images, SSH, password rotation.
- `infra/workstation/provision` — provisions the static Google Cloud
  infrastructure (APIs, identity, IAM, image bucket, firewall rule).
- `infra/workstation/deploy` — pushes the flake to `/etc/nixos` on the instance
  and runs `nixos-rebuild switch`; runtime credentials in `/var/lib/workstation`
  are preserved.
- `infra/workstation/web-access` — rotates website and recovery passwords.
- `.github/workflows/infra.yml` — applies or checks infrastructure on PRs and
  merges, so infrastructure changes go through code review.
- `.github/workflows/workstation.yml` — manual workstation action using Workload
  Identity Federation.

Instances are named `workstation-NAME`, carry the label
`managed-workstation=true`, and are independent of tog and any other project.

## Costs

Stopping avoids running compute charges, but the disk still costs money.
Destroy deletes the disk permanently. There are no automatic backups,
snapshots, or restores. Password recovery requires only GitHub Actions access
to run the `web-terminal` action and Secret Manager access to read the new
password.