# Workstation

## What

Workstation provides a persistent, remotely hosted development environment accessible through a web browser or SSH. It is independent of any repository or agent framework. Google Compute Engine is the current hosting implementation.

## Usage

Manage a workstation from **Actions → Workstation → Run workflow**. GitHub Actions lets you bootstrap and manage the environment using only a browser, without installing local tools. Create, start, stop, or destroy the workstation there; the workflow summary links to its browser interface.

Or use the command line:

```sh
scripts/workstation create main --web-terminal
scripts/workstation shell main
scripts/workstation stop main
scripts/workstation start main
scripts/workstation destroy main
```

## Setup

Follow the [setup and operations guide](docs/workstation.md) to configure the current Google Compute Engine implementation and GitHub Actions workflow.
