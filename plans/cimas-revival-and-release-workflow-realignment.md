# Cimas revival and release-workflow realignment

Status as of 2026-06-29. Working draft kept locally; this file is the canonical published record. Updates land as direct commits to `main` per the org's plans/ convention (no PR ceremony for plan-only commits).

## Standing scope boundary — `metanorma/packed-mn` is led by @ronaldtse

**Hands-off rule (recorded 2026-06-29).** Maintenance of `metanorma/packed-mn` and its release-dispatch chain ([`metanorma/metanorma-cli#428`](https://github.com/metanorma/metanorma-cli/issues/428): 4-of-5 platform workflows currently disabled, `repository_dispatch` wire has not fired since 2026-05-17, no release tag since v1.14.4 on 2025-12-01) sits with @ronaldtse. From this plan's scope **we do not action `metanorma/packed-mn` directly** — no reconstruction of the dispatch wire from our side, no re-enablement of disabled platform workflows, no PRs against the repo — beyond surfacing diagnostic facts on the relevant tickets for visibility.

In practice:

- Diagnostic facts (chain-state observations, build-log evidence) can land as factual comments on `cli#428` for visibility.
- The `cli#428` ticket is cross-referenced from this SSOT and from `release-chain.md` for completeness.
- Any change to `metanorma/packed-mn` itself waits on an explicit go-ahead from @ronaldtse, even where a fix would be small. The hands-off rule outranks the convenience.

For background context on the broader release-trigger surface: the docker-rebuild side of the release dispatch chain had been silently failing every metanorma-cli release since 2026-05-16 (per [`metanorma/metanorma-cli#426`](https://github.com/metanorma/metanorma-cli/issues/426)). That side was fixed end-to-end on the night of 2026-06-28/29 — see the "Outcome — 2026-06-29" entry below for the chain validation. Recording it here so the cross-referenced `cli#428` thread has the full chain-health picture available when packed-mn work resumes.

This scope boundary can be revisited when packed-mn work resumes; until then it is the working assumption for the cimas-revival scope tracked in this plan.

---


## Outcome — 2026-06-29 (evening): Open-issue sweep across the cimas/ci ticket queue

A single session cleared or advanced six tickets in the `metanorma/ci` queue, plus filed a new design candidate and posted chain-health evidence on `metanorma-cli#428`.

### Items cleared

| # | Item | Resolution |
|---|---|---|
| 1 | [`metanorma/ci#237`](https://github.com/metanorma/ci/issues/237) — "Investigate whether to delete old fontist-setup-action workflow" | Investigation comment + [`#317`](https://github.com/metanorma/ci/pull/317) PR. Decision (Option B): **keep both** `fontist-setup` (all-in-one, used by `metanorma-cli/.github/workflows/fonts-check.yml`) and `fontist-repo-setup` (Fontist-already-installed minimal variant) — they are complementary, not redundant. Fix the wrong description on `fontist-setup` (it had a copy-pasted description from `gh-rubygems-setup-action`). Document the distinction in both `action.yml`s so future maintainers don't pick the wrong variant. The fontist toolchain is fragile enough that deletion + migration (Option A) was rejected as not worth the risk. |
| 2 | [`metanorma/metanorma-cli#428`](https://github.com/metanorma/metanorma-cli/issues/428) — packed-mn dispatch chain | Informational comment posted with the docker-chain validation evidence from earlier today (the new `release-passed → release-tag → build-push` chain firing green for the first time against `cli` v1.16.6). Framed as chain-health context, not a request. Scope boundary recorded above (packed-mn led by @ronaldtse, hands-off from this plan's scope). |
| 3 | [`metanorma/ci#292`](https://github.com/metanorma/ci/issues/292) — "Bringing metanorma org to release-workflow parity" | Close-as-superseded comment posted. Scope 1 (wrapper convergence) stood down 2026-06-18; scope 2 (three observability observations) rehomed to `#302` on 2026-06-24. Nothing actionable remains under `#292` itself. |
| 4 | [`metanorma/ci#272`](https://github.com/metanorma/ci/issues/272) + [`#276`](https://github.com/metanorma/ci/issues/276) — tests-passed permissions cluster | [`PR#277`](https://github.com/metanorma/ci/pull/277) merged (`e56e2b3`) — the 2-line PAT-restore fix opened 2026-05-13, recrafted per @ronaldtse's "I meant (B)" review on 2026-05-15, all checks green, `mergeable: CLEAN`. Investigation also confirmed: (a) the master template's workflow-level `permissions: contents: write` is correct; (b) sample of 7 active callers all currently at `contents: write` (the original `contents: read` cap on `metanorma-plugin-datastruct` has been swept by an intervening regen); (c) all sibling reusable workflows (`xml2rfc-rake.yml`, `inkscape-rake.yml`, `monorepo-rake.yml`, `mn-processor-rake.yml`, `libreoffice-rake.yml`, `graphviz-rake.yml`, `rubygems-release.yml`) already have the PAT restore on both dispatch steps. Both Consequences of `#276` mechanically resolved; close-out comments posted on `#272` and `#276`. |
| 5 | [`metanorma/ci#300`](https://github.com/metanorma/ci/issues/300) — "cimas revival: design gaps" | **Gap-4 proposal added**: flatten stale cimas PRs on new-wave-open. Surfaced by maintainer observation that PRs are missed for ~2 weeks on active-maintainer repos and longer on inactive ones. Proposed shape: strict-superset check, label-and-comment (not auto-close), with a single-branch-per-repo alternative noted for Phase B. |

### Net effect on the queue

Five items moved from "open, awaiting review" to "resolved or with clear close-out." `#272`, `#276`, `#292` are ready for close (suggested in comments). `#317` is a small fontist description-fix PR open for review. `#300` has a fourth design candidate filed. `cli#428` has fresh chain-health evidence on the thread.

The pattern is escalation-through-work: progress concrete items rather than waiting on review, while leaving maintainer authority intact on the open design questions and the packed-mn scope. The artefacts (a merged PR, comment threads, a labelled investigation, the Gap-4 proposal) are concrete things to react to rather than further "what do you think?" prompts.

### Carryover for the next working slot

- `#274` pubid-narrow-wave (10 PRs, mechanical regeneration) — clones a fresh `cimas-wd`, runs `cimas sync -g pubid`, pushes 10 branches, opens 10 PRs, watches CI.
- Incidental sweep: any residual `contents: read` cap on pubid-* callers gets corrected by the same regeneration (clean overlap with `#272/#276`).

---

## Outcome — 2026-06-29: Stale bundler-cache root-cause fix; 5-week silent docker-block broken; new release→docker chain validated end-to-end for the first time

Two structurally-related failures in the release chain were diagnosed and fixed tonight, and a third was retrospectively validated as actually working. Net effect: **the metanorma-cli docker chain has shipped a new image for the first time since 2026-05-16**, a ~6-week silent-failure window.

**The proximate failure.** `metanorma-cli` v1.16.6 `do-release` failed twice (2026-06-27 + 2026-06-28) on `Bundler::GemNotFound: metanorma-nist`, despite the gem being a normal entry in the `Gemfile`. Locally on a maintainer's machine, the same `bundle install` succeeded. The third attempt tonight succeeded after the fix landed, with `metanorma-cli 1.16.6` now live on rubygems.

**Root cause ([`metanorma/ci#314`](https://github.com/metanorma/ci/issues/314)).** `rubygems-release.yml`'s release job called `ruby/setup-ruby@v1` with `bundler-cache: true`. The cache key was a hash of `Gemfile.lock`. metanorma-org gems don't commit `Gemfile.lock`, so the cache key was unstable, and `ruby/setup-ruby` used its **restore-key fallback** to restore a cache from a previous release run that had a different Gemfile state. After the stale restore, `bundle install` only installed the diff — typically a single recently-bumped gem — leaving any newly-added gem (here `metanorma-nist`) **silently absent**. `bundle exec rake release` then failed at resolve time. The log was unambiguous: cache key `Gemfile.lock-b31809f053...` (current) vs restore-key hit `Gemfile.lock-ebde68ccbd...` (older, different) — confirmed stale restore. Only `mn2pdf 2.60` was installed post-restore; every other gem was assumed-cached. This bug was generic — it bit every gem release going through `rubygems-release.yml`, not just metanorma-cli.

**Fix shipped in two PRs.**

- [`metanorma/ci#315`](https://github.com/metanorma/ci/pull/315) — hardcoded `bundler-cache: false` on the release job's `ruby/setup-ruby` step; deprecated the `inputs.bundler_cache` parameter (still accepted, value ignored, default flipped to `false`). Closed `#314`.
- [`metanorma/ci#316`](https://github.com/metanorma/ci/pull/316) — added the explicit `Fresh bundle install` step (`bundle install --jobs 4 --retry 3`) that `#315` regressed. With `bundler-cache: false`, `ruby/setup-ruby` does NOT run `bundle install` itself, and `#315` had not added a replacement step — so the release job was running `bundle exec rake release` against an empty gem set, dying in 6 seconds on the same `Bundler::GemNotFound`. Inserted the explicit step between `Remove Gemfile.lock before bump` and `Bump version`, mirroring the preflight job's structure ([`#313`](https://github.com/metanorma/ci/pull/313)).

The preflight job ([`#313`](https://github.com/metanorma/ci/pull/313)) had already been using `bundler-cache: false` plus an explicit `bundle install` since it landed — that's why local `cimas release-preflight` passed in the days the live CI release was failing on the same gem set. The fix brings the release job to the same hygiene.

**Why this slipped past `#315` review.** Conflated "`ruby/setup-ruby` with `bundler-cache: true` runs `bundle install` internally" with "the workflow has an `bundle install` step somewhere." It did not. The cache flag was the only install mechanism in the release job. Step-tracing the release job, or reading the preflight job closely enough to notice it has a separate `bundle install` step *for a reason*, would have caught it. Lesson banked for future setup-ruby flag changes: trace every step's source of installed gems before toggling the cache flag.

**Retrospective validation of `#426` (the silent docker-dispatch bug).** [`metanorma/metanorma-cli#426`](https://github.com/metanorma/metanorma-cli/issues/426), closed 2026-06-25, had documented that every metanorma-cli release since 2026-05-16 had silently failed to trigger the downstream `metanorma-docker` rebuild. The old chain was `ruby-artifacts.yml` on `release: published` → `gh workflow run build-push.yml --field version=...` against metanorma-docker. metanorma-docker's `build-push.yml` had a bare `workflow_dispatch:` with no `inputs:` block, so the API rejected the `version` field with HTTP 422. Both dispatches failed; the docker images on Docker Hub had been ~5 versions stale.

The fix was a chain rewrite: route through `peter-evans/repository-dispatch` with event-type `release-passed` from `rubygems-release.yml` itself (step 22 of the release job), receive in metanorma-docker via a new `release-tag.yml` workflow on `repository_dispatch: types: [release-tag]`, which creates the version tag in the docker repo, which then triggers `build-push.yml` and `build-push-windows.yml` on tag push. This chain was wired in `#426`'s close but never actually fired against a real release — the bundler-cache bug was blocking every release attempt that would have exercised it.

Tonight was the first end-to-end test:

| Time (UTC) | Event |
|---|---|
| 14:14:41 | metanorma-cli `do-release` repository_dispatch fired (third attempt) |
| 14:16:27 | metanorma-cli release job completed success — `gem push` of `metanorma-cli 1.16.6` to rubygems live |
| 14:16:27 | `Dispatch release-passed` step (rubygems-release.yml line 329) succeeded |
| 14:18:44 | metanorma-docker `release-tag` workflow ran on repository_dispatch — created the `v1.16.6` tag |
| 14:20:40 | metanorma-docker `build-push` and `build-push-windows` triggered on `main`-branch push — both completed success |
| 14:20:40 | metanorma-docker `build-push` and `build-push-windows` triggered on `v1.16.6` tag push — in progress at time of writing |

**Net effect.** The new release→docker chain — `rubygems-release.yml` `Dispatch release-passed` → metanorma-docker `release-tag` → tag-push → `build-push*` — is verified working end-to-end against a live release for the first time. The ~6-week silent-failure window (2026-05-16 → 2026-06-29) closed.

**Structural follow-ups surfaced.**

1. **The "green means published" invariant from [`#292`](https://github.com/metanorma/ci/issues/292) needs to extend to "green means downstream cascaded".** `#426` and `#314` both manifested as silent-failure classes — a release run reported success even though the desired downstream effect (docker rebuild for `#426`; `gem push` for `#314`) had not actually happened (or happened against a broken pipeline). The "green means published" invariant catches the `#314` shape (release job green but `gem push` skipped or failed mid-step); it does NOT catch the `#426` shape (release job green, dispatch step green, but receiver rejected the dispatch with HTTP 422 silently in a separate run). The invariant needs to extend to the downstream cascade as an observable: assert that the dispatched event was acknowledged downstream within a bounded time window, or fail the release run. Filed as a follow-up scope for `#302`.

2. **`bundler-cache: true` on `ruby/setup-ruby` is structurally unsafe in any workflow that mutates `Gemfile.lock` mid-run.** Any future caller of `rubygems-release.yml`, or any new workflow with similar shape, should default to `bundler-cache: false` plus an explicit `bundle install` step. Worth adding as a check in the cimas master template review — when reviewing inherited workflow templates against the master, flag any `bundler-cache: true` in a workflow that also does `rm -f Gemfile.lock`.

3. **An end-to-end contract test of the full release chain (the third structural observation in `#292`) would have caught both `#314` and `#426` before they shipped.** A test in `metanorma/ci`'s own CI that bumps a fake gem, publishes to a test rubygems source, emits `release-passed`, and asserts the downstream tag-push and `build-push*` runs complete, would break any change to the shared workflow that breaks the chain. Open as scope.

**Linked work.** [`metanorma/ci#314`](https://github.com/metanorma/ci/issues/314) (root-cause analysis) — closed by `#315`. [`metanorma/ci#315`](https://github.com/metanorma/ci/pull/315) (hardcode `bundler-cache: false`) — merged. [`metanorma/ci#316`](https://github.com/metanorma/ci/pull/316) (add explicit `bundle install` step, regression hotfix from `#315`) — merged. [`metanorma/metanorma-cli#426`](https://github.com/metanorma/metanorma-cli/issues/426) (docker dispatch silently fails every release) — closed 2026-06-25, retrospectively validated tonight. `release-chain.md` in `metanorma/ci` updated to name the stale-cache failure mode under layer 7 and to note both `#315` and `#316` as the resolution.

---

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

---

## Forward roadmap — cimas/ci rehabilitation arc past `#300` (recorded 2026-06-29 evening)

Stocktake of remaining work beyond the 2026-06-29 escalation sweep. Roughly ordered by ripeness for daylight pickup.

### 1. Near-term concrete (ready to execute, mechanical)

| Item | Effort | Note |
|---|---|---|
| **a. `#274` pubid-narrow-wave** — 10 PRs across `pubid-bsi`, `pubid-ccsds`, `pubid-cen`, `pubid-core`, `pubid-iec`, `pubid-ieee`, `pubid-iso`, `pubid-itu`, `pubid-jis`, `pubid-nist`, `pubid-plateau` | 2 hrs | Tightest-blast-radius cluster; verifies cimas-side wave mechanics post-`#314`/`#316` |
| **b. `#274` full wave** — the remaining 13 TODO repos: `html2doc`, `iso690render`, `metanorma`, `metanorma-cli`, `metanorma-plugin-lutaml`, `metanorma-utils`, `mn2pdf-ruby`, `mnconvert-ruby`, `niso-jats`, `reverse_adoc`, `rfcxml`, `sts-ruby` | ~1-1.5 daylight session | Same cimas-wd, second pass |
| **c. `#274` MISSING triage** — `metanorma-plugin-datastruct`, `mn2pdf`, `mn2sts`, `rfc2md`, `stepmod2mn` | ~30 min each | Diagnose: archived? renamed? out-of-scope? |
| **d. `#274` NOVER fix** — `csa-ccm-tools/csa-ccm.gemspec` | ~15 min | Manually add `required_ruby_version` line since the patches regex can't insert |

### 2. `#302` observability — scope additions

| Item | Effort | Note |
|---|---|---|
| Post-`gem push` rubygems-API verification step in `rubygems-release.yml` | 1-2 hrs | Catches the `#314`-class silent-fail (claimed push, gem absent from API) |
| Post-dispatch acknowledgement poll (bounded wait for receiver workflow) | 2-3 hrs | Catches the `#426`-class silent-fail (dispatch accepted but rejected by receiver) |
| Document "dispatch accepted" vs "dispatch acted on" distinction in `release-chain.md` | 30 min | Cheap, high-clarity-value |

### 3. `#309` chain streamlining — follow-ups

| Item | Effort | Note |
|---|---|---|
| **End-to-end contract test in `metanorma/ci`'s own CI** | **multi-day** | Highest single value-add. Would have caught both `#314` and `#426`. Test gem fixture + test downstream receiver + workflow assertions. |
| `bundler-cache: true` + `Gemfile.lock` mutation check (cimas template audit automation) | 1-2 hrs | Forensic scan for the unsafe pattern across caller workflows |
| Comprehensive layer-by-layer failure-mode documentation in `release-chain.md` | 3-4 hrs | Beyond the layer-7 entry already there |

### 4. `#300` Gap IMPLEMENTATIONS (the big work past the docs pass)

All four Gaps are documented as "proposed, not implemented" in [`metanorma/cimas:README.adoc`](https://github.com/metanorma/cimas/blob/main/README.adoc) (commits `8f1705f`, `307955d`, `9e94446`); the table below tracks the implementation effort.

| Gap | Effort | Note |
|---|---|---|
| Gap 1 — per-repo `with:` rendering | ~4-5 hrs | Schema + renderer + ERB template + tests. **Gates Gap 2.** |
| Gap 4 — flatten-stale cimas PRs | ~4-5 hrs full / ~1.5-2 hrs cheaper | Cheaper version skips strict-superset gate (label-and-comment all open `cimas-sync-*` PRs on new-wave-open) |
| Gap 3 — drift-audit subcommand | ~6-8 hrs | Diff classifier + heuristics + sync-blocking semantics. Largest mechanical piece. |
| Gap 2 — monorepo sub-template family | **multi-day**, depends on Gap 1 | Reusable-workflow extensions in `metanorma/ci` + new `gh-actions/monorepo/*` template family + `metanorma/pubid` as first migration target |

### 5. Hygiene cleanup carried from the 2026-06-19 / 2026-06-24 waves

| Item | Effort | Note |
|---|---|---|
| 25 wave-PR creation failures from the 2026-06-19 wave (core flavour gems `isodoc`/`metanorma-cli`/`metanorma-standoc`/`metanorma-bsi`/`metanorma-nist`; `mn-templates-*` cluster; tooling cluster) | half-day | Per-repo investigation; non-default base-branch + existing PR conflicts likely causes |
| 87 wave-PR permissions amend gaps (non-master-template `release.yml` variants) | half-day | Second regex pass on each |
| 6 *-ruby tooling repos (`emf2svg-ruby`, `mn2pdf-ruby`, `mn2sts-ruby`, `mnconvert-ruby`, `mnconvert`, `sts2mn-ruby`) needing custom one-off edits | 2-3 hrs | Non-standard `release.yml` structures |
| 1 `atmospheric` push-failed wave PR | ~30 min | Investigate access/state |
| Older open `metanorma/ci` tickets: [`#278`](https://github.com/metanorma/ci/issues/278) (patch-release breaking-change heuristic), [`#258`](https://github.com/metanorma/ci/issues/258) (dev deps in release), [`#210`](https://github.com/metanorma/ci/issues/210) (bundle update in flavor tests in docker container) | 1-3 hrs each | Concrete-action escalation per ticket |
| Coradoc-style opt-outs across other repos (additional Gap 3 instances beyond `#318`) | 1-2 hrs | Audit the org for the pattern |

### 6. Long-horizon / Phase B

| Item | Effort | Note |
|---|---|---|
| Cimas Phase B refactor (autoload, OOP/MECE decomposition of `Cli::Command`, no `respond_to?`/`instance_variable_get`/`send`, YAML schemas, README expansion, specs throughout) | **multi-week** | Per the 2026-06-16 code-standards prompt. The cimas-side of the rehabilitation. |
| Trusted Publishing OIDC migration (replacing rubygems API-key auth) | **multi-week** | Direction set in 2026-06-19 wave's `id-token: write` permissions block; not actually wired |
| Stale public husks for archived flavour gems (`gb`, `vg`, `m3d`, `mpfa`, `m3aawg`) | 1-2 hrs | Same pattern as the 2026-06-28 `nist`/`bsi` husk fix; lower urgency since these repos are archived |

### 7. Hands-off (out of scope for this plan)

| Item | Note |
|---|---|
| `metanorma-cli#428` packed-mn dispatch chain reconstruction | Led by @ronaldtse per the standing scope boundary above |
| `metanorma/cimas#40` rake.yml `permissions: contents: read` block | @ronaldtse-assigned (cimas template), led by him |

### Working priority for the next several daylight sessions

1. **Complete `#274`** (1.a → 1.b → 1.c → 1.d) — finishes the most visible drift across the stack
2. **Prior-wave residual cleanup** (5) — gets the existing PR queue clean before adding new ones
3. **`#302` post-`gem push` verification + post-dispatch acknowledgement** (2) — biggest observability wins per effort
4. **Older open `metanorma/ci` tickets** `#210`/`#258`/`#278` — concrete-action progression per ticket
5. **End-to-end contract test in `metanorma/ci` CI** (3) — biggest structural win against `#314`/`#426`-class recurrence
6. **`#300` gap implementations** in order: Gap 4 → Gap 1 → Gap 3 → Gap 2 (last; depends on Gap 1)
7. **Phase B / Trusted Publishing / stale husks** — longer-horizon; rides alongside the above

🤖

---

## Outcome — 2026-06-29/30: late-night wave, deprecation triage, plugins family completion, cimas bug surfacings

The carryover wave (Section 1.a + 1.b of the forward roadmap above) was executed late on 2026-06-29 across the processor/tools/metanorma/plugins/model groups in `cimas-wd-2026-06-29`. Net outcome: **8 PRs created, 17 no-op (already template-current), 6 deprecation strips landed, 4 cimas bugs surfaced**.

### Wave outcome — 8 PRs created

Main-wave batch (4 PRs):

- [`metanorma/csa-ccm-tools#38`](https://github.com/metanorma/csa-ccm-tools/pull/38)
- [`metanorma/html2doc#104`](https://github.com/metanorma/html2doc/pull/104)
- [`metanorma/metanorma-cli#431`](https://github.com/metanorma/metanorma-cli/pull/431)
- [`metanorma/mn2pdf-ruby#48`](https://github.com/metanorma/mn2pdf-ruby/pull/48)

Plugins batch (4 PRs — all 4 `metanorma-plugin-*` repos, including 2 newly added to cimas-config):

- [`metanorma/metanorma-plugin-lutaml#285`](https://github.com/metanorma/metanorma-plugin-lutaml/pull/285)
- [`metanorma/metanorma-plugin-glossarist#77`](https://github.com/metanorma/metanorma-plugin-glossarist/pull/77)
- [`metanorma/metanorma-plugin-datastruct#75`](https://github.com/metanorma/metanorma-plugin-datastruct/pull/75) (first ever cimas-sync PR for it)
- [`metanorma/metanorma-plugin-plantuml#55`](https://github.com/metanorma/metanorma-plugin-plantuml/pull/55) (first ever cimas-sync PR for it)

### Wave outcome — 17 no-op (already template-current from prior waves)

The 16 metanorma flavour repos (`metanorma-bipm/bsi/cc/generic/iec/ieee/ietf/iho/iso/itu/jis/nist/ogc/plateau/ribose/standoc`) plus `mn2sts-ruby` had wave branches pushed but `gh pr create` returned "No commits between main and cimas-sync-2026-06-29" — meaning their staged content was effectively identical to main. Prior waves had brought them to template-current state already. Healthy sign that the rehabilitation has been propagating across the bulk of the stack.

### Deprecation triage — branches deleted + cimas-config strips

Maintainer triage during the wave identified 3 obsolete metanorma flavour repos (in addition to the pubid + iso690render strips landed earlier in the slot):

| Repo | Last release | Stripped via |
|---|---|---|
| `metanorma-csa` | 2025-09-01 (10 mo) | wave branch deleted mid-flight; cimas.yml strip in [`#323`](https://github.com/metanorma/ci/pull/323) |
| `metanorma-m3aawg` | 2023-03-13 (3+ yrs) | same |
| `metanorma-un` | 2024-09-30 (21 mo) | same |

Combined with the earlier [`#319`](https://github.com/metanorma/ci/pull/319) (11 pubid standalones + umbrella) and [`#321`](https://github.com/metanorma/ci/pull/321) (iso690render legacy of relaton-render), the total cimas-config strip for 2026-06-29 is **15 repos**.

### Plugins family completion — `metanorma-plugin-{datastruct,plantuml}` added

[`#322`](https://github.com/metanorma/ci/pull/322) added the 2 missing `metanorma-plugin-*` repos to `cimas-config/cimas.yml`. Pre-existing config inconsistencies found during the audit:

- `metanorma-plugin-datastruct` was in the `plugins` group but had no `repositories:` entry, causing `cimas sync` to log `not configured, skipping` on every wave.
- `metanorma-plugin-plantuml` was absent from both.
- `metanorma-plugin-glossarist` was in `repositories:` but missing from the `plugins` group.

All four are now consistently in both `repositories:` and the `plugins` group.

### Inventory — answering "what's actually in scope?"

300 metanorma org repos in total, of which ~80 are active Ruby gem repos managed by cimas (64 unambiguous-Ruby + 14 metanorma flavours misclassified as HTML/Liquid by GitHub primaryLanguage + `sts-ruby`). 47 Ruby tools not in cimas (deliberately or otherwise). 19 XML schema repos. 47 templates/samples/data. 1 docs site. 1 archived (`metanorma-tutorial`). Plus the `pubid` monorepo as a Gap-2-pending case.

### Cimas bugs surfaced — to be filed as `metanorma/cimas` issues

Tonight's wave surfaced 4 distinct cimas bugs / limitations worth banking:

1. **`cimas open-prs -m` is used as PR title, not body.** Passing a multi-line markdown PR body via `-m` causes HTTP 422 (`title is too long, max 256 chars`). Workaround: bypass `cimas open-prs` and use `gh pr create` directly.

2. **`cimas sync` writes master-template workflow files onto monorepo umbrellas** despite the monorepo's local `uses: ./.github/workflows/...` pattern. Concrete instance: `metanorma/pubid` (the monorepo) got `gh-actions/master/rake.yml` written on top of its monorepo-aware local `rake.yml`, which would break its CI on merge. Hand-cleanup (wave-branch deletion) required. Closely related to [`#300`](https://github.com/metanorma/ci/issues/300) Gap 2; cimas-side detection of monorepo `uses:` shapes would prevent the auto-clobber.

3. **`cimas sync` patches-regex `spec\.required_ruby_version\s*=.*` doesn't match the `s.required_ruby_version` block-variable convention.** `reverse_adoc.gemspec` uses `Gem::Specification.new do |s|` (single-char `s`) instead of `do |spec|`, so the regex skips it. Concrete one-repo edge case tonight but represents a class. Easiest fix: relax regex to `(?:spec|s)\.required_ruby_version\s*=.*`.

4. **`cimas sync` patches-mode warning `pattern did not match, file unchanged` is misleading.** Fires both when the regex genuinely didn't match (no `required_ruby_version` line at all, e.g. NOVER case in `csa-ccm-tools/csa-ccm.gemspec`) AND when the regex did match but `gsub!` returned `nil` because the substitution was identical (gemspec already at target version). UX / log-message clarity issue.

To be filed as one consolidated `metanorma/cimas` issue (1, 3, 4 together since they're small operational improvements; 2 is closely related to `#300` Gap 2 and can cross-reference).

### Reverse_adoc — deferred

`reverse_adoc.gemspec` uses the `s.` block-var convention; patches regex doesn't match. Not in tonight's wave. Two options for follow-up: (a) manually rewrite `reverse_adoc.gemspec` to use `spec.` consistently (15-line repo-style change), or (b) fix cimas Bug 3 above (regex relaxation, one-line cimas change benefiting all `s.`-style gemspecs). Option (b) is the cleaner root-cause fix. Deferred for daylight pickup.

🤖
