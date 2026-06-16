# Cimas revival and release-workflow realignment

Status as of 2026-06-16. Working draft kept locally; this file is the canonical published record. Updates land as direct commits to `main` per the org's plans/ convention (no PR ceremony for plan-only commits).

## Context

This plan covers two coupled threads of work on the metanorma org's CI/release infrastructure:

1. **Cimas revival** — restoring the `metanorma/cimas` gem to a runnable state on current Ruby (3.3 / 3.4 / 4.0) so it can resume its role as the synchroniser for shared CI configuration across the metanorma stack.
2. **Release-workflow realignment** — bringing metanorma-org gems into parity with the `<org>/support` wrapper convention already used by `relaton/support`, `fontist/support`, and `lutaml/support`. Metanorma is currently the only org without an analogous adapter layer; closing that gap is the natural completion of a pattern Ronald established elsewhere.

The two threads are coupled because the cimas-sync wave is what propagates the wrapper-routing change across the ~65 metanorma-org gems that share the master release.yml template.

## Phase A — pre-batch unblocking (in flight, targets 2026-06-19)

### Cimas revival

Three cimas PRs landed today restoring the gem to runnable state across the matrix:

- [`metanorma/cimas#42`](https://github.com/metanorma/cimas/pull/42) — adds `ostruct` as an explicit runtime dependency (Ruby 4.0 removed it from default gems).
- [`metanorma/cimas#43`](https://github.com/metanorma/cimas/pull/43) — relaxes the bundler dev-dep constraint from `~> 2.0` to `>= 2.0` to admit bundler 4.x (current runner default); drops the unused `travis` dependency (it transitively pulled in `json_pure 2.6.3`, which breaks on Ruby 4.0 stdlib).
- [`metanorma/cimas#37`](https://github.com/metanorma/cimas/pull/37) — periodic cimas-self-sync; brings rake.yml and .rubocop.yml into alignment with the current master templates.
- [`metanorma/cimas#38`](https://github.com/metanorma/cimas/pull/38) — new `patches` sync mode for in-place regex-based edits on existing files (refs [`metanorma/ci#274`](https://github.com/metanorma/ci/issues/274), the centralised `required_ruby_version` use case). Bumps cimas to 0.3.0.

CI status: green across all matrix entries (Ruby 3.3 / 3.4 / 4.0, macOS / Ubuntu / Windows) on the post-merge main.

### Wrapper layer — `metanorma/support`

New repo [`metanorma/support`](https://github.com/metanorma/support) hosts the release-workflow wrapper for metanorma-org gems, mirroring the existing `relaton/support`, `fontist/support`, `lutaml/support` pattern. Single file at `.github/workflows/release.yml`, `workflow_call` interface modelled on `fontist/support`'s. Forwards only `rubygems-api-key`, does not forward `pat_token` — the rationale is that the inner `rubygems-release.yml` workflow handles the no-PAT publish path correctly with its idempotent guard, which avoids fragility in the test-gated relay chain.

### Cimas template update

[`metanorma/ci#293`](https://github.com/metanorma/ci/pull/293) updates `cimas-config/gh-actions/master/release.yml` to route through `metanorma/support` instead of calling `metanorma/ci/rubygems-release.yml@main` directly. Two-line change: swap the `uses:` reference, drop the `pat_token` secret line. The cimas-sync wave then propagates this to the 64 metanorma flavour gems + 1 ammitto gem that reference the master template.

### Cimas-sync wave (in flight)

`cimas setup` + `cimas sync` completed across all 187 repos in cimas.yml (185 metanorma + 1 ammitto + 1 metanorma-taste, the last newly added via [`metanorma/ci#296`](https://github.com/metanorma/ci/pull/296)). Sync staged the new caller content on `cimas/sync-ci-workflows` branches in each repo's local clone. Selective per-repo push begins with the metanorma-taste canary; the wider wave follows once the canary verifies the wrapper-routed release end-to-end on rubygems.

### Tracking issue + structural observations

[`metanorma/ci#292`](https://github.com/metanorma/ci/issues/292) opened as the tracking issue for the wrapper convergence work. Body includes three constructive structural observations that complement the wrapper architecture:

1. **"Green means published" as an invariant** — a release run that did not actually publish (no `gem push`, no `release-passed` dispatch) should fail rather than report success. Protects every maintainer from acting on a green dispatch that didn't ship.
2. **Downstream cascade as a first-class observable step** — `release-passed` → `notify` → `mn-processor-notify` failures should surface, not silently no-op.
3. **Release-flow contract test in `metanorma/ci` CI** — an end-to-end test of the reusable workflow (bump → publish to a test source → emit `release-passed` → assert a downstream consumer received the dispatch). Changes to the shared workflow then break in metanorma/ci's own CI rather than in a maintainer's announced release.

These remain useful regardless of the wrapper convergence; the wrapper insulates metanorma-org from the call-chain-shape-specific failure modes, and the invariant + contract test would catch the next class of failure before it surfaces in production.

### Side: relaton-render alignment

[`relaton/relaton-render#79`](https://github.com/relaton/relaton-render/pull/79) (merged) restores `relaton-render`'s release.yml to the `relaton/support` wrapper convention used by every other relaton gem. Aligns relaton-render with the rest of the relaton org's release path.

### Side: oss-guides Lint/MissingSuper

[`riboseinc/oss-guides#82`](https://github.com/riboseinc/oss-guides/pull/82) adds `Lint/MissingSuper: AllowedParentClasses: [Liquid::Drop]` to the inherited ribose ruleset. Liquid::Drop is a recurring architectural feature across the metanorma stack (7+ repos use it in production); the cop exception lives in the centralised ruleset rather than as per-repo drift.

## Phase B — Cimas refactor (post-batch)

After the Phase A work has unblocked the 2026-06-19 batch and the metanorma-taste canary plus broader wave have verified the wrapper end-to-end, cimas gets a substantive refactor under Ronald's style prompt.

### Code standards (per Ronald's 2026-06-16 prompt)

> Ensure code cleanliness and OOP and MECE and fully model-driven, semantically-driven and open/closed principle, DRY, performance, single source of truth, fully achieves encapsulation and uses high-level architecture. ultrathink. Always think about what can we improve here in architecture and code? Make sure we have good specs throughout. Never use private send methods (breaks encapsulation), instance variable set/get, never use respond_to (poor typing), and ensure that we do not use require_relative (or "require" with code within our library due to load paths) and instead use ruby autoload (define in the immediate parent namespace's file path [create file if it doesn't exists]).

### Deliverables

- **Autoload conversion**: replace `require_relative` and bare `require` for in-library code across `lib/cimas/**/*.rb` with Ruby `autoload`, defined in the immediate parent namespace's file path (file created if absent). Restructure file layout where namespace-to-file path doesn't already align.
- **OOP/MECE decomposition of `Cimas::Cli::Command`**: the current class carries setup, sync, diff, push, pull, open-prs, and for-each in one body. Each subcommand becomes its own class with single responsibility; shared infrastructure (config loading, repo iteration, github-client wiring) factored into a separate seam.
- **Encapsulation cleanup**: eliminate `instance_variable_get`/`instance_variable_set`, `send` to private methods, and `respond_to?` wherever they appear.
- **YAML schemas for the cimas config files**: schemas for `cimas-config/cimas.yml`'s `repositories:` block (per-repo entries: `remote`, `branch`, `files:`, `template:`), the templates inheritance, the patches block (added in #38), and any per-org config under `cimas-config/gh-actions/<org>/`.
- **Documentation**: README expansion covering install, config schema reference, per-subcommand usage, and the patches mode introduced in #38; inline rdoc on the public API surface.
- **Specs throughout**: the existing suite covers `apply_patches` (added with #38) but is sparse on the older subcommands. Bring coverage up across the refactored class boundaries.

### Phase B trigger

Phase B starts when all four of these are true:

1. The cimas-sync wave on metanorma/* has merged across the affected repos without regressions.
2. A metanorma flavour gem has successfully released via the new wrapper path end-to-end (gem on rubygems, tag pushed, downstream cascade fired).
3. The 2026-06-19 batch release window has passed cleanly.
4. No objections from Ronald or other maintainers surface on this plan or on the linked issues / PRs.

Until those four hold, Phase B is paused.

## Linked work surface

| Surface | Status |
|---|---|
| [`metanorma/cimas#42`](https://github.com/metanorma/cimas/pull/42) (ostruct) | merged |
| [`metanorma/cimas#43`](https://github.com/metanorma/cimas/pull/43) (bundler + travis kill) | merged |
| [`metanorma/cimas#37`](https://github.com/metanorma/cimas/pull/37) (self-sync) | merged |
| [`metanorma/cimas#38`](https://github.com/metanorma/cimas/pull/38) (patches mode) | merged |
| [`metanorma/cimas#41`](https://github.com/metanorma/cimas/pull/41) (contents:read variant) | closed (superseded by #37; contents:read decision deferred to upstream template) |
| [`metanorma/support`](https://github.com/metanorma/support) (new repo, wrapper) | live |
| [`metanorma/ci#292`](https://github.com/metanorma/ci/issues/292) (wrapper convergence tracking issue) | open |
| [`metanorma/ci#293`](https://github.com/metanorma/ci/pull/293) (cimas template routing) | merged |
| [`metanorma/ci#296`](https://github.com/metanorma/ci/pull/296) (metanorma-taste added to cimas.yml) | merged |
| [`relaton/relaton-render#79`](https://github.com/relaton/relaton-render/pull/79) (relaton/support restoration) | merged |
| [`riboseinc/oss-guides#82`](https://github.com/riboseinc/oss-guides/pull/82) (Lint/MissingSuper for Liquid::Drop) | open |
| Cimas-sync wave on metanorma/* (selective push) | in flight, canary on metanorma-taste |
| Metanorma-taste canary release via wrapper | pending wave-PR merge |
| 2026-06-19 batch release | scheduled |

## Out of scope

- Other orgs' release flows (relaton, lutaml, plurimath, fontist) — already wrapper-protected via their respective `<org>/support` repos. No action needed.
- The `master/release_wo_bundle_install.yml` variant referenced by 3 metanorma repos (metanorma, metanorma-utils, ...) — intentionally untouched by #293; can be aligned in a follow-up if needed.
- Bug reports filed only as draft on the metanorma-cli session's incident track — held pending specific need-to-file signal. Two structural bugs in the shared rubygems-release.yml workflow have been observed (silent-green non-publish under `gated: true` + PAT; `rake release` GemNotFound on the do-release path after Gemfile.lock removal); the wrapper architecture neutralises both for metanorma-org direct-callers, so filing them is informational rather than urgent.

🤖
