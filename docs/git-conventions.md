---
description: Git workflow and commit conventions
alwaysApply: true
---
# Git conventions

## Project model

`main` is the product branch for this independent downstream. Changes do not need to remain easy to merge back into `babanin/mac-djview`.

That freedom does not justify noisy history: keep work easy to review, bisect, and revert.

## Commit messages

- Use imperative mood.
- Keep the first line concise (preferably under 72 characters).
- Explain *why* in the body when the reason is not obvious from the diff.
- Use prefixes such as `fix:`, `feat:`, `security:`, `ui:`, `ci:`, `docs:` when they improve scanability.

## Branching and pull requests

- `main` is the primary branch.
- Use short-lived topic branches for code and non-trivial documentation work.
- Keep decoder/security, UI, system integration, and performance work in separate PRs when practical.
- Prefer one meaningful commit per small PR.
- Prefer rebase merge for these focused PRs to keep `main` linear.
- Do not rewrite published release tags.

## What to commit

- Source code and tests.
- Build/release scripts and workflow definitions.
- Documentation.
- Small, intentional test fixtures only when their provenance is clear and their size is justified.
- Icon Composer source and other editable product assets.

## What not to add in new work

- `.build/` and other generated build output.
- Generated `.app` bundles as source-of-truth artifacts; use CI/release artifacts instead.
- Large binary DjVu fixtures without a specific regression need and provenance review.
- Temporary debug images/logs.
- `.DS_Store` and other editor/OS metadata.

The repository still contains some inherited/legacy binary artifacts. Their presence is not a precedent for new work; cleanup should be handled in a dedicated repository-hygiene change so history and test provenance are reviewed deliberately.

## Releases

- Release builds must come from a tag/explicit ref, not an uncommitted local tree.
- Keep architecture/deployment-target checks in CI.
- Preserve sandbox entitlements and checksum artifacts.
- Until Developer ID signing/notarization exists, document the ad-hoc-signing/Gatekeeper limitation clearly.
