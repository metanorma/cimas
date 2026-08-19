# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What cimas is

A CLI gem that fans out CI-configuration synchronization ("waves") across a fleet of GitHub repos: clone all repos listed in a `cimas.yml`, render template files into each repo's working copy, commit drift to a per-wave branch, push, open PRs, then clean up branches/files after waves land or die. Metanorma-org specific; the live fleet configs live in `metanorma/metanorma-build-scripts/cimas-config/`.

Development happens on `main`; all changes land via PRs, one clean (squashed) commit each, rebase-merged.

## Commands

```sh
bundle install            # Gemfile is gemspec-driven; Gemfile.lock is untracked
bundle exec rspec         # full suite (rake default == spec)
bundle exec rspec spec/cimas/repository_spec.rb                # one file
bundle exec rspec spec/cimas/cli/command_spec.rb -e "refuses push"   # one example
```

- Rubocop: **not in the bundle** (not a gemspec dev-dependency) — run the globally installed `rubocop` directly. `.rubocop.yml` inherits a remote riboseinc config and lists plugin gems that may not be installed; it parses fine, but the run reports hundreds of pre-existing style offenses (single quotes vs the org's double-quote policy, 80-col lines) — do not treat it as a merge gate. CI (`.github/workflows/rake.yml` → `metanorma/ci` reusable workflow) runs specs only.
- `bin/console` works (`bundle exec ruby bin/console`).
- GitHub-touching code paths need `GITHUB_TOKEN` in the environment; specs do not.

## Architecture

Everything routes through two files:

- **`exe/cimas`** — entry point only: `require_relative '../lib/cimas'`, `Cimas::Cli::Runner.start(ARGV)`, and a two-tier rescue (`Cimas::Cli::Error`/`Thor::Error` → one clean line, exit 1; anything else → backtrace). All parsing/help lives in `Cimas::Cli::Runner` (Thor).
- **`lib/cimas/cli/runner.rb`** — `Runner < Thor` is the CLI surface: one definition per flag (`SHARED_OPTIONS` + `STRING_OPTION_KEYS` data; per-command `method_option`), `cimas help [COMMAND]` is the help interface (no `--help` remap), no `default_task` (bare `cimas` prints help; a leading global option would otherwise dispatch the default with the subcommand as an argument), `exit_on_failure?` true (Thor 1.5 exits 0 otherwise). Every task is one line: `run_command("name")` → `Command.new(command_options).execute(name)`. Adding a subcommand = desc + options + one-line action; adding a flag = one entry in the tables.
- **`lib/cimas/cli/command.rb`** — `Command` is the orchestrator holding the domain: config loading, every subcommand's behavior, ERB rendering, the patch engine. GitHub access goes through the `Cimas::GitHub` seam. Config precedence: `DEFAULT_CONFIG` < cimas.yml `settings:` < Runner-translated options. User-facing errors raise `Cimas::Cli::Error` (lib/cimas/cli/error.rb).

Domain models and seams, each loaded via autoload with `__dir__`-absolute paths (see lib/cimas.rb / lib/cimas/cli.rb): `Cimas::Repository` (`repositories:`), `Cimas::Patch` (`patches:` — compiled regex, `matches?`/`apply`), `Cimas::OrphanFiles` (pure orphan-detection logic), `Cimas::WorkingCopy` (the git seam — every git-gem call, rescue, and porcelain parse lives behind ~10 domain verbs like `drift?`, `reset_clean`, `provision via reset_onto/switch_branch`, `push` returning `:pushed/:behind_remote/[:rejected, e]`; subcommands must not call the git gem directly), `Cimas::GitHub` (Octokit boundary: client, remote→slug, visibility fallback), `Cimas::ReleasePreflight` (extracted check-runner). `Cimas::GENERATED_HEADER` / `GENERATED_HEADER_MARKER` are the SSOT for the generated-file header. `repo_by_name` returns a real `nil` for unknown names.

### Dispatch-time scope guard (the key safety mechanism)

`Command.execute(command_name)` is the single dispatch entrypoint (the Thor Runner calls it). One `COMMANDS` registry entry per subcommand drives everything: remote-mutating classification (`remote_mutating` / `remote_mutating_if`) applies the scope guard **and** the `Scope for <command>: N repo(s): ...` announcement from the same data; `requires` / `requires_if` fail fast on missing flags (`push` without `-b`/`-m`, `for-each` without `-c`, `release-preflight` without `--repo` exit 1 before any repo iteration). Remote-mutating commands refuse a missing, empty, or zero-resolving `-g`; local-only commands (`sync`, `pull`, `diff`) still default to every repo. **Adding a subcommand = adding one registry entry — nothing else.** Calling a subcommand method directly bypasses guard/validation by design (it protects CLI operators, not library callers).

### The wave lifecycle (order matters)

`setup` → `pull` → `sync` → `diff` → `push` → `open-prs` → (`cleanup-merged-prs` | `cleanup-closed-prs` | `cleanup-orphan-files`), plus `for-each` (arbitrary shell per repo) and `release-preflight` (single repo).

- **`sync`** copies each `files:` mapping from the config-master directory (`-d`) into the repo working area under `repos_path` (`-r`). `.erb` sources render with an `OpenStruct` binding: legacy per-repo `template: binding:` keys become dot-notation methods; the top-level `with:` hash is exposed as `with_values[...]` (for keys that aren't valid Ruby identifiers). After copying, `apply_patches` runs regex find/replace on in-place files.
- **Ownership marker**: every synced file gets the two-line `# Auto-generated by Cimas` header from the single managed-file writer (`write_managed` under `copy_file`/`write_rendered`). `cleanup-orphan-files` uses this header (first 500 bytes) as proof cimas owns a file before deleting it; **patches deliberately do not add the header** because they edit existing files.
- **`push`** skips repos without local drift (`WorkingCopy#drift?`); `open-prs` already tolerates missing/empty remote branches, so no-op pushes are skipped rather than forced.
- **Scope**: `-g` takes a group name, a bare repo name, or `all`. See "Dispatch-time scope guard" above.
- **Per-repo iteration**: commands loop via `each_configured_repo` (skips unconfigured names) and `each_target_repo` (also skips repos whose working copy is missing, uniform `skipping <command> for it` message). Use these in new commands — do not hand-roll the skip preamble.
- **Mutation safety**: every mutating step is wrapped in `dry_run("description") { ... }`, which prints instead of executing under `--dry-run`.
- **`open-prs`** handles stale prior-wave PRs via `--supersede-stale` (label + comment, reviewer keeps close authority) and `--flatten-stale` (also auto-closes).

### Conventions

- Log lines carry severity prefixes (`[ERROR]`, `[WARNING]`, `[INFO]`); `sanity_check` is advisory — it warns and continues.
- Specs build real temp-dir working areas, real `Command` objects, real `Git.init`/local-bare-remotes (no doubles, no network); `exe_spec` boots the real executable with `RUBYOPT` cleared (installed-gem execution model). `spec/cimas/wave_lifecycle_spec.rb` is the end-to-end money path (sync → diff → push against a local bare remote); when touching git-touching code, run it first.
- `plans/` holds dated sync-wave planning notes; consult the newest file for in-flight wave context.
- `TODO*` files are local working notes — git-ignored, never commit them.
- README.adoc is the authoritative user documentation and includes a "Gotchas summary" table; update it when adding subcommand flags or behavior changes.
