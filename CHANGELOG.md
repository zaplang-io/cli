# Changelog

## Unreleased

- Add opt-in environment variable defaults for string and integer options.
  [cli#13](https://github.com/zaplang-io/cli/issues/13)

- Add terminal-aware progress bars with bounded updates and context-manager
  cleanup. [cli#12](https://github.com/zaplang-io/cli/issues/12)

- Add typed visible and hidden prompts and confirmation with retries and
  EOF-to-abort handling.
  [cli#11](https://github.com/zaplang-io/cli/issues/11)

- Add typed `Exit` and `Abort` and share their status mapping with usage
  errors across command and group dispatch.
  [cli#6](https://github.com/zaplang-io/cli/issues/6)

- Add named groups, subcommand dispatch, and automatic group and command help.
  [cli#5](https://github.com/zaplang-io/cli/issues/5)

- Add Click-style command declarations, typed options and positional
  arguments, optional handler context, and typed usage errors.
  [cli#4](https://github.com/zaplang-io/cli/issues/4)

- Specify the first-release CLI contract, document its core parser boundary and
  threat model, and link the core parser and decorator dependencies.
  [cli#3](https://github.com/zaplang-io/cli/issues/3)

- Initialize the repository scaffold: README, AGENTS.md, DECISIONS.md, CHANGELOG,
  package manifest, CI workflow, and the `src/` / `tests/` / `tools/` layout. No
  library code yet. [zaplang-io/zap#314](https://github.com/zaplang-io/zap/issues/314)
