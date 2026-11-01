# Coding Standards

Coding standards for this repository.

## Priorities

Apply these in order:

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
  `CODE_SERVER_TAG` over `TAG` and `GCLOUD_ARGS` over `GC`.
- Name a variable for its meaning and keep values in named constants:
  prefer a `load_average` variable read using a `LOAD_AVERAGE_MINUTES`
  constant over `one_minute_load`, which encodes a value in its name.
- Name a retry loop's counter `attempt` rather than `i` or `_`.
- Standard and domain terminology is allowed where it is the convention:
  positional parameters (`$1`, `$2`), awk field references, and established
  terms such as `ssh`, `ip`, `name`, `zone`, and `project`.
- Express intent through names and small, focused functions rather than prose
  comments.

## Comments

- Do not add comments to source files where a well-named entity can carry the
  meaning instead. Extract complexity into named functions and constants.
- Minimize comments overall; Bash has no types to convey some constraints, so
  a short comment is acceptable when no name can express the reason.
- Reserve comments for what a name cannot say: non-obvious constraints,
  invariants, and deliberate choices. Do not describe what the code does.
- If a reader needs a comment to understand a block, extract the block into a
  well-named function instead.

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

## Infrastructure

- Manage all Google Cloud infrastructure as code in this repository. Identity,
  IAM, buckets, roles, and firewall rules are declared in `infra/` and are
  provisioned only by `infra/workstation/provision` — through the Infra
  workflow, or the documented one-time bootstrap when a project is new.
- Do not provision, modify, or delete project-level resources with ad-hoc
  cloud CLI commands, in personal shells, or from instance lifecycle scripts.
  The workstation CLI creates and destroys instances only.
- Change infrastructure through a pull request, like any other code. When
  infrastructure is missing or drifts, fix the repository and let the Infra
  workflow converge the project; never point-fix a live project by hand.

## Change discipline

The intent: every change lands through review, stays within its own scope, and
removes what it supersedes, so the default branch keeps a coherent history and
no speculative or dead machinery accumulates.

- Make repository changes in a linked git worktree on a branch and submit them
  through a pull request. Do not commit directly to the default branch.
- Make the smallest complete change that satisfies the requirement.
- Treat exploratory ideas and future possibilities as non-requirements until
  they are explicitly accepted.
- Do not add speculative compatibility, configuration, abstractions, or
  extension points.
- When feedback changes ownership, lifetime, output hierarchy, or failure
  semantics, restate the complete boundary and remove invalid abstractions
  instead of layering another type onto them.
- When a simpler accepted direction gives up an earlier property, remove the
  superseded code, tests, and documentation rather than preserving it
  implicitly.
- Preserve existing behavior unless the task explicitly changes it.
- Add or update tests for observable behavior and validation rules.
- Deliver every change through a pull request: commit, push, and create one, or
  update the current open pull request. Check that an existing pull request is
  not already merged before updating it.

## Required checks

Run these before opening a pull request:

```sh
# every Bash script
bash -n scripts/workstation infra/workstation/*
# every Bash script
shellcheck scripts/workstation
shellcheck infra/workstation/*
# every workflow
actionlint .github/workflows/*.yml
```