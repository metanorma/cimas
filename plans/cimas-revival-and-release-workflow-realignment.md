# Cimas revival and release-workflow realignment

Status as of 2026-06-28. Working draft kept locally; this file is the canonical published record. Updates land as direct commits to `main` per the org's plans/ convention (no PR ceremony for plan-only commits).

## Outcome — 2026-06-28: Public husk fix for `metanorma-nist` + `metanorma-bsi` (closing the 2019 privatisation hole)

A latent architectural hole was closed today: when `metanorma-nist` and `metanorma-bsi` were privatised in 2019 at the request of NIST and BSI, their existing public RubyGems entries were left in place at their last 2021-era versions. For five years anyone running `gem install metanorma-nist` from public RubyGems (without scoping their Gemfile to the private GH Packages source) got the 2021-era gem with 2021-era dependency pins, silently dragging the entire downstream metanorma stack backwards.

**Discovery path.** Surfaced via triage of [`metanorma/metanorma#568`](https://github.com/metanorma/metanorma/issues/568) (Peter Wyatt, PDF Association). The original report turned out to be unrelated env-orphan gems on the reporter's side (same shape as the earlier [`metanorma-pdfa#38`](https://github.com/metanorma/metanorma-pdfa/issues/38) — `asciidoctor-iso` → `iso-bib`), but triage of it uncovered this distinct stale-public-husk pattern as a real concern.

**Audit.** All 20 metanorma flavour repos checked: `metanorma-nist` and `metanorma-bsi` are the only two fitting the private+stale-on-public pattern. Other stale public versions exist (`gb`, `vg`, `m3d`, `mpfa`, `m3aawg`) but those repos are archived and not on the release path, so they don't need husking.

**Fix shipped.** Public husk gems published to RubyGems, each with zero runtime dependencies and a deprecation `warn` on load pointing at the private GH Packages source:

- [`metanorma-nist 1.5.0`](https://rubygems.org/gems/metanorma-nist/versions/1.5.0) — above public `1.3.2`, in the version gap between private `1.4.5` and private `2.0.0`, below the active private major `2.x` (current `2.8.7`). Tracking: [`metanorma/metanorma-nist#497`](https://github.com/metanorma/metanorma-nist/issues/497) (closed on publish).
- [`metanorma-bsi 0.7.0`](https://rubygems.org/gems/metanorma-bsi/versions/0.7.0) — above public `0.0.1`, in the version gap between private `0.6.3` and private `1.0.0`, below the active private major `1.x` (current `1.6.9`). Tracking: [`metanorma/metanorma-bsi#625`](https://github.com/metanorma/metanorma-bsi/issues/625) (closed on publish).

**Source of record.** [`metanorma/ci:husks/`](https://github.com/metanorma/ci/tree/main/husks) (committed via [`metanorma/ci#311`](https://github.com/metanorma/ci/pull/311)) — gemspecs, minimal `lib/` namespace, README explaining the pattern.

**Why higher versions, not yanks.** Yanks are irreversible per RubyGems rules and burn the version slot. Publishing higher-versioned husks achieves the same practical effect (resolver picks the higher version by default) without losing the ability to re-use the version namespace if circumstances change.

**Net effect.**
- `gem install metanorma-nist` / `metanorma-bsi` from public RubyGems now resolves to the husk, prints a deprecation warning, and pulls no other gems. No more silent stack drag.
- Private GH-Packages consumers (anyone with a scoped Gemfile) continue to get the current private version unchanged.

**Wyatt's `metanorma/metanorma#568` itself was closed** with an env-cleanup ELI5 response — same shape and resolution as his earlier `metanorma-pdfa#38`. The bug was not caused by the husk gap; the husk gap was a separate concern surfaced during triage.

**Policy gap remains for the future.** This fix handles the two existing instances. The underlying policy hole — that privatising a metanorma-org repo doesn't automatically yank-or-husk its public counterpart — is not yet closed. If/when a future flavour gem gets privatised, the same pattern could recur. Worth considering: a cimas-side check at sync time that flags any privatised repo whose public counterpart is still resolvable, OR a documented checklist step at privatisation time. Out of scope for this fix; surfaced as a follow-up.

---

## Outcome — 2026-06-18: gated-direct release model adopted; `metanorma/support` wrapper stood down

After both approaches were exercised against live releases — the wrapper via the `metanorma-taste` 1.0.8 canary, the gated-direct path via an `html2doc` 1.11.1 canary — the **test-gated direct release model is the adopted direction for the metanorma org**, and the `metanorma/support` wrapper layer described in Phase A below has been **stood down** (not adopted).

What settled it: the test-gated release path in `metanorma/ci`'s `rubygems-release.yml` — the [test-gated re-architecture](https://github.com/metanorma/ci/pull/289) plus the 2026-06-11/06-12 immediate-publish and identity-after-bump fixes — was verified working **end-to-end** via the `html2doc` 1.11.1 canary on 2026-06-18: `workflow_dispatch` bump+tag → tag-triggered test matrix → `do-release` → publish, with `html2doc 1.11.1` confirmed live on rubygems. With the gated path confirmed reliable, the wrapper's immediate-publish indirection is unnecessary for metanorma gems, and maintaining a second release pattern in the org would only add divergence from the `isodoc` / `metanorma-standoc` path already in use.

Actions taken to land this outcome (2026-06-18):

- **cimas master template reverted to gated-direct.** `cimas-config/gh-actions/master/release.yml` again routes through `metanorma/ci/.github/workflows/rubygems-release.yml@main` and forwards `rubygems-api-key` + `pat_token` (commit `a9f7ca1` on `metanorma/ci`), so future cimas-syncs reproduce the gated-direct caller, not the wrapper.
- **Wave PRs closed.** The 144 open `cimas/sync-ci-workflows` PRs that routed callers through `metanorma/support` were closed as superseded.
- **`metanorma-taste` reverted** to gated-direct ([`metanorma/metanorma-taste#149`](https://github.com/metanorma/metanorma-taste/pull/149)) — it was the one gem flipped to the wrapper during canary work.
- **`metanorma/support` repo** remains in place as infrastructure but is unused; remove or retain at the maintainer's discretion.

Net effect: metanorma-org gems release through the same test-gated direct path as `isodoc` and `metanorma-standoc`. No wrapper migration is in flight. **Everything in the Phase A / Phase B material below is retained as a record of what was explored — it is not the current plan.**

---

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

`cimas setup` + `cimas sync` completed across all 187 repos in cimas.yml (185 metanorma + 1 ammitto + 1 metanorma-taste, the last newly added via [`metanorma/ci#296`](https://github.com/metanorma/ci/pull/296)). Sync staged the new caller content on `cimas/sync-ci-workflows` branches in each repo's local clone. Selective per-repo push begins with the metanorma-taste canary at [`metanorma/metanorma-taste#147`](https://github.com/metanorma/metanorma-taste/pull/147); the wider wave follows once the canary verifies the wrapper-routed release end-to-end on rubygems.

#### Deferred follow-up — wave-PR permissions amend gaps

A second pass over the 155 wave branches added a `permissions: contents:write, packages:write, id-token:write` block to each caller's `release.yml`, matching what the cimas master template now ships. Per GitHub Actions semantics, GITHUB_TOKEN scope is set by the calling workflow, not the called reusable workflow, so the block needs to live on each repo's `release.yml`, not only on the `metanorma/support` wrapper. The `id-token: write` line also prepares the path for rubygems Trusted Publishing (OIDC-based, replacing API-key auth — current direction per https://guides.rubygems.org/trusted-publishing/).

Outcome of the amend pass:

- **68 wave branches updated cleanly** — these now carry the permissions block.
- **~87 wave branches** use non-master-template release.yml variants and need a second pass with extended regex matching to apply the block.
- **6 *-ruby tooling repos** (`emf2svg-ruby`, `mn2pdf-ruby`, `mn2sts-ruby`, `mnconvert-ruby`, `mnconvert`, `sts2mn-ruby`) need custom one-off edits — they use non-standard release.yml structures.
- **1 push-failed repo** (`atmospheric`) still outstanding from the original wave push — needs investigation for access / state.

The migration to Trusted Publishing itself is Phase B scope; current releases continue successfully via the API-key path (verified: metanorma-taste 1.0.8 released 2026-06-16 12:54 UTC).

#### Deferred follow-up — 25 wave-PR creation/update failures

The wave-PR creation loop opened or repurposed 155 PRs successfully but **25 failed** to create or update. These include several core batch-release flavour gems that **must** have wrapper PRs landed before the next batch:

- **Core flavour gems (priority)**: `metanorma/isodoc`, `metanorma/metanorma-cli`, `metanorma/metanorma-standoc`, `metanorma/metanorma-bsi`, `metanorma/metanorma-nist`.
- **`mn-templates-*` cluster** (10 repos): `mn-templates-cc`, `mn-templates-iec`, `mn-templates-ietf`, `mn-templates-iso`, `mn-templates-itu`, `mn-templates-m3aawg`, `mn-templates-nist`, `mn-templates-ogc`, `mn-templates-un`.
- **Tooling and misc** (10 repos): `bipm-data-outcomes`, `eccma-iso-scor-vocab` (#5 edit failed), `emf2svg-ruby`, `enisa-eucs`, `mn-requirements`, `mn-samples-mbxif`, `mn2pdf-ruby`, `mnconvert-ruby`, `mnconvert`, `pngcheck-ruby`, `tex2mn`.

Likely root causes to investigate: non-default base-branch (e.g. `master` rather than `main` on some), existing PR conflicts, missing workflows or non-standard repo state. Each failure triaged individually; the 5 core flavour gems prioritised first.

#### Deferred follow-up — taste's `.rubocop.yml` discipline

The canary PR ([`#147`](https://github.com/metanorma/metanorma-taste/pull/147)) intentionally omits the `.rubocop.yml` update that cimas-sync also generated. Reason: doing so would strip taste's existing `inherit_from: .rubocop_todo.yml` line, unmasking ~4242 bytes of grandfathered rubocop violations as CI noise during the canary. Holding it back keeps the canary focused on wrapper validation while preserving taste's current rubocop discipline.

The second piece of taste's local rubocop config (`Lint/MissingSuper: AllowedParentClasses: [Liquid::Drop]`) was centralised the same day via [`riboseinc/oss-guides#82`](https://github.com/riboseinc/oss-guides/pull/82) and becomes redundant when the rubocop.yml sync lands later — no work needed for that piece.

The `.rubocop_todo.yml` follow-up will revisit taste's debt with one of: paying it down, preserving the per-repo override via cimas's new patches mode (PR #38), or accepting the unmasking and surfacing the violations in CI. The decision sets precedent for similar overrides the broader wave may surface across the other ~64 metanorma repos, so it's deliberate.

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
