# Workstation

## What

Workstation provides a persistent, remotely hosted development environment accessible through a web browser or SSH. It is independent of any repository or agent framework. Google Compute Engine is the current hosting implementation.

## Usage

Manage a workstation from **Actions → Workstation → Run workflow**. GitHub Actions lets you bootstrap and manage the environment using only a browser, without installing local tools. Create, start, stop, set up browser access, issue a new password, or destroy the workstation there; the workflow summary links to its browser interface.

Or use the command line:

```sh
scripts/workstation create main --web-terminal
scripts/workstation shell main
scripts/workstation idle-shutdown main
scripts/workstation stop main
scripts/workstation start main
scripts/workstation destroy main
```

## Setup

The current hosting implementation requires a Google Cloud project. You can reuse an existing project or create one with a unique Project ID such as `mcyster-dev`. Follow the [Google Cloud project setup](docs/workstation.md#google-cloud-project-setup) to bootstrap a workstation entirely from your browser.
