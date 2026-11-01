# Workstation

## What

Workstation provides a persistent, remotely hosted development environment
accessible through a web browser or SSH. It runs NixOS and is configured
declaratively with Nix flakes. Google Compute Engine is the current hosting
implementation. It is independent of any repository or agent framework.

The repository is a NixOS flake plus a small Google Cloud lifecycle manager:

- `nixosConfigurations.workstation` — the complete, declarative workstation.
- `.#packages.<system>.gceImage` — the minimal GCE-compatible base image.
- `nixos/extensions/` — optional capabilities as ordinary NixOS modules
  (OpenCode web service, browser terminal, Caddy/HTTPS, idle shutdown).
- `scripts/workstation` and `.github/workflows/workstation.yml` — instance
  lifecycle, image management, browser access, and password secrets.

## Usage

Manage a workstation from **Actions → Workstation → Run workflow**. GitHub
Actions lets you bootstrap and manage the environment using only a browser,
without installing local tools: create, start, stop, configure, set up browser
access, issue a new password, or destroy the workstation there. The workflow
summary links to its browser interface and to the password secrets.

Or use the command line from a machine with `gcloud` (and, for `create`, a
Linux machine with Nix):

```sh
scripts/workstation create main --web-terminal
scripts/workstation shell main
scripts/workstation stop main
scripts/workstation start main
scripts/workstation configure main
scripts/workstation destroy main
```

## Setup

The current hosting implementation requires a Google Cloud project. You can
reuse an existing project or create one with a unique Project ID such as
`mcyster-dev`. Follow the [Google Cloud project setup](docs/workstation.md#google-cloud-project-setup)
to bootstrap a workstation entirely from your browser.

Projects with a Nix flake define their own development environments. After
signing into your user account on the workstation once:

```sh
gh repo clone mcyster/tog
cd tog
direnv allow
```

See [docs/workstation.md](docs/workstation.md) for the architecture, browser
access, and remote recovery details.