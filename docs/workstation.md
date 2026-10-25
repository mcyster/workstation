# Workstation

A workstation is a persistent Ubuntu VM on Google Compute Engine. It is not tied to a code repository. First boot creates a `developer` user and installs Git, Nix, direnv, and nix-direnv. Clone projects, install tools, and run agents inside it as you would on a local computer.

## Prerequisites

- Google Cloud project with billing enabled and the Compute Engine, IAM, STS, and Secret Manager APIs.
- Google Cloud CLI (`gcloud`) for local commands and initial setup.
- Project IAM permissions to configure service accounts, workload identity, and compute resources.

The included Nix development shell provides `gcloud` and adds `scripts/` to `PATH`. With Nix and direnv installed, run `direnv allow` to load it automatically.

```sh
gcloud auth login
gcloud config set project PROJECT
gcloud config set compute/zone us-central1-a
bash infra/workstation/gcloud-identity --project PROJECT --repo mcyster/workstation
```

Enter the returned service account and identity provider as repository **Actions secrets** `WORKSTATION_GCLOUD_SERVICE_ACCOUNT` and `WORKSTATION_GCLOUD_WORKLOAD_IDENTITY_PROVIDER`. Enter `WORKSTATION_GCLOUD_PROJECT` as an **Actions variable**, with `WORKSTATION_GCLOUD_ZONE` optional (default `us-central1-a`). The bootstrap script is idempotent, but review any existing IAM configuration before using it.

## GitHub workflow

Open **Actions → Workstation → Run workflow**. Choose `create`, `start`, `stop`, `web-terminal`, `list`, or `destroy`, and optionally provide a machine name (`main` by default). `create` enables the browser editor by default. The summary provides the external URL and a Secret Manager link, but never prints the password.

## CLI

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
- `infra/workstation/setup`: idempotent first-boot host provisioning, embedded in cloud-init metadata.
- `infra/workstation/web-terminal`: code-server service and password hash updates.
- `infra/workstation/gcloud-identity`: workload identity, service account, and Secret Manager setup.
- `.github/workflows/workstation.yml`: manual action, using Workload Identity Federation.

VMs have names `workstation-NAME` and the label `managed-workstation=true`. The CLI refuses to destroy an instance without its ownership label. Workstations are independent of tog and do not clone any repository automatically.

## Costs and recovery

Stopping avoids running compute charges, but the disk still costs money. Destroy deletes the disk permanently. There are no automatic backups, snapshots, or restores. Password recovery requires only GitHub Actions access to run the `web-terminal` action and Google Cloud Secret Manager access to read the new password.
