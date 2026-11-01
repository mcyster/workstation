# Workstation

## What

Workstation provides a persistent, remotely hosted development environment accessible through a web browser or SSH. It is independent of any repository or agent framework. Google Compute Engine is the current hosting implementation.

## Usage

Manage a workstation from **Actions → Workstation → Run workflow** using only a browser — create, start, stop, enable browser access, configure environments, rotate the shared password, or destroy. The run summary links to the workstation's browser interface.

All the detail — the app registry, environments, browser apps, and the local `workstation` CLI — lives in [docs/workstation.md](docs/workstation.md).

## Setup

The current hosting implementation requires a Google Cloud project. You can reuse an existing project or create one with a unique Project ID such as `mcyster-dev`. Follow the [Google Cloud project setup](docs/workstation.md#google-cloud-project-setup) to bootstrap a workstation entirely from your browser.

## Development

Repository conventions and required checks are in
[docs/coding-standards.md](docs/coding-standards.md). Detailed operations
documentation lives in [docs/](docs/).
