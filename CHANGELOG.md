# Changelog

## [Unreleased]

### Added

- Initial Codex-only split from VibesDeGoGo!.
- Codex skill, hook scripts, project-local hook config, and smoke tests.
- Global `UserPromptSubmit` hook that makes VDGG the default workflow for
  coding work in any git repository.

### Changed

- VDGG state and tool hooks now resolve the git root before reading or writing
  `.codex/.vdgg-*`, so sessions started from subdirectories apply to the whole
  repository.
