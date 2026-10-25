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

The script enables the required APIs and creates the Google Cloud service account, permissions, identity provider, and Secret Manager secret. It prints values for `WORKSTATION_GCLOUD_SERVICE_ACCOUNT` and `WORKSTATION_GCLOUD_WORKLOAD_IDENTITY_PROVIDER`.

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

Use **Actions → Workstation → Run workflow** to run `start`, `stop`, `web-terminal`, `list`, or `destroy` after setup. `web-terminal` sets up browser access or issues a new password. The summary links to Secret Manager but never prints the password.

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
scripts/workstation list
scripts/workstation shell main
scripts/workstation config-ssh main
scripts/workstation stop main
scripts/workstation start main
scripts/workstation web-terminal main
scripts/workstation destroy main
```

Override `--project` and `--zone` per command, or use `gcloud` configuration. `create` leaves existing machines unchanged; `start` preserves the disk. `destroy` removes the VM and boot disk; interactive CLI runs ask for confirmation, while the GitHub action uses `--yes`.

SSH keys are managed by gcloud. Once `config-ssh` has run, standard `ssh`, `scp`, and `rsync` can be used.

## Browser access

`create --web-terminal` provisions code-server (browser-based editor and shell) with a random password. Browse to `https://EXTERNAL_IP:8443` and accept the self-signed certificate warning. The workstation holds only an Argon2 password hash. The plaintext password is added to the Google Cloud Secret Manager secret `workstation-web-terminal-password`, which the workflow identity can append to, but cannot read. Use Secret Manager in the Google Cloud console to see the active password.

Run `web-terminal` to set up browser access or issue a new password. `start` rotates the password after a stopped VM resumes. `create` without the flag leaves port 8443 closed. Browser access is public on port 8443 when enabled; protect the Google Cloud project and Secret Manager permissions and avoid leaving expensive API credentials in unattended sessions. Consider narrowing the firewall source range when practical.

## Provisioning and ownership

- `scripts/workstation`: instance lifecycle, firewall, SSH, and password rotation.
- `infra/workstation/setup`: idempotent first-boot host provisioning, attached as a GCE startup script.
- `infra/workstation/web-terminal`: code-server service and password hash updates.
- `infra/workstation/github-gcloud-identity`: workload identity, service account, and Secret Manager setup.
- `.github/workflows/workstation.yml`: manual action, using Workload Identity Federation.

VMs have names `workstation-NAME` and the label `managed-workstation=true`. The CLI refuses to destroy an instance without its ownership label. Workstations are independent of tog and do not clone any repository automatically.

## Costs and recovery

Stopping avoids running compute charges, but the disk still costs money. Destroy deletes the disk permanently. There are no automatic backups, snapshots, or restores. Password recovery requires only GitHub Actions access to run the `web-terminal` action and Google Cloud Secret Manager access to read the new password.
