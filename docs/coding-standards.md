# Coding Standards

Coding standards for this repository, adapted from the
[`mcyster/tog`](https://github.com/mcyster/tog) repository's
[`AGENTS.md`](https://github.com/mcyster/tog/blob/main/AGENTS.md),
[`docs/development-standards.md`](https://github.com/mcyster/tog/blob/main/docs/development-standards.md),
and
[`docs/principles.md`](https://github.com/mcyster/tog/blob/main/docs/principles.md).
tog states the standards for Rust; this document applies the same priorities to
this repository's Bash scripts and GitHub Actions workflows.

## Priorities

Apply these in order (from tog's principles):

1. **Readability and understandability.** The code should carry most of the
   explanation of its structure and behavior.
2. **Correctness** through validation and clear failure at boundaries.
3. **Simplicity.** The result should be easy to understand: the code maps
   clearly to the problem it solves, with no machinery beyond what the problem
   requires. Simplicity is a property of the design that remains, not of how it
   was reached — it can require a large change, and a small diff is not evidence
   of a simple design.

## Naming

- Use descriptive, **full-word names** for variables, functions, and files.
- Do not use **single-letter names** for project-defined variables, parameters,
  or loop counters.
- Avoid abbreviations in project-defined names. For example, prefer
  `CODE_SERVER_TAG` over `TAG`, `GCLOUD_ARGS` over `GC`, and
  `one_minute_load` over `load1`.
- Name a retry loop's counter `attempt` rather than `i` or `_`.
- Standard and domain terminology is allowed where it is the convention:
  positional parameters (`$1`, `$2`), awk field references, and established
  terms such as `ssh`, `ip`, `name`, `zone`, and `project`.
- Express intent through names and small, focused functions rather than prose
  comments.

## Bash scripts

- Start executable scripts with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Validate external input at the boundary and fail fast with a clear message.
  `scripts/workstation` provides a `die` helper for this.
- Keep scripts idempotent when they run repeatedly: provisioning, installers,
  and environment scripts may be re-applied safely.
- Prefer shellcheck-clean code using full-word names.

## GitHub Actions workflows

- Use full-word names inside `run:` scripts; no single-letter variables.
- Validate workflows with `actionlint`.

## Structure and documentation

- Keep durable documentation in `docs/`.
- Keep the provisioning script self-contained: `infra/workstation/setup` runs
  as a GCE startup script with no repository access.

## Change discipline

- Make changes on a branch and deliver them through a pull request; do not
  commit directly to the default branch.
- Make the smallest complete change that satisfies the requirement.
- Preserve existing behavior unless the task explicitly changes it.
- When a change makes an earlier property moot, remove the superseded code and
  documentation rather than preserving it.

## Required checks

Run these before opening a pull request:

```sh
# every Bash script
bash -n scripts/workstation infra/workstation/* environments/*.sh

# every Bash script
shellcheck scripts/workstation
shellcheck infra/workstation/*
shellcheck environments/*.sh

# every workflow
actionlint .github/workflows/*.yml
```