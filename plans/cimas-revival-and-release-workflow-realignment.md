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

### 3b. Cimas small operational bug fixes ([`metanorma/cimas#49`](https://github.com/metanorma/cimas/issues/49))

Filed 2026-06-30 from the wave's discoveries. Three small operational improvements:

| Bug | Fix scope | Effort |
|---|---|---|
| `cimas open-prs -m` used as PR title not body (causes HTTP 422 on multi-line bodies) | Add `--body-file PATH` option; keep `-m` as title | ~30-60 min |
| Patches regex `spec\.required_ruby_version\s*=.*` doesn't match `s.` block-var convention (reverse_adoc instance) | Relax regex to `(?:spec\|s)\.required_ruby_version\s*=.*` in cimas-config | 5 min |
| `pattern did not match` warning conflates "regex didn't match" with "no-op identical substitution" | Distinguish the two cases with separate log paths | ~30 min |

Total ~1-2 hrs focused cimas work. Slots in well between observability (`#302`) and the bigger Gap implementations.

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

## Outcome — 2026-06-30 (evening sub-slot): cimas#49 bug fixes shipped end-to-end + #302 observability triplet complete + Gap 4 cheaper implemented

A focused ~1-hour evening sub-slot cleared the cimas-side bug ticket cleanly, completed the entire `#302` observability scope addition, and implemented Gap 4 of `#300` in its cheaper variant. Eight PRs in total, all self-merged.

### Sub-slot PRs

| # | Item | PR |
|---|---|---|
| 1 | `cimas#49` Bug 2 — patches regex `(spec\|s)` + stale pubid group strip | [`metanorma/ci#324`](https://github.com/metanorma/ci/pull/324) |
| 2 | `reverse_adoc` wave PR (unblocked by Bug 2) | [`metanorma/reverse_adoc#100`](https://github.com/metanorma/reverse_adoc/pull/100) |
| 3 | `cimas#49` Bug 1 — `cimas open-prs --body` / `--body-file` flags | [`metanorma/cimas#50`](https://github.com/metanorma/cimas/pull/50) |
| 4 | `cimas#49` Bug 3 — distinguish patches warnings (pattern-absent WARNING vs no-op INFO) | [`metanorma/cimas#51`](https://github.com/metanorma/cimas/pull/51) |
| 5 | `#302` 1st observability addition — post-`gem push` rubygems-API verification step | [`metanorma/ci#325`](https://github.com/metanorma/ci/pull/325) |
| 6 | `#302` 2nd observability addition — post-dispatch acknowledgement poll | [`metanorma/ci#326`](https://github.com/metanorma/ci/pull/326) |
| 7 | `#302` 3rd observability addition — `release-chain.md` "dispatch accepted vs acted on" doc | [`metanorma/ci#327`](https://github.com/metanorma/ci/pull/327) |
| 8 | `#300` Gap 4 cheaper — `cimas open-prs --supersede-stale` flag | [`metanorma/cimas#52`](https://github.com/metanorma/cimas/pull/52) |

### Net effect on the rehabilitation arc

- **`metanorma/cimas#49` issue auto-closed** (all 3 bugs landed; Bug 2 via `ci#324`, Bug 1 via `cimas#50`, Bug 3 via `cimas#51`).
- **`#302` observability scope from the 2026-06-29 follow-up comment is now fully implemented** — all three scope items (post-publish gem verification, post-dispatch acknowledgement, doc the distinction). Future silent-fail classes of the `#314` shape (publish succeeds but gem not live) or `#426` shape (dispatch accepted but no run created) will surface immediately rather than weeks later.
- **`#300` Gap 4 implemented** in its cheaper-variant form (label-and-comment-but-don't-close, no strict-superset gate). Future cimas-sync waves can use `--supersede-stale` to keep the PR queue clean. cimas `README.adoc` updated to reflect "implemented" status with a usage example.

### Forward-roadmap status after this sub-slot

- Section 1 (#274 wave): bulk done. Section 1.b stragglers handled via the late-night Jun 29/30 wave. Reverse_adoc unblocked by Bug 2 and shipped. MISSING + NOVER triage still pending for next-wave inclusion.
- Section 2 (#302 observability): **closed** — all three additions landed (`#325`, `#326`, `#327`).
- Section 3 (#309 streamlining): unchanged from the prior pass. The end-to-end contract test remains the biggest single piece, multi-day; comprehensive layer-by-layer documentation in `release-chain.md` partially advanced via the `#327` Layer-11 augmentation but the broader pass remains.
- Section 3b (`cimas#49`): **closed** — all three bugs fixed.
- Section 4 (#300 Gaps): Gap 4 **implemented** (`cimas#52`). Gaps 1, 2, 3 still documented as proposed in cimas README + #300; implementation pending.
- Section 5 (hygiene): unchanged.
- Section 6 (Phase B / Trusted Publishing / stale husks): unchanged.
- Section 7 (hands-off): unchanged.

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

---

## Outcome — 2026-06-30 (late-evening sub-slot): cimas backlog triage — 2 quick-win PRs + 5 closures + 5 arc-link comments

A focused 30-minute sub-slot framed around the cimas/ci rehabilitation arc rather than checkbox-style backlog deletion. The framing — map every open ticket to its place in the arc rather than judging each in isolation — drove the split between closures, arc-link comments, and ship-now PRs. Net result: open cimas backlog shrunk from **13 → 6**, with the 6 remaining all anchored to specific roadmap items rather than floating as unprioritised 2020-era debt.

### Sub-slot PRs (both self-merged)

| # | Item | PR |
|---|---|---|
| 1 | `cimas#7` — filter token user out of reviewers (open-prs API rejected self-review and the rescue path was dropping the OTHER reviewers as a side-effect) | [`metanorma/cimas#53`](https://github.com/metanorma/cimas/pull/53) |
| 2 | `cimas#12` — gate noisy per-repo no-op log lines under `--verbose` (Skip cloning / Skipping commit / repo.branch debug print — dominated the output of any wave run regardless of `-v`) | [`metanorma/cimas#54`](https://github.com/metanorma/cimas/pull/54) |

### Closures with reasoning

| # | Reason |
|---|---|
| `cimas#7` | Closed via [`cimas#53`](https://github.com/metanorma/cimas/pull/53) |
| `cimas#8` | Parallelise git ops — deferred without active demand; serial run is ~5-10 min for 187 repos, not on critical path; future need can route through Gap 3 drift-audit's independent-per-repo scan if perf surfaces |
| `cimas#9` | Fix `lint` subcommand — superseded; no current code trace, no demand signal in 6 years; structural successor is Phase B YAML schemas + `#300` Gap 3 drift-audit |
| `cimas#10` | GitLab support — out of scope; cimas serves GitHub-hosted gems; dual-pathing every Octokit call against gitlab-ruby for zero foreseeable consumer is not on the rehabilitation arc; if a downstream needs it, sibling tool sharing cimas-config schema is cleaner than dual-pathing |
| `cimas#12` | Closed via [`cimas#54`](https://github.com/metanorma/cimas/pull/54) |
| `cimas#20` | Central code-health badges — obsolete without demand signal; in practice rubocop/lint badges handled via oss-guides, CI status via per-repo GHA, version via rubygems |
| `cimas#36` | Replace Hound with rubocop — superseded; Hound shut down in early 2025; rubocop via centralised oss-guides ruleset + per-repo GHA is the de facto org-wide implementation |

### Arc-link comments (remain open, anchored to roadmap)

| # | Roadmap anchor |
|---|---|
| `cimas#4` (files under groups key) | Phase B YAML schemas + `#300` Gap 1 (per-repo `with:` rendering schema) |
| `cimas#5` (Transition to Thor) | Subsumed by Phase B "OOP/MECE decomposition of `Cli::Command`" — framework decision deferred until decomposition is in scope |
| `cimas#13` (`approve-prs` subcommand) | Phase B decomposition; flagged scoping question (which PRs match? gated by what?) |
| `cimas#14` (`merge-prs` subcommand) | `#300` Gap 4 territory (strict-flatten path past `--supersede-stale`); Phase B decomposition; flagged scoping question (CI green? required approvals?) |
| `cimas#15` (config sanity check every time) | Phase B YAML schemas (structural sanity at load-time) + `#300` Gap 3 drift-audit (state divergence) — two-pronged "every-time" surface |

### Hands-off (per the standing scope boundary)

| # | Reason |
|---|---|
| `cimas#40` (rake.yml permissions block) | Untouched. cimas-template maintenance lane, awaiting the assigned maintainer's review |

### Net state

- **Open cimas backlog: 13 → 6** (5 arc-resident + 1 hands-off)
- **Closed today: 7** (#7 + #12 by PR-Closes; #8, #9, #10, #20, #36 by triage close-with-comment)
- **Arc-link comments: 5** giving every remaining-open ticket a roadmap pointer

### Why this matters for the rehabilitation arc

Before this sub-slot, the cimas backlog was a mix of fresh actionable items (cimas#49 just landed) and untouched 2020-era ticket debt that hadn't been triaged in 5-6 years. The mixed state meant a maintainer (or contributor) reading the issue list couldn't tell at a glance which items represented genuine current work vs unprioritised noise. After this sub-slot, **every open cimas ticket has a recent comment placing it in the rehabilitation arc** — either pointing at the Phase B refactor scope, at a specific `#300` Gap, or (for `cimas#40`) at the standing scope boundary. The backlog now mirrors the roadmap rather than being parallel to it.

### Forward-roadmap status after this sub-slot

Section 1 (#274 wave): unchanged from evening sub-slot.

Section 2 (#302 observability): unchanged — closed.

Section 3 (#309 streamlining): unchanged.

Section 3b (`cimas#49`): unchanged — closed.

Section 4 (#300 Gaps): unchanged — Gap 4 cheaper landed; Gaps 1/2/3 pending.

Section 5 (hygiene): unchanged.

Section 6 (Phase B / Trusted Publishing / stale husks): **enriched with concrete cimas backlog tickets** — Phase B now has 5 specific backlog tickets (`cimas#4`, `#5`, `#13`, `#14`, `#15`) anchored to it as future scope inputs rather than floating as separate tracks. When Phase B work starts, those tickets will be the user-side specs.

Section 7 (hands-off): unchanged.

### Sub-slot totals

- **30 minutes wall-clock**, 2 PRs + 10 comments
- Realistic time estimates honoured throughout (no PR took longer than 12 minutes from branch-cut to merge; comments batched 5-at-a-time in parallel writes + parallel posts)

🤖

---

## Outcome — 2026-07-01 (post-midnight sub-slot): ci backlog sweep — 11 closures + 3 arc-link comments + dashboard codecov question resolved

Same triage shape applied to the `metanorma/ci` ticket queue, parallel to the cimas-side sweep two hours earlier. A mid-flight intercept verified a specific claim before the closure landed: the `ci#68` coverage-badges close was about to use the generic "no convergence in 5 years" framing when the actual answer was sharper — `metanorma/dashboard` is the centralised badge surface, coverage tracking was once included via Code Climate, and every call site is now commented out (the `<%#` markers throughout `README.adoc.erb`). The convergence happened; the decision was no.

### Sub-slot closures

| # | Reason |
|---|---|
| `ci#292` | Wrapper convergence — close-out comment from 2026-06-29 actioned (scope 1 stood down 2026-06-18; scope 2 rehomed to `#302` then implemented via `#325`/`#326`/`#327`) |
| `ci#276` | tests-passed permissions cluster — close-out comment from 2026-06-29 actioned ([`#277`](https://github.com/metanorma/ci/pull/277) PAT restore merged; siblings + active callers verified aligned) |
| `ci#272` | tests-passed permissions cluster — same close-out as `#276` |
| `ci#302` | Observability triplet — fully implemented (`#325` post-publish gem verify + `#326` post-dispatch ack poll + `#327` release-chain.md doc); structural silent-fail classes now surface immediately |
| `ci#237` | fontist-setup investigation — resolved via [`#317`](https://github.com/metanorma/ci/pull/317) (Option B kept-both: `fontist-setup` + `fontist-repo-setup` complementary; wrong description fixed; documented distinction in both action.ymls) |
| `ci#210` | bundle update in flavor tests — Option A close-at-source (the script already runs `bundle update` since 2022-01-24; the failure mode is upstream-per-gem gemspec under-specification, not a CI-side script gap) |
| `ci#203` | Review cimas config for all repositories — active as continuous operational activity via the rehabilitation arc (strip waves `#319`–`#323`; structural continuations via Phase B YAML schemas + `#300` Gap 3) |
| `ci#199` | Replace Hound with rubocop — duplicate of `cimas#36` closed earlier; Hound shut down 2025, rubocop via centralised oss-guides ruleset + per-repo GHA is the de facto org-wide implementation |
| `ci#117` | Conventional commit message check — discussion never converged in 3 years; metanorma stack uses descriptive imperative commit messages without `type(scope): subject` formal shape; reopenable with concrete proposal |
| `ci#94` | Automerge PR workflow v2 — superseded by GH-native `gh pr merge --auto` flow + `cimas#45`'s auto-delete-on-merge + cimas-side `add_auto_merge_label` |
| `ci#68` | Coverage badges — **convergence happened, decision was no**: `metanorma/dashboard`'s [`README.adoc.erb`](https://github.com/metanorma/dashboard/blob/main/README.adoc.erb) emits per-gem badges for gem version, GHA workflows, PRs, commits-since — a `shield_code_climate` helper IS defined in [`erb_helper.rb`](https://github.com/metanorma/dashboard/blob/main/erb_helper.rb) but every call site is commented out (`<%#` markers throughout). Coverage tracking was tried (Code Climate, not codecov) and deliberately disabled across the matrix. Reopenable if a maintainer drives codecov-and-dashboard-re-enablement. |

### Sub-slot arc-link comments (remain open, anchored to roadmap)

| # | Roadmap anchor |
|---|---|
| `ci#197` (Ronald handle reassignment) | Section 5 hygiene's "6 *-ruby tooling repos" sweep absorbs the per-repo locations; cimas-patches mode is the centralisable vector for cimas.yml entries. **Blocked on the target handle being specified** — replacement target needs maintainer decision before sweep can run |
| `ci#186` (mn-samples `convert.yml` centralisation) | Out of current arc scope (build-system migration for sample-doc repos, not release-chain). Two paths: small canary if mn-samples maintenance is currently painful, or defer until Phase B's reusable-workflow rewriting pass absorbs |
| `ci#82` (unify native-extension workflow) | Section 5 hygiene's "6 *-ruby tooling repos needing custom edits" IS this cluster (`emf2svg-ruby`, `mn2pdf-ruby`, `mn2sts-ruby`, `mnconvert-ruby`, `mnconvert`, `sts2mn-ruby`); `#300` Gap 1's per-repo `with:` rendering is the canonical demand case. Implementation as `cimas-config/gh-actions/native-ext/` template family parallel to `master/` |

### Hands-off / already-tracked at arc level

- `ci#309` (assigned maintainer) — release-chain streamlining; partial via `#327` doc augmentation; broader pass still pending. Arc-resident
- `ci#300` (no assignee) — cimas revival design gaps; Gap 4 cheaper landed via `cimas#52`; Gaps 1/2/3 pending. Arc-resident
- `ci#278` (assigned maintainer) — patch-release breaking-change heuristic guard; deferred from earlier sub-slot. Arc-resident
- `ci#274` (opoudjis, "help wanted") — the big wave ticket; bulk done late-night 2026-06-29/30, MISSING + NOVER pending. Arc-resident

### Net state

- **Open ci backlog: 18 → 7** (4 arc-resident + 3 arc-link-commented)
- **Closed today: 11 ci issues** (the 3 early closes for #292/276/272 plus the 8 substantive closures in this sub-slot)
- **Arc-link comments: 3** giving every remaining-open older ticket a roadmap pointer

### Methodological note — verified-claim-before-close

The "verify dashboard does NOT do codecov before closing as no-convergence" intercept is the lesson from this sub-slot. Default close-comments were drafted under the framing "no convergence on coverage in 5 years" — accurate but generic. The actual answer (dashboard exists, coverage WAS once included via Code Climate, all call sites are commented out → a deliberate de-adoption) is shaper-of-future-decisions in a way the generic frame isn't. The discipline: when a closure cites "no convergence", actively look for the surface where convergence would have shown up rather than just asserting absence.

### Combined two-pass totals (cimas + ci backlog sweep)

- **PRs shipped + merged: 2** (`cimas#53`, `cimas#54`)
- **Total closures: 18** (cimas: 7; ci: 11)
- **Total arc-link comments: 8** (cimas: 5; ci: 3)
- **SSOT updates: 2 per pass** (canonical + sanitised public)
- **Open cimas + ci backlog: 31 → 13** (cimas 13→6; ci 18→7) — net **18 tickets cleared, ~60% reduction**
- **Wall-clock: ~90 minutes total** (cimas pass ~35min + ci pass ~25min + SSOT updates ~10min + intercept-and-correction ~5min)

🤖

---

## Outcome — 2026-07-01 (late post-midnight sub-slot): `#274` NOVER fix shipped — per-repo gemspec hygiene completed

Continuation of the third sub-slot's last ~40 min. Item 1.d from the forward roadmap (`#274` NOVER fix for `csa-ccm-tools/csa-ccm.gemspec`) shipped.

### PR

| # | Item | PR |
|---|---|---|
| 1 | `csa-ccm.gemspec` `required_ruby_version = ">= 3.3.0"` + `.rubocop.yml` `TargetRubyVersion: 2.5 → 3.3` | [`metanorma/csa-ccm-tools#39`](https://github.com/metanorma/csa-ccm-tools/pull/39) (merged `b4cd84b` on `master`) |

### Net effect on `#274`

- **MISSING (5 entries)** — all resolved without cimas-side action (closure comment posted in earlier sub-slot)
- **NOVER (1 entry)** — resolved via `csa-ccm-tools#39`

The 2026-06-29 dry-run preview's MISSING + NOVER set from `#274` is now fully resolved at the cimas-config + per-repo-hygiene layer. The umbrella `#274` ticket (org-wide push to Ruby 3.3) remains open as the tracking entry for any future flavour-gem-specific Ruby version bumps that surface.

### Footnote — Rubocop's `Gemspec/RequiredRubyVersion` cop catch

The fix landed with two-file scope rather than one because Rubocop's `Gemspec/RequiredRubyVersion` cop requires `required_ruby_version` (in the gemspec) and `TargetRubyVersion` (in `.rubocop.yml`'s `AllCops:`) to be equal. The `.rubocop.yml`'s `TargetRubyVersion: 2.5` was stale (Ruby 2.5 EOLed 2018-03-31) — a pattern likely present on other 2018-2020-era metanorma flavour gems where the gemspec has been bumped but `.rubocop.yml` hasn't. Worth a future audit pass when Phase B's cimas-side schema work lands: any gemspec whose `required_ruby_version` doesn't match `.rubocop.yml`'s `TargetRubyVersion` triggers a soft-warning at sync time.

### Third sub-slot grand totals

- **3 PRs shipped + merged** (cimas#53, cimas#54, csa-ccm-tools#39)
- **18 issues closed** (cimas: 7; ci: 11) + **8 arc-link comments**
- **2 SSOT updates per pass** = 4 SSOT updates total this sub-slot
- **31 → 13 open** across cimas + ci backlogs (58% reduction)
- **1 NOVER fix shipped** completing `#274`'s 2026-06-29 dry-run preview triage
- **Wall-clock: ~80 minutes total** (out of 90 min target)

🤖

---

## Outcome — 2026-07-01 (post-midnight late sub-slot continued): atmospheric strip + #300 Gap 3 acceptance criteria comment

Section 5 hygiene item: the `atmospheric` push-failed wave PR (SSOT estimate 30 min). Resolved by stripping the stale cimas.yml entry — the underlying cause was a silent transfer-out-of-org, undiscovered for ~2 months 7 days.

### The drift

`metanorma/atmospheric` was transferred out of the metanorma org on **2026-04-23T05:21:06Z** — the same day a new single-repo `atmospheris` org was created. The gem was renamed `atmospheric → atmospheris`. Live destination: `atmospheris/atmospheris` (public, active, last push 2026-04-23 itself). The cimas.yml entry continued to push-fail in every wave since with cimas reporting only "1 push-failed (atmospheric)" and no diagnostic of why.

### PR + comment

| # | Item | Surface |
|---|---|---|
| 1 | Strip atmospheric from cimas.yml, leaving a comment block with the transfer history | [`metanorma/ci#329`](https://github.com/metanorma/ci/pull/329) (merged `1727899`) |
| 2 | `#300` Gap 3 acceptance criteria comment naming the four drift failure modes (deleted, archived, transferred-out, default-branch-renamed) and the cheap API-call detection signal for each | [`#300` comment](https://github.com/metanorma/ci/issues/300#issuecomment-4844577163) |

The Gap 3 comment doubles as a concrete implementation spec — when the drift-audit subcommand work begins, the criteria + the detection-signal table + the recommended sync-block-with-override behaviour are ready to consume.

### Forward-roadmap impact

Section 5 hygiene: atmospheric resolved. The other Section 5 items (25 wave-PR creation failures, 87 permissions amend gaps, 6 *-ruby tooling repos) remain as multi-hour scope.

Section 4 `#300` Gap 3: enriched with concrete acceptance criteria from a real-world canonical case (~2 months 7 days from transfer to discovery, with cimas reporting only an undiagnosed push-fail in the interim). Implementation seam still pending Phase B's `Cli::Command` decomposition (gives drift-audit a clean structural home).

### Third sub-slot revised grand totals

- **4 PRs shipped + merged** (cimas#53, cimas#54, csa-ccm-tools#39, ci#329)
- **18 issues closed** (cimas: 7; ci: 11) + **9 arc-link/design comments** (cimas: 5; ci: 4)
- **Section 5 hygiene: atmospheric resolved** (1 of the listed Section 5 items cleared)
- **`#300` Gap 3 enriched** with implementation-ready acceptance criteria

🤖

---

## Outcome — 2026-07-01 (post-midnight late sub-slot finale): standoc + isodoc gated-release restoration + Gap 3 criterion #2

A mid-flight intercept during the Coradoc opt-out audit caught that standoc + isodoc were listed as having the "do immediate release without waiting for unit tests pass" opt-out rationale — when in fact the per-repo `release.yml` files on both repos had been moved BACK to the gated `metanorma/ci/.github/workflows/rubygems-release.yml@main` path in June 2026. The cimas.yml was missed in that pass; each subsequent wave silently skipped both repos for rake/release with no surface alarm.

### Diagnosis

- 2024-08-06 commit [`099925c`](https://github.com/metanorma/ci/commit/099925c) added the "immediate release" commented-out lines for standoc + isodoc.
- **June 2026**: per-repo `release.yml` on both was moved BACK to the gated path. Verified by direct API read of both repos' current release.yml.
- cimas.yml was missed. Each cimas-sync wave silently skipped the rake/release entries.
- Detection time from per-repo restoration to cimas.yml restoration: **~1 month**. The discovery vector: a manual audit while spec'ing Gap 3 silent-opt-out detection, which surfaced the contradiction.

### PR + comments

| # | Item | Surface |
|---|---|---|
| 1 | Restore standoc + isodoc gated-release sync entries; replace stale rationale with restoration-context comment; standoc rake.yml swapped from removed `plantuml/rake.yml` to `inkscape/rake.yml` | [`metanorma/ci#330`](https://github.com/metanorma/ci/pull/330) (merged `fccc854`) |
| 2 | `#300` Gap 3 acceptance criterion #2 (silent template opt-out detection); `#330` named as the canonical real-world case | [`#300` comment](https://github.com/metanorma/ci/issues/300#issuecomment-4844812873) |

The Gap 3 criterion comment also flagged `metanorma-plugin-glossarist`'s commented-out `.rubocop.yml` entry (no inline rationale) as unverified — could be legitimate documented opt-out OR another stale-opt-out instance; needs follow-up.

### Forward-roadmap impact

Section 5 hygiene: standoc + isodoc opt-out drift cleared in addition to atmospheric. The silent-drift pattern surfaced by this audit suggests an org-wide audit pass (when Gap 3 lands) will find more instances of the same shape.

Section 4 `#300` Gap 3: now has **two concrete acceptance criteria comments** (URL-drift + silent-opt-out) anchored to real-world canonical cases (atmospheric + ci#330). When implementation begins, the spec is ready to consume.

### Final third-sub-slot grand totals

- **5 PRs shipped + merged** (cimas#53, cimas#54, csa-ccm-tools#39, ci#329, ci#330)
- **18 issues closed** (cimas: 7; ci: 11) + **10 arc-link/design comments** (cimas: 5; ci: 5)
- **2 Section 5 hygiene items cleared** (atmospheric strip; standoc + isodoc gated-release sync restoration)
- **`#300` Gap 3 enriched with TWO concrete acceptance criteria** anchored to real-world canonical cases (atmospheric URL-drift; standoc/isodoc silent-opt-out)
- **31 → 13 open** across cimas + ci backlogs (58% reduction), all 13 arc-anchored
- **Wall-clock: ~95 minutes total** (out of 90 min target)

🤖

---

## Outcome — 2026-07-02 (evening block 1): ci#278 Option 1 shipped + glossarist rationale documented

Block 1 of a two-block session. Shipped one major structural (`ci#278`) + one small hygiene (`ci#332`).

### PRs

| # | Item | PR |
|---|---|---|
| 1 | Document glossarist `.rubocop.yml` opt-out rationale (converts unverified → verified documented opt-out per `#300` Gap 3 class) | [`metanorma/ci#332`](https://github.com/metanorma/ci/pull/332) (merged `4cb1af9`) |
| 2 | Implement `#278` Option 1 — patch-release breaking-change heuristic guard on manual `workflow_dispatch`, default-on with per-run opt-out flag | [`metanorma/ci#333`](https://github.com/metanorma/ci/pull/333) (merged `744db56`) |

### Guard design + empirical validation

Three heuristics in `.github/scripts/release-breaking-check.rb` (~230 lines):

- **(a) Deleted shipping-path files** — `git diff --diff-filter=D <prev>..HEAD -- lib/ exe/ bin/ sig/`. File-tree diff rather than gemspec eval because many gemspecs `require "./lib/…/version"` which fails under `git show`. Cost ~50 ms.
- **(d) Prism AST diff** — Ruby stdlib since 3.2; parse each `lib/**/*.rb` at prev tag AND HEAD, extract top-level module/class/def names, diff. Cost ~0.5-2 s.
- **(e) `gem-compare`** — advisory-only (rubygems outage must not itself block release). Cost ~5-15 s.

**Empirical validation against `lutaml/lutaml`**:

| From → To | Bump | Result | What caught it |
|---|---|---|---|
| v0.9.41 → v0.9.42 (**ticket's incident**) | patch | tripped | file deletion (`xmi_hash_to_uml.rb`) |
| v0.10.9 → v0.10.10 | patch | tripped | 3 method removals via Prism heuristic |
| v0.10.10 → v0.10.11 | patch | clean | — |
| v0.10.8 → v0.10.9 | patch | clean | — |
| v0.10.17 → v0.10.18 | patch | tripped | **4 file deletions** (a recurrence of the pattern the ticket describes) |

Two positives (one known + one newly-surfaced) and two negatives confirmed no false-fire.

### Heads-up posts on wrapper repos

Three issues opened notifying maintainers of behavioural change:

- [`relaton/support#54`](https://github.com/relaton/support/issues/54)
- [`lutaml/support#3`](https://github.com/lutaml/support/issues/3)
- [`fontist/support#4`](https://github.com/fontist/support/issues/4)

`plurimath/support` skipped — repo exists but has no `.github/workflows` directory (not a wrapper).

Each post names the opt-out flag (`acknowledge_breaking_in_patch`) with usage examples.

### Verified-claim-before-comment discipline check

Applied per the discipline established previously. Verified each wrapper's release.yml actually calls `metanorma/ci/rubygems-release.yml@main` before drafting posts — caught plurimath/support NOT being a wrapper, avoiding a heads-up to an unaffected repo.

### Block 1 totals

- **2 PRs shipped + merged**
- **3 heads-up issues** on relaton/support, lutaml/support, fontist/support
- **1 major ticket closed** (`ci#278`)
- **1 documented opt-out formalised** (glossarist rubocop)
- **Wall-clock ~50 min**

### Roadmap impact

Section 5 hygiene: `ci#278` closed by implementation.

Section 4 (`#300` Gap 3): glossarist contributes a small enrichment to the "documented opt-out (do not flag)" class — criterion gains a "rationale line must not be empty" sub-check.

Next up: block 2 (Gap 3 drift-audit MVP) — ~2-3 hrs at second venue.

🤖

---

## Decision — 2026-07-02 (block 1 tail): don't mass-nuke orphan cimas branches

Section 5 hygiene sweep of the 5 core flavour gems surfaced ~15-20 orphan `cimas/*` and `cimas-sync-*` branches accumulated across 2021-2026. Sample from the 5 repos:

| Repo | Total cimas-prefix branches | MERGED-PR (safe to delete) | Open PR | No PR |
|---|---|---|---|---|
| `isodoc` | 3 | 2 | 0 | 1 (from 2021) |
| `metanorma-cli` | 5 | 0 | 2 (active) | 3 (2 pre-2024, 1 recent) |
| `metanorma-standoc` | 4 | 3 | 0 | 1 (2026-06 recent) |
| `metanorma-bsi` | 5 | 4 | 0 | 1 (identical-to-main) |
| `metanorma-nist` | 4 | 3 | 0 | 1 (identical-to-main) |

Total across the 5: 21 branches. 12 have merged PRs (safe to delete mechanically). 2 have open PRs (active work, do not touch). 7 have no PR — a mix of 2021-2023 stragglers and 2026-06 wave residue that failed to open a PR (likely from the pre-`cimas#49` `-m`-as-title bug that produced HTTP 422 during wave-PR creation).

Extrapolating: possibly 200+ orphan branches across the 187-repo cimas.yml scope.

### Decision

**Do not mass-nuke the orphans.** Reasoning:

1. **None have been externally commented on.** No maintainer has raised the branch-list noise as a blocker.
2. **Risk of mass-delete misfire exceeds benefit.** A batched force-delete across 200+ branches on 187 repos has non-zero risk of catching something meaningful.
3. **`cimas cleanup-merged-prs` ([`cimas#47`](https://github.com/metanorma/cimas/pull/47)) handles the MERGED-PR class mechanically.** When we do run a cleanup pass, we run that subcommand rather than a hand-rolled loop.
4. **The wave-management surface is moving forward** via `#300` Gap 4's `--supersede-stale` and Gap 4 full's merge-prs direction. Once those mature, they naturally reduce orphan creation at the source.

### What this means going forward

- **Don't propose or execute a mass-nuke of orphan branches** unless (a) a maintainer asks, (b) a branch is actively causing a problem, or (c) `cimas cleanup-merged-prs` is being run as part of a targeted post-wave sweep.
- **Ignore old cimas branches by default.** They are inert.
- If a future audit surfaces the same finding, **link back to this decision** rather than re-litigating.

### Was the sweep still worth it?

Yes — because it also confirmed:
- **All 5 core flavour gems are current on their appropriate release template** (rubygems for isodoc/cli/standoc, github-packages for bsi/nist via `release_github_packages.yml`). The "25 wave-PR creation failures" list from the 2026-06-19 wave is substantially stale.
- **bsi/nist's cimas.yml entries correctly route to `release_github_packages.yml`** — the 2019 privatisation is fully reflected in config.
- `cimas-sync-2026-06-29` branches on bsi/nist show `vs_main=identical` — the June 29 wave produced no actual change on those repos (already at target).

Section 5 (Hygiene cleanup) status update: the 25-wave-PR-creation-failures item is likely closer to 5-10 real failures now. A future dedicated Section 5 pass should re-derive the failure list rather than trust the 2026-06-19 snapshot.

🤖

---

## Outcome — 2026-07-02 (block 1 postscript): Ronald engaged constructively on ci#332

Ronald left two review comments on [`ci#332`](https://github.com/metanorma/ci/pull/332) (the glossarist rubocop rationale doc PR) at 2026-07-02T11:33-11:34Z, providing substantive technical direction on the shape of the opt-out.

### Substance of the pushback

**Technical, not process-oriented.** The objection is to the *shape* of the merged change, not to the merge itself. Ronald's position:

- **The glossarist opt-out shouldn't exist at all.** Per-repo `.rubocop.yml` divergence is what allows staleness (outdated Ruby versions, bad-practice drift).
- **Enrich the shared master rubocop template with the plugins** (`rubocop-rspec`, `rubocop-performance`, `rubocop-rake`) — best practice belongs at the shared layer.
- **Use `.rubocop_todo.yml`** for grandfathered violations (already the metanorma-taste pattern).
- **Use inline `# rubocop:disable ...`** for repo-specific exclusions rather than top-level `Exclude:` divergence.
- **Restore the sync** — un-opt-out glossarist.

Defensible technical read; will honour.

### Immediate response

Posted [factual acknowledgement + concrete follow-up plan](https://github.com/metanorma/ci/pull/332#issuecomment-4865308614) as a comment on ci#332 — takes the point without defensive re-litigation, names a concrete PR-shape follow-up, surfaces the one open decision (Ruby-version bump path for glossarist) as a question rather than a unilateral choice.

### Follow-up work added to the queue

1. **Enrich `cimas-config/gh-actions/master/.rubocop.yml`** with the three plugins.
2. **Un-opt-out `metanorma-plugin-glossarist`** — restore sync, move divergence to `.rubocop_todo.yml` + inline guards.
3. **Revert ci#332's opt-out documentation**.
4. **Revise Gap 3 spec** — "documented opt-outs are legitimate, do not flag" is too permissive; most documented opt-outs should not exist; drift-audit should flag with context rather than accept.
5. **Ruby-version bump for glossarist** (per `#274`) — pending Ronald's response on the two paths.

### Impact on the ask-forgiveness pattern

**Confirms the pattern is workable.** Ronald does engage when he surfaces; the pattern gave him a concrete artefact to react to; he responded with substantive technical direction rather than blocking or venting.

Caveat: the substantive-technical-pushback class is real. Some ask-forgiveness merges will land as "correct direction" and stand; some will land as "wrong shape, redo" as ci#332 did. Willingness to redo constructively is part of the pattern's cost.

🤖

---

## Outcome — 2026-07-02 (block 1 extension): ci#332 follow-up phase 1 shipped + phase 2 filed for @kwkwan

Ronald's feedback on `ci#332` translated into concrete PRs and issues within the same session.

### PR + issue

| # | Item | Surface |
|---|---|---|
| 1 | Master rubocop template enrichment — added `plugins:` (rubocop-rspec, rubocop-performance, rubocop-rake) + `TargetRubyVersion: 3.4 → 3.3` to align with `#274` | [`metanorma/ci#334`](https://github.com/metanorma/ci/pull/334) (merged `b4ba333`) |
| 2 | Follow-up issue for @kwkwan (glossarist un-opt-out walk-through: inline-guards migration + gemspec Ruby bump + regenerate `.rubocop_todo.yml`) | [`metanorma/metanorma-plugin-glossarist#78`](https://github.com/metanorma/metanorma-plugin-glossarist/issues/78) |
| 3 | Status comment on ci#332 documenting phase 1 shipped + phase 2 filed + phase 3 (revert ci#332 rationale) queued for after phase 2 lands + Gap 3 spec revision noted | [ci#332 comment](https://github.com/metanorma/ci/pull/332#issuecomment-4865402434) |

### The "can't guess business motivations" limitation

Concrete implication for `#300` Gap 3 spec: the "documented opt-out" class is a **flag with context**, not a **skip class**. Automated drift-audit catches structural mismatches but can't infer *business* motivations behind opt-outs — the maintainer's business context ("customer policy," "in-flight private fork," "data-source dependency," etc.) is not derivable from live-vs-template config comparison. Drift-audit surfaces the opt-out + rationale + a human-review gate; the maintainer decides "still valid" or "resolve." Machine can't decide autonomously.

Will fold this into the Gap 3 spec revision after phase 3 (ci#332 rationale revert) lands.

### Ask-forgiveness pattern calibration update

**Confirmed workable + reveals the substantive-pushback response norm.** Ronald engages when he surfaces; his pushback is technical (not process-oriented); the follow-up expectation is a concrete PR + status update, not defensive re-litigation. The extra cost of the pattern is one "wrong-shape landing → follow-up sequence" event per ~5-10 substantive unilateral merges — acceptable given the alternative is 9+ months of ticket-aging.

### Block 1 revised totals

- **3 PRs shipped + merged** (ci#332, ci#333, **ci#334**)
- **1 issue filed for external maintainer** (metanorma-plugin-glossarist#78)
- **3 heads-up issues** on relaton/support, lutaml/support, fontist/support (from earlier)
- **1 orphan-branch decision recorded** (don't nuke)
- **~6 SSOT updates**
- **Wall-clock: ~85 min**

Next up: block 2 at second venue (Gap 3 MVP, ~2-3 hrs).

🤖

---

## Outcome — 2026-07-02 (block 1 postscript 2): PR-review rubric memory persistence

Downstream of Ronald's engagement on ci#332 — durable behavioural change wired into the cross-session AI operating rules.

### The rubric

Ronald forwarded his own PR-review rubric for opoudjis to use on extraneous-contributor PRs opoudjis has been called to review:

> Investigate our (branch and/or PR and/or unstaged code) that is contributed and supposed to be a great enhancement on our work. The contributor can easily devolve into hacks or unclean architecture because the contributor may not understand the high-level strict architecture we have. Ensure code cleanliness and OOP and MECE and fully model-driven and open/closed principle, DRY, performance. ultrathink. What else can we improve here in architecture and code? Make sure we have good specs thought out. Do an audit.

opoudjis framed it as a reasonable starting point for extraneous PRs, with the maintainer retaining ad-hoc override authority on any specific PR.

### Persistence wiring

Trigger-stub form (not always-on inline) — the rubric fires only when explicitly asked to review an extraneous PR, so autoloading the full text every session would waste context.

- Canonical memory file: `~/.claude/memory/feedback_pr_review_ronald_rubric.md`
- Instruction trigger stub: `~/.claude/instructions/pr-review-ronald-rubric.md`
- `@`-included in `~/.claude/CLAUDE.md` under the GitHub-behaviour block

### Scope

**Applies to**: extraneous-contributor PRs (external contributor, non-trivial change, called on to review). Audit report goes to opoudjis first, never direct PR comment without explicit approval.

**Does NOT apply to**: own PRs (cimas/ci rehabilitation work), team-internal PRs from established maintainers, trivial PRs (dep bumps, typos, single-liners), bulk auto-generated PRs (cimas-sync, dependabot). For those cases the SPIRIT of the rubric applies (cleanliness, DRY, tests) as light checks — not the full audit shape.

### Companion relationship

Cross-linked with the 2026-06-16 companion memory covering Ronald's code-style prompt (write-side, applies when writing code for Ronald-managed repos: cimas, ci, oss-guides). Same principles, different triggers — one for authoring, one for reviewing.

### Meta-observation on the arc

Ronald engaging on ci#332 → substantive technical feedback → phase 1 shipped (ci#334) → phase 2 filed for @kwkwan (glossarist#78) → phase 3+4 queued → Gap 3 spec sharpened → **AND** durable operating-rule update baked into memory. One engagement event, one turn of the follow-up sequence, and the arc's default AI behaviour is upgraded for all future extraneous-PR reviews. That's the compounding shape of ask-forgiveness done well: each engagement doesn't just close one ticket, it strengthens the pattern.

🤖

---

## Outcome — 2026-07-02/03 (block 2): Gap 3 drift-audit MVP shipped + 12/13 findings actioned

Block 2 target — the `#300` Gap 3 drift-audit MVP scanner — shipped in ~35 min, followed by immediate action on the findings it surfaced.

### Shipped

| # | Item | Surface |
|---|---|---|
| 1 | **Drift-audit MVP scanner** — 556-line Ruby script implementing 7 failure-mode classes (a/b/c-external/c-internal/d/e.2/e.3). Standalone script under `.github/scripts/cimas-drift-audit.rb`; integration as cimas subcommand is Phase B territory. | [`metanorma/ci#335`](https://github.com/metanorma/ci/pull/335) (merged `29e8add`) |
| 2 | **First real audit report** posted on `#300` — 156 of 170 clean, 9 errors, 4 warnings, 1 flag | [`#300` comment](https://github.com/metanorma/ci/issues/300#issuecomment-4866395661) |
| 3 | **8 external transfers stripped** (edoxen, emf2svg-ruby, iev, oscal-ruby, pdfa-iso-32000-2, reeper, vectory, xml-c14n) — each was in a different org after transfer; cimas.yml was silently push-failing. | [`metanorma/ci#336`](https://github.com/metanorma/ci/pull/336) (merged `59cc642`) |
| 4 | **4 stale-duplicate internal renames stripped** (metanorma-model-m3d, metanorma-model-rsd, mn-samples-mlit, metanorma-ietf-data) — investigation revealed each was a duplicate whose destination already existed in cimas.yml with correct config. Also stripped 3 stale group-membership references. | [`metanorma/ci#337`](https://github.com/metanorma/ci/pull/337) (merged `88ea99b`) |

### Empirical validation of the tool

**Class (c) split validated by empirics.** The Gap 3 spec called out (c) as one class. First-run findings showed BOTH shapes needed different severity: 8 external transfers (error) and 4 internal renames (warning). Split baked into the tool + confirmed by the follow-up PRs where the two classes needed different corrective actions.

**Same-day loop validated.** Audit → strip PR → re-audit → confirmed. Went from 13 findings → 5 → 1 in three PR shipping cycles within ~1 hour.

**Zero silent-drift (e.2) findings across 170 repos.** Independent validation that recent hygiene passes have kept the config-vs-live-state actually aligned.

### Deferrals

MVP explicit deferrals: (e.1) stale-rationale heuristic, coradoc-shape narrative opt-outs, affirm-action mechanism, integration as cimas subcommand (Phase B), automated test suite.

### Remaining unactioned finding

- **`iso-10303` (class d)**: default branch is `mn/main` (not `main`). Unusual — probably deliberate. Deferred pending maintainer confirmation.

### Block 2 grand totals

- **4 PRs shipped + merged**
- **1 comment attaching real audit report** to `#300`
- **12 real drift findings actioned** (of 13 surfaced by the audit)
- **~66 min wall-clock** out of ~2h block budget

Post-block-2 cimas.yml state is the cleanest since the rehabilitation arc began. Future waves' "N failed" reports will now correspond to legitimate current-state issues, not accumulated stale-config noise.

🤖

---

## Outcome — 2026-07-03 (block 2 extension): drift-audit MVP → v1 with (e.1) + coradoc-shape

Extension pass following block 2's MVP + strip work. Both explicit MVP deferrals resolved in a focused ~55 min pass.

### Shipped

| # | Item | Surface |
|---|---|---|
| 1 | **(e.1) stale-rationale detection** — for glossarist-shape opt-outs, compare live file vs referenced template; if they match, the rationale is contradicted by live state → error (e.1). | [`metanorma/ci#338`](https://github.com/metanorma/ci/pull/338) (merged `45fc74a`) |
| 2 | **Coradoc-shape narrative opt-outs** — parser extension emitting OptOut for rationale comment blocks in `files:` sections that mention filenames but lack a commented-out file mapping. False-positive filter rejects narrative opt-outs whose mentioned file is already synced. | same PR |

### The 7-class spec is now fully implemented end-to-end

Every failure-mode class from the sharpened Gap 3 spec is detected:

| Class | Detection | Severity |
|---|---|---|
| (a) repo deleted | 404 on API probe | error |
| (b) repo archived | `.archived == true` | warning |
| (c-external) external transfer | `.full_name` org differs | error |
| (c-internal) internal rename | `.full_name` name differs, org same | warning |
| (d) branch drift | `.default_branch` differs from cimas.yml | error |
| (e.1) stale-rationale | live file matches template referenced in opt-out | error |
| (e.2) silent template drift | live file differs from claimed-synced template | warning |
| (e.3) documented opt-out | valid or unverifiable rationale (glossarist or coradoc shape) | flag |

### Empirical validation

- **coradoc** newly surfaces as `(e.3)` narrative-shape ✓
- **glossarist** stays as `(e.3)` (live file differs from template — correctly classified as real opt-out) ✓
- **standoc + isodoc** correctly filtered (restoration comments about actively-synced files) ✓
- **Zero `(e.1)` findings** on current cimas.yml — validates that recent hygiene passes have kept documented opt-outs honest

### The standoc/isodoc conceptual validation

The `(e.1)` detector's canonical test case is the standoc/isodoc drift from 2026-07-01 (`ci#330`). Would have surfaced immediately as `(e.1) error` instead of waiting for a manual audit ~1 month later. That's the tool's structural value proposition made concrete.

### Block 2 revised grand totals

- **5 PRs shipped + merged** across block 2 (MVP scanner + 8-strip + 4-dedupe + extensions + audit-report comment)
- **12 real drift findings actioned** in same-session detect-and-act loop
- **Full 7-class spec implemented end-to-end**
- **~85 min wall-clock** of the ~2h block budget

### The compounding effect

The audit went from proposal → MVP → shipped + actioning findings → full 7-class end-to-end implementation in a single ~2h block. Tool-mediated maintenance: a spec turns into a scanner turns into cleanup turns into a permanent hygiene mechanism.

🤖

---

## Outcome — 2026-07-04 (evening block, first ~1 hr): #300 Gap 3 close-out + scheduled drift-audit end-to-end + Gap 1 mechanism shipped

Third weekend evening block. Sequence: Gap 3 close-out, scheduled drift-audit, Gap 1. Total ~65 min for what was estimated 6-7 hrs.

### Shipped

| # | Item | Surface |
|---|---|---|
| 1 | **`#300` Gap 3 close-out comment** — full 7-class spec substantially done via ci#335+#338; deferrals enumerated | [`#300` comment `4881516777`](https://github.com/metanorma/ci/issues/300#issuecomment-4881516777) |
| 2 | **Scheduled drift-audit parent ticket** for accountability | [`ci#340`](https://github.com/metanorma/ci/issues/340) |
| 3 | **Scheduled drift-audit workflow** — weekly Wed 09:00 UTC + workflow_dispatch, PAT for private-repo visibility, tracking-issue-per-label with auto-updated body + comment log | [`ci#341`](https://github.com/metanorma/ci/pull/341) (merged `8801d37`) |
| 4 | **Auto-created tracking issue** for rolling drift reports | [`ci#342`](https://github.com/metanorma/ci/issues/342) |
| 5 | **First scheduled-audit finding actioned** — `DGGS2ISO-19170` stripped (class-a deleted repo) | [`ci#343`](https://github.com/metanorma/ci/pull/343) (merged `7fdc9df`) |
| 6 | **cimas Gap 1 mechanism** — per-repo `with:` block schema + ERB `with_values` wire-up + 8 focused specs | [`cimas#55`](https://github.com/metanorma/cimas/pull/55) (merged `c2ce12c`) |

### Gap 1 mechanism notes

cimas already had `.erb` rendering + a per-repo `template: binding:` hash. Gap 1 added a top-level `with:` key exposed as `with_values` in ERB. Both mechanisms coexist. Bug fix bonus: `Hash#dig` block form silently ignored, returning nil when absent; changed to `|| {}` for type stability.

Deferred per "prove the mechanism, migrate at leisure":
- Parametric `master/rake.yml.erb` template.
- Real `metanorma` repo migration with `with: private-fonts: true`.
- README doc update.

### Scheduled drift-audit detect-and-act loop demonstrated

Within ~35 min of `ci#341` merging: manual dispatch → surfaced false positives (fixed with PAT) → surfaced 2 real errors → actioned 1 via `ci#343`. Next scheduled run (Wed 09:00 UTC) confirms clean state.

### Time calibration

Gap 1 estimated at 4-5 hrs; actual ~22 min. Same 5:1 overestimation ratio as the drift-audit MVP. Systematic pattern; roadmap estimates for script-based / cimas-mechanism changes should be divided by ~5 for actual work of this shape.

### Block totals (so far)

- **5 PRs merged**, **2 issues filed**, **1 comment**
- **~65 min wall-clock** of the 5-hr slot; ~4 hrs buffer

Next: Gap 4 full.

🤖

---

## Outcome — 2026-07-04 (evening block continued): Gap 1 migration + two critical drift-audit bug fixes

Continuation of the earlier weekend evening block. After Gap 3 close-out + scheduled drift-audit + cimas#55 mechanism (~65 min), the actual Gap 1 migration shipped alongside two critical bug fixes surfaced by the migration work.

### Shipped

| # | Item | Surface |
|---|---|---|
| 7 | **Gap 1 migration** — new parametric `master/rake.yml.erb` template (superset of `inkscape/rake.yml`, byte-identical with empty `with_values`); 3 consumers migrated (metanorma with `with: private-fonts: true`, metanorma-standoc, isodoc); bundled with drift-audit `read_template` path bug fix | [`metanorma/ci#344`](https://github.com/metanorma/ci/pull/344) (merged `90d8107`) |
| 8 | **drift-audit `.erb` rendering bug fix** — was comparing live files against RAW ERB source (with unrendered `<%= ... %>` tags), producing false-positive (e.2) findings for every `.erb` consumer. Now renders templates using cimas#55's `with_values` shape before comparison | [`metanorma/ci#345`](https://github.com/metanorma/ci/pull/345) (merged `6a64c63`) |

### Two critical drift-audit bugs discovered + fixed

Both surfaced by empirical work in this block. Both were causing (e.2) silent-drift detection to under-report drift silently since the tool shipped:

- **Bug 1**: `read_template` path double-`gh-actions/` — silent nil return, all (e.2) findings suppressed. Fixed in ci#344.
- **Bug 2**: `.erb` templates not rendered before comparison — every `.erb` consumer would show false-positive DIFF. Fixed in ci#345.

**Meta-observation**: the scheduled workflow's compounding value is now clear beyond maintenance. It's also an ongoing correctness check on the tool itself. Bug 1 was surfaced immediately by the first live workflow run (24 false-positive class-a from PAT scope); Bug 2 came from the Gap 1 migration adding first-of-kind `.erb` consumers.

### Empirical state (post both fixes)

Full audit against `cimas.yml` (157 entries):

- **1 error** (class d): `iso-10303` `mn/main` branch drift (deferred)
- **242 warnings** (class e.2): legitimate accumulated silent template drift — 55 rubocop, 58 docker, 42 generate, 21 rake, 19 test, 16 release. Needs a maintainer-driven cimas-sync wave.
- **2 flags** (class e.3): coradoc + glossarist (expected)

### Block totals (evening slot cumulative)

- **8 PRs shipped + merged** across the block
- **2 issues filed** (ci#340, ci#342)
- **1 comment** (`#300` Gap 3 close-out)
- **2 critical bug fixes** on drift-audit
- **~2h20m wall-clock** of the 5-hr slot

### Compounding value

The pattern "ship the tool → run it → surface bugs → fix immediately" is turning drift-audit into a reliable maintenance surface faster than any test suite would.

🤖

---

## Outcome — 2026-07-04 (evening block finale): Gap 4 full shipped via cimas#56

Final ~1 hr chunk of the weekend evening slot. Gap 4 full shipped.

### Shipped

| # | Item | Surface |
|---|---|---|
| 9 | **Gap 4 full — `--flatten-stale`** — extends `cimas#52`'s `--supersede-stale` with auto-close of superseded PRs. Implies supersede-stale at CLI-flag time (setting `--flatten-stale` alone activates detection + label + comment + close). Refactors: `handle_superseded_pr` + `supersede_comment_body` helpers. README section added alongside the existing `--supersede-stale` doc. | [`cimas#56`](https://github.com/metanorma/cimas/pull/56) (merged `b35fc55`) |

### Design decisions

- **Wave-regeneration invariant assumed** — every cimas-sync wave regenerates the same file set from cimas.yml, so newer waves strictly supersede older by construction. Lets `--flatten-stale` skip the strict-superset diff gate.
- **`--supersede-stale` preserved as safer path** for cases where the invariant breaks.
- **Comment body factored out** so both modes go through the same shape.

### `#300` gaps status (post-tonight)

| Gap | Status |
|---|---|
| Gap 1 (per-repo `with:` rendering) | ✅ Mechanism + first migrations shipped |
| Gap 2 (monorepo sub-template family) | ⏸ Untouched |
| Gap 3 (drift-audit) | ✅ Full 7-class spec + scheduled workflow |
| Gap 4 (cheaper) | ✅ Shipped 2026-06-30 |
| Gap 4 (full) | ✅ Shipped tonight |

Only Gap 2 remains from the `#300` roadmap.

### Cumulative evening block totals

- **9 PRs shipped + merged** across three chunks
- **3 issues filed** (ci#340 parent, ci#342 tracking, plus earlier work)
- **3 substantive comments**
- **3 critical bug fixes discovered + fixed via empirical use**
- **~3h45m wall-clock** of the 5-hr slot

🤖

---

## Outcome — 2026-07-05 (post-midnight ~15 min): #300 Gap 2 shipped + all gaps now closed end-to-end

Post-break resumption. Gap 2 shipped in ~15 min.

### Shipped

| # | Item | Surface |
|---|---|---|
| 10 | **`#300` Gap 2 — monorepo-per-gem template family** — new shared reusable `metanorma/ci/.github/workflows/monorepo-per-gem-rake.yml` (promoted from pubid's local fork, byte-identical); new cimas template `cimas-config/gh-actions/monorepo/rake.yml.erb`; re-add `pubid` to cimas.yml resolving the PENDING-READD block | [`metanorma/ci#346`](https://github.com/metanorma/ci/pull/346) (merged `ae6ec51`) |

### Design decisions

- **Named for the pattern, not the consumer** — `monorepo-per-gem` (each gem has its own Gemfile) distinguishes from existing `monorepo-rake.yml` (shared Gemfile). Pattern-name survives if pubid renamed.
- **Promoted local fork to shared reusable** rather than enriching the existing shared `generic-rake.yml` — investigation showed pubid's local adds monorepo/gem_directory/gem_name but LACKS the metanorma-flavour features (submodules, setup-tools, private-fonts, choco-cache) that shared generic-rake carries. Folding would bloat both consumers.
- **7 optional `with:` inputs** in the cimas template matching monorepo-per-gem-rake.yml's input surface.

### `#300` all gaps closed end-to-end

| Gap | Status | Shipped |
|---|---|---|
| Gap 1 | ✅ | cimas#55, ci#344 |
| Gap 2 | ✅ | ci#346 (this) |
| Gap 3 | ✅ | ci#335, #338, #341, #344, #345 |
| Gap 4 (cheaper) | ✅ | cimas#52 |
| Gap 4 (full) | ✅ | cimas#56 |

The cimas rehabilitation roadmap's `#300` chapter is done. Next: run the sweep to clear the 242 accumulated drift findings.

🤖

---

## Outcome — 2026-07-05 ~02:00-03:00: sweep wave shipped end-to-end + three cimas correctness bugs surfaced + fixed

The full org-wide cimas-sync wave shipped, with `--flatten-stale` (Gap 4 full) as its wave-management mode. Sync + push + open-prs surfaced three distinct cimas correctness bugs that had never been exercised on real data before this sweep; each was fixed in-flight.

### Bugs surfaced + fixed

1. **`cimas#57`** ✅ — sync's `ERB.new(File.read(source_path))` didn't pass `trim_mode: '-'`, so the new `master/rake.yml.erb` and `monorepo/rake.yml.erb` templates from Gap 1/Gap 2 that use `<%- ... -%>` trim markers failed to parse. One-line fix, backward-compatible.
2. **`cimas#58`** ✅ — `pngcheck-ruby` uses `files: []` in cimas.yml (an intentionally-empty Array meaning "track the repo but don't touch any file"), but `Cli::Command#push` called `g.add(repo.files.keys)` on the raw Array. Fix: normalise `files: []` to an empty Hash at `Repository#init_from_attributes` time.
3. **`cimas#60`** ✅ — three `options[...]` references inside `Cli::Command#open_prs` (lines 487, 560, 602) where the accessor pattern is `config[...]`; plus a UTF-8 encoding bug on `File.read` of the `--body-file` argument that choked JSON encoding on non-ASCII bytes. Both were unreachable until `--body-file` / `--flatten-stale` were exercised on real data.

### The sweep outcome

- **Sync**: 158 repos, 0 errors, 21 expected patch warnings.
- **Push**: 156/158 force-pushed (2 permission-denied on OGC external repos — those fall to their own maintainers). 151 fresh commits made.
- **Open-PRs with `--flatten-stale`**: 148 wave PRs opened; 30 prior stale `cimas-sync-*` PRs auto-closed as superseded across the org. Steady-state open-PR count on the org is now lower than before the wave.

### Design gotcha named

Push consumes sync's staged working-tree state, so if push fails partway through and is re-run without a fresh sync, files staged on the first push's now-deleted sync branch are lost. Workaround: always run `cimas sync` before each `cimas push` attempt. Fuller fix (self-heal or refuse-with-instruction) queued as a follow-up.

### `#300` all gaps still closed end-to-end (unchanged)

The sweep is the first end-to-end exercise of the full `#300`-shaped tool loop on real data.

🤖

---

## Outcome — 2026-07-05 ~14:00-16:00: ci#347 course-correction (docker-only for doc repos + iso-10303 drop)

[`metanorma/ci#347`](https://github.com/metanorma/ci/issues/347) filed by @ronaldtse ~6 hours after the sweep completed, with three concrete architectural corrections needed on cimas.yml.

### Three asks

1. **Delete `iso-10303`** from cimas. (Was already flagged as awaiting confirmation — its default branch is `mn/main`, not `main`; now confirmed to remove from cimas altogether.)
2. **Document repos: only `docker.yml`, never `generate.yml`, except `mn-samples-*`.** Architectural principle: `docker.yml` runs the shipping/container path via `metanorma/metanorma:latest`; `generate.yml` runs the native gem-install path. Only sample repos are meant to smoke-test the gem-install path; real doc repos should exercise the shipping path only.
3. **Private-docs: strip the deployment step.**

### Remediation shipped

- **cimas.yml corrected** on `metanorma/ci` main directly (commit `949efb2`): iso-10303 repo entry + iso-group line removed; 26 doc repos had their `.github/workflows/generate.yml` mapping deleted; 6 doc repos had `generate.yml` renamed to `docker.yml` (they had only that one workflow, so renaming preserves a workflow file). Total 44 lines removed. Rule applied: `.github/workflows/generate.yml` is permitted only on repos named `mn-samples-*`.
- **Template starter files preserved** — `common/`, `templates/`, `default/` paths under `mn-templates-*` + `metanorma-cli` are downstream user-project scaffolds, not repo-own-CI; untouched.
- **Item 3 verified already met** — private-docs group members all map to `private-docker.yml.erb` or `private-fonts.yml.erb`, neither of which has a deploy step. Confirmed on live `mn-samples-bsi/.github/workflows/docker.yml` (build job only).
- **40 doc-repo wave PRs handled** — 31 closed with `--delete-branch` (addresses both the mailbox burst grievance AND the follow-up complaint about orphaned branches); 9 had already merged before the close-loop reached them (their `generate.yml` is now landed in-repo and needs a follow-up delete).
- **CI-failure claim spot-checked**: across the 39 doc-repo wave PRs (excluding one that couldn't be inspected), 24 (~61%) had failing CI checks — dominated by `generate.yml` native-gem-install failures on repos not set up to build native gems. 15 (~39%) passed. Validates the docker-only architectural rule as the right correction, not just a peace offering.
- **cimas#60 shipped** — `options[...]` → `config[...]` + UTF-8 encoding fixes, surfaced by the running open-prs invocation and fixed in-flight.

### Follow-ups queued

- **Delete existing `generate.yml` files** from the ~30 doc repos that had them, plus the 9 where the wave PR merged before we could close it. cimas.yml stops future regeneration but does not delete existing files from target repos. Either a targeted manual PR wave or a cimas file-removal feature.
- **`cimas cleanup-closed-prs`** — extend `cimas cleanup-merged-prs` (or add sibling) to also delete branches of closed-not-merged PRs. `--delete-branch` on the bulk close addressed today's 31 branches directly, but a systematic subcommand is a small follow-up.
- **Notification-suppression at GitHub sender side is not feasible** — GH notifies all watchers on PR creation with no per-PR / per-author / per-branch-pattern API knob. Only client-side mitigations exist (subject-based Gmail filters, `Ignore` in watching config). Documented in the ci#347 reply.
- **Wave cadence discipline going forward**: cimas blasts at most fortnightly, aligned with the fortnightly release cadence; `--flatten-stale` as the default mode on all waves (not just current-test invocations); the scheduled Wed 09:00 UTC drift-audit as the quiet-visibility mechanism between waves.

### `#300` gaps unchanged

ci#347 is orthogonal to the `#300` roadmap; all gaps remain closed end-to-end.

🤖

---

## Outcome — 2026-07-05 ~16:00-21:30: cleanup subcommands + failed-PR sweep + org-wide cleanup wave

Post-ci#347 continuation block. Two new cimas subcommands shipped, the KEEP-list wave-PR failure inventory categorized + selectively fixed, and the ci#347-driven orphan `generate.yml` cleanup wave rolled out.

### Two new cimas subcommands

- **[`cimas#61`](https://github.com/metanorma/cimas/pull/61)** ✅ — added `cleanup-orphan-files` (inverse of sync; walks each repo, detects files with the Cimas auto-generated header comment that are no longer in the repo's `files:` mapping, and deletes them) + `cleanup-closed-prs` (sibling of `cleanup-merged-prs` for the closed-not-merged case; sweeps all `cimas-sync-*`-prefixed branches whose PR was closed without merge and deletes the remote branches). 5 new specs covering the orphan-detection helper (header match, mapping filter, `.git/` skip, clean-repo, binary-file tolerance).
- **[`cimas#62`](https://github.com/metanorma/cimas/pull/62)** ✅ — follow-up on cimas#61 after running it against the org for real: (a) nil-guard on `File.read` return for empty files / dangling symlinks; (b) `--only-target=PATH1,PATH2,...` to scope the orphan sweep to specific target paths, so a wave stays focused on one class of orphan and doesn't also pull in unrelated historical drift the broader scan surfaces; (c) `push_to_branch` / `pr_message` are now only resolved when `--push-after` needs them, so the local-only dry-run mode works without `-b`.

### cimas.yml archive-out corrections

- **metanorma-gb removed** (`metanorma/ci:8c35bef`) — was still being swept despite being in the `ignore: obsolete` group tag (the tag is documentation-only; only the absence of a `repositories:` entry actually excludes a repo). Wave PR #166 got opened on it in the sweep.
- **lapidist removed** (`metanorma/ci:ad46643`) — confirmed defunct (last human commit 2021-05-29; all subsequent activity is cimas/mn-requirements automation). Removed from `repositories:` and the `infrastructure` group. Wave PR #29 closed with branch deleted.

### Failed-PR inventory across the KEEP-list

Scanned all 105 KEEP-list wave PRs (gem/tool/model/style/site/infra shape); **17/109 rake failures** (~16%; residual after the ci#347 doc-repo split — down substantially from the 61% doc-repo baseline).

**Categorized:**

- **Merged despite failing CI** — 3 PRs (metanorma-ieee#753, metanorma-gb#166, metanorma-itu#801). Governance question left to maintainer.
- **Actively-maintained (leave to maintainer)** — 4 PRs: rfcxml#32, niso-jats#34, suma#102, sts-ruby#35. Each of these has active commits from the maintainer in 2026-04→2026-07; the wave PR CI failure is a snapshot in the middle of in-flight work.
- **Maintainer-owned drift (already-triaged)** — 2 PRs: plantuml#56 (owner: @kwkwan), metanorma-document#26 (under-development).
- **Fixable-by-us and shipped** — 6 PRs (see the fixes table below).
- **GHA scheduling anomaly (not code)** — 1 PR: reverse_adoc#101. Test-matrix jobs stuck in `pending` state; not a code fix. Leave to a re-run trigger.

### Six fixable-by-us fixes shipped

| Repo | Fix | Commit |
|---|---|---|
| cnccs | Orphan `.github/workflows/rake.yml` (Cimas-header, not in mapping — ancient Ruby 2.4-2.7 matrix) nuked. cnccs is a data-only repo, no gem release path. | `metanorma/cnccs:cff277a` |
| plantuml | Bot PRs #52 (PlantUML 1.2026.4) + #53 (1.2026.5) closed as superseded by #54 (1.2026.6, current) — collapses the stalled bump-PR chain | PRs closed, branches deleted |
| ietf-data-importer | Spec assertion `expect(VERSION).to eq("0.3.0")` was stale (version.rb now says 0.3.1). Swapped for semver-shape regex — coverage without self-invalidation on future bumps. | `metanorma/ietf-data-importer:5d9c024` |
| csa-ccm-tools | Gemspec `bundler "~> 2.0"` collided with modern bundler (4.x); relaxed to `>= 2.0`. Also stripped `pry` + `pry-coolline` from Gemfile (debug tools that leaked in). | `metanorma/csa-ccm-tools:1b01fa0` |
| cimas | `apply_patches` spec expected `/pattern did not match/` but impl says `pattern not present in file`; drift from an earlier warning refinement. Wave PR #59 also closed as stale. | `metanorma/cimas:aec1544` |
| metanorma-registry | activesupport 5.2 requires `mutex_m` + `bigdecimal`, both removed from Ruby 3.4+ stdlib default gems. Added both to Gemfile explicitly (avoiding the 5→7 major-version bump). | `metanorma/metanorma-registry:ce3ecb7` |
| bipm-data-importer | coradoc 2.0 dropped the entire `input/` tree including `input/html.rb`, which `common.rb` requires. Pinned coradoc to `~> 1.1` as stopgap; filed [`bipm-data-importer#59`](https://github.com/metanorma/bipm-data-importer/issues/59) assigned to @ronaldtse documenting the breakage + real-fix scope (port to coradoc 2.x API). | `metanorma/bipm-data-importer:f44620d` + issue |

### The ci#347 orphan `generate.yml` cleanup wave

Using the new `cimas cleanup-orphan-files --only-target=.github/workflows/generate.yml --push-after`, walked all 158 cimas-managed repos + purged orphan `generate.yml` from doc repos. **26 branches force-pushed** across `cleanup-orphans-2026-07-05` (26 doc repos with the orphan; 129 clean; 0 errors). Then `cimas open-prs --flatten-stale` opens the wave PRs.

### Design decision (worth naming)

The `--only-target` scope filter emerged from running the broader `cleanup-orphan-files` and discovering unexpected historical drift — `.hound.yml` on many gem repos, `notify.yml` on metanorma-cli + metanorma, `rake.yml` on flavour gems that don't map rake.yml anymore. Those are all real orphans, but they're outside ci#347's scope, and blast-including them into a "docker-only cleanup" wave would introduce unwanted noise. Scoping the filter is what makes cimas usable as a scoped-cleanup tool rather than a bulldozer. The broader-drift finding is worth surfacing separately — it's a follow-up wave that can be triggered at any point.

### Cumulative arc totals (updated end-of-day 2026-07-05)

- **`#300` roadmap**: 10 PRs + all 4 gaps closed end-to-end (unchanged)
- **cimas correctness fixes**: cimas#57, #58, #60, #61, #62 all merged; [cimas#63](https://github.com/metanorma/cimas/issues/63) filed (push-precondition follow-up); cimas#15 closed with arc-link comment (drift-audit substantially delivered its intent).
- **ci#347 remediation**: cimas.yml corrected + 40 doc-repo wave PRs handled + cimas#60 shipped
- **This session's failed-PR fixes**: **8 non-doc-repo fixes shipped** — cnccs (orphan rake.yml), ietf-data-importer (VERSION spec semver-regex), csa-ccm-tools (bundler + pry), cimas spec drift, metanorma-registry (mutex_m + bigdecimal), bipm-data-importer (coradoc pin + issue #59), **sts-ruby (rubocop-drift todo regen `4f61060`)**, **suma (rubocop-drift todo regen `548e996`, dropped 193 stale exclusions in the process)** + 2 cimas.yml archive-outs (gb, lapidist) + 1 issue filed
- **Cleanup wave**: 26 doc repos got fresh `cleanup-orphans-2026-07-05` PRs. **18/26 merged by session end**; 8 open failing on pre-existing docker.yml `build` errors or CodeQL Analyze issues (per-repo maintainer investigation, not template drift).
- **False-alarm findings**: rfcxml #32 and niso-jats #34 rubocop failures are runner-environment-specific (local rubocop passes clean; todo files already cover the plugin-drift offenses on those two). CI retries should resolve without code changes.
- **Rubocop-drift pattern captured** for future waves: after ci#334 enriched `master/.rubocop.yml` with `rubocop-rspec` / `rubocop-performance` / `rubocop-rake` plugins (per Ronald's explicit ask on ci#332), gems whose `.rubocop_todo.yml` predates that landing carry stale exclusion sets. Recipe: `bundle exec rubocop --regenerate-todo && bundle exec rubocop`.

### Broader-drift cleanup wave prepped for 2026-07-06 post-release

Broader `cleanup-orphan-files` catalog generated tonight (no `--only-target`): 89 orphan repos, ~130 orphan files across 20+ file types. Turnkey `--only-target=.hound.yml,rake.yml,notify.yml,integration.yml,test.yml` invocation prepared in the pickup file. Deferred until Monday to avoid double-blasting the mailbox alongside tonight's wave. Deliberately excluded: template scaffolds (`common/` prefix), niche `docker-pres_xml.yml`, long tail (need per-instance investigation).

🤖

---

## Outcome — 2026-07-06 ~12:20: ci#347 reopened for private-vs-public visibility-driven treatment

@ronaldtse posted two follow-up asks on the reopened [ci#347](https://github.com/metanorma/ci/issues/347):

> "Regarding keeping a list of private repos: it should be determined by the repository visibility on the GitHub repository itself."
>
> "We need to also distinguish between public document repos vs private document repos."

Both point at the same design gap: cimas.yml's manual `private-docs` group has drifted from actual GitHub visibility, and the public/private axis should be a systematic property picked up at sync time from GitHub's own `.private` flag, not a hand-curated list.

### Audit against actual GitHub visibility (as of 2026-07-06)

- **1 misclassified as private**: `mn-samples-ribose` is in `private-docs` but is public on GitHub.
- **13 misclassified as public** (mapped to `public-docker.yml`, which includes a deploy-to-GH-Pages job):
  - `docs` group: ogc-dggs-xmi, eccma-iso-scor-vocab, annotated-express, iso-iec-smart-terms
  - `iso` group: iso-690, iso-8000-51, iso-8000-100-ed2, iso-8601-1, iso-8601-2, iso-10303-2, iso-19115-3, iso-19626-1, iso-tc184-sc4

### Not an active leak — verified via Pages API

Checked GitHub Pages API for all 13 GitHub-private repos: **all return `status=404`**, i.e. Pages is disabled on every one. The deploy step in `public-docker.yml` explicitly checks Pages-enabled and silently skips when off — private content has never actually been published anywhere. The wrong-template mapping is a **latent** issue, not an active data leak: if someone enables Pages on any of those 13 via the GitHub UI, the deploy job would suddenly go live.

### Direction

**Option B (the visibility-driven design refactor)** — cimas sync fetches `.private` from `gh api repos/<slug>` for each doc repo at sync time and picks the right template automatically; the manual `private-docs` group is removed. Work will happen under the reopened ci#347. Deferred to a subsequent session; not executed here.

Design outline:

1. cimas sync fetches `.private` per doc repo, with per-run caching.
2. Template selection moves from static `files:` mapping to visibility-conditional: `docker.yml` → `public-docker.yml` if public, `private-docker.yml.erb` if private. cimas.yml declares the logical role; cimas picks the concrete template at sync time.
3. Remove the `private-docs` group from cimas.yml (mn-samples-* stays grouped for the sample-vs-doc exception).
4. Next sync after the refactor migrates the mismatched repos automatically.

### Audit expanded — correction to the initial count

Fuller scan across all 158 cimas.yml repos surfaced **3 additional GitHub-private repos wrongly mapped to `public-docker.yml`** beyond the 13 initially reported: `iso-10303-11`, `iso-19135`, `iso-15926-6`. The last two were also independently flagged by @ronaldtse via `CHANGES_REQUESTED` reviews on their wave PRs (`iso-15926-6#9`, `iso-19135#345`), which have now been closed with branch delete.

Corrected total: **16 GitHub-private doc repos wrongly mapped to `public-docker.yml`**. Latent-leak verification still holds — all 16 return `status=404` on the GitHub Pages API, so no content has been publicly deployed.

@ronaldtse endorsed Option B's direction on the reopened ci#347: *"Reasonable to separate the private docker workflow for documents."* Full follow-up thread on ci#347.

🤖

---

## Outcome — 2026-07-06 ~13:30-14:20: post-dispatch tripwire reverted

### What was in place

[`metanorma/ci#326`](https://github.com/metanorma/ci/pull/326) (merged 2026-06-30, commit `56bdec5`) added a "verify release-passed dispatch acknowledged downstream" step at the end of `rubygems-release.yml`. The step polled for 90s after firing `release-passed` back to the same repo, and red-failed the CI job if no workflow run appeared. Intent: make silent-fail on missing receivers visible.

### Why it was wrong for this architecture

The release-chain fan-out is orchestrated from `metanorma-cli`: its live `notify.yml` catches `release-passed` → calls `mn-processor-notify.yml` → reads `dependent_repos.env` → dispatches `do-release` at each dependent gem. Dependent gems are *leaves* in this design; they release when metanorma-cli tells them to and don't cascade further. They don't need — and were never intended to have — their own notify.yml receiver.

The tripwire I added assumed the opposite topology (every gem cascades). So it fired on every leaf gem's release and red-failed the CI even though gem-publish had already completed successfully. The tripwire ran *after* the publish step in `rubygems-release.yml`, so it could not prevent a release; it could only add a red CI mark after the fact.

Effect over the six days it was live: every leaf-gem release CI showed red on the tripwire step even though the gem had successfully published to rubygems. The signal was noise.

### Reverts

- **[`metanorma/ci:8de06be`](https://github.com/metanorma/ci/commit/8de06be)** — reverts the tripwire step from `rubygems-release.yml`. Releases go green when gem-publish succeeds.
- **[`metanorma/ci:132bcfd`](https://github.com/metanorma/ci/commit/132bcfd)** — reverts a same-day cimas.yml change that would have mapped notify.yml to 47 gems. Inert (no cimas sync ran).
- **[`metanorma/isodoc:a8e3f763`](https://github.com/metanorma/isodoc/commit/a8e3f763)** — deletes a notify.yml file direct-pushed to isodoc live main earlier the same day.

### Evidence that releases were shipping through the tripwire

Both today's isodoc releases and today's metanorma-standoc release published successfully to rubygems despite the red CI:

- `isodoc` v3.6.7 (2026-07-06 04:05 UTC), v3.6.8 (2026-07-06 08:03 UTC)
- `metanorma-standoc` v3.4.8 (2026-07-06 04:26 UTC)

### Design gap the tripwire tried and failed to catch

`metanorma-cli`'s `dependent_repos.env` is a hand-maintained list. If it drifts — a repo dropped, name mistyped, line commented out by accident — that repo silently stops being triggered on future releases. The tripwire I built could not have caught this: it checked receiver existence on the sender side, not fan-out completion on the orchestrator side. Correct guard shape is:

1. Inside `mn-processor-notify.yml` (or a step called after it), verify each `do-release` dispatch actually produced a workflow run on the target repo.
2. Alternative: a scheduled workflow that periodically diffs `dependent_repos.env` against the current rubygems state and surfaces drift after the fact.

Design when calm, not during a release.

🤖

---

## Outcome — 2026-07-07: metanorma-docker runner Ruby pin fixed + Ruby-floor drift audit queued

### What surfaced

metanorma-cli v1.16.8 released successfully to rubygems 2026-07-07 01:03 UTC, but the metanorma-docker `release-tag.yml` workflow that fires on the downstream `release-passed` event failed with `version solving has failed` — bundler tried to install metanorma-cli 1.16.8 (which requires Ruby >= 3.3 per ci#274) into a Ruby 3.2.11 runner and correctly refused.

**Root cause**: the workflow's `ruby/setup-ruby@v1` step pinned `ruby-version: '3.2'`. It never got bumped when ci#274 pushed the org-wide Ruby floor from 3.2 → 3.3. The four Dockerfiles in the same repo (ubuntu, alpine, ruby, windows) were already on 3.3.7 — only the workflow-runner pin was stale.

### Immediate fix

[`metanorma/metanorma-docker:93fc853`](https://github.com/metanorma/metanorma-docker/commit/93fc853) — one-line change, `ruby-version: '3.2'` → `'3.3'` in `.github/workflows/release-tag.yml`. Retriggered v1.16.8 via `workflow_dispatch`.

### Follow-up queued: audit-machinery for Ruby-floor drift class

No automated coverage exists for "runner-side Ruby pins across the org must match the gemspec-declared floor." When ci#274 bumped the floor, gemspecs got updated (via cimas patches machinery), but workflow-runner pins in other repos silently stayed on the old floor until a real release exercised the mismatch. Same could happen again on the next floor bump.

**Where to extend**: the scheduled drift-audit in `metanorma/ci:.github/workflows/cimas-drift-audit.yml` + `metanorma/ci:.github/scripts/cimas-drift-audit.rb`. Add an 8th class to the current 7-class taxonomy.

**What the check does**:

- Walks `.github/workflows/*.yml` across cimas-managed repos + Dockerfiles.
- Extracts `ruby/setup-ruby@v*` steps → `ruby-version:` value → major.minor.
- Extracts Dockerfile `FROM ruby:X.Y.Z` lines → major.minor.
- Compares against a hardcoded `RUBY_FLOOR = '3.3'` constant (with a comment pointing at ci#274; bumped by one-line edit when the floor next moves).
- Reports findings to [ci#342](https://github.com/metanorma/ci/issues/342) in the same shape as other drift-audit classes.

**What it does NOT do**: no auto-fix; no workflow-blocking; passive schedule-only report. No tripwire shape.

**Estimate**: ~30-60 min actual.

**Related**: [`ci#274`](https://github.com/metanorma/ci/issues/274) (Ruby 3.3 floor), [`ci#341`](https://github.com/metanorma/ci/pull/341) (drift-audit workflow), [`ci#342`](https://github.com/metanorma/ci/issues/342) (rolling tracking issue).

🤖

---

## Outcome — 2026-07-07: metanorma-docker v1.16.8 released + suma-docker chain hop surfaced

### Release status

metanorma-docker v1.16.8 released cleanly. Both workflows completed successfully:

- **Linux** ([run 28839809846](https://github.com/metanorma/metanorma-docker/actions/runs/28839809846)) — `Build+publish` for `metanorma-ruby`, `metanorma-ubuntu`, `metanorma-alpine`. Images live on `docker.io/metanorma/metanorma:1.16.8` and `ghcr.io/metanorma/metanorma:1.16.8`.
- **Windows** ([run 28839809861](https://github.com/metanorma/metanorma-docker/actions/runs/28839809861)) — `Build Windows (ltsc2022)` + `(ltsc2025)` + `create-manifest`. Windows push happens inside the `build` job before tests; two `ltsc2025` test failures are non-blocking (`continue-on-error: true` on all `ltsc2025` matrix entries).

### New release-chain hop discovered: metanorma/suma-docker

Surfaced via [iso-10303#705](https://github.com/metanorma/iso-10303/issues/705). `metanorma/suma-docker` publishes `ghcr.io/metanorma/suma-docker`, a 30-line thin layer over the metanorma base image:

```
FROM metanorma/metanorma:1.16.6
# install eengine 5.2.7 (EXPRESS schema engine)
# install eep (Eurostep EXPRESS Parser)
```

Since the [`be4e186` 2026-07-02 restructure](https://github.com/metanorma/suma-docker/commit/be4e186), suma itself ships inside the `metanorma` gem, so this repo installs no gems — glues two static EXPRESS binaries onto the metanorma-docker base image. Windows leg exists (`Dockerfile.windows`) but is commented out in the workflow.

**Automation status**: none. `Dockerfile` line 1 is a hardcoded `FROM metanorma/metanorma:X.Y.Z`. Release procedure requires manual base-image bump + workflow_dispatch of `release-tag.yml`. No `repository_dispatch` receiver, no notify hook, no polling. Maintainer confirmed the automation would be ideal but has not been in the current time budget; queued as a follow-up on this SSOT.

### Downstream consumers (blast-radius map)

Org-wide search surfaced two:

1. **`metanorma/iso-10303-2-vocab` README** — documents `docker run ghcr.io/metanorma/suma-docker:latest` for Docker-preferring users. External-user surface.
2. **`metanorma/iso-10303` `build.yml`** — uses `bundle exec suma build` **directly against the gem, not the Docker image**. Internal CI decoupled.

No metanorma-org internal CI depends on suma-docker. Blast radius of a broken suma-docker release is bounded to external users pulling `:latest`.

### Failure-mode analysis for auto-sync

| Failure mode | Probability | Behaviour |
|---|---|---|
| Base distro migration breaks `apt-get` package names on the eengine install layer | Very low | Auto-build FAILS red, no broken image published. Safe fail. |
| eengine 5.2.7 SBCL binary incompatible with newer glibc in bumped base | Very low | Build succeeds but `eengine --version` fails at runtime. Silent breakage. |
| Base-image tag scheme changes | Very low | Build fails at `FROM` resolution. Safe fail. |
| Major-version metanorma bump (e.g. `2.0.0`) with breaking gem-embedded SUMA changes | Rare (~biennial) | Auto-published image could ship silently broken. |

The silent-broken-image class exists today with manual bumps — suma-docker's `publish-linux` builds and pushes without ever `docker run`-ing the image. Smoke-test guard is independent risk-reduction regardless of automation.

### Queued follow-up (post-current-cycle)

Two parts, sequenced:

**Part A: Smoke-test guard on suma-docker's `build-push.yml`** (~15 min, standalone value).

Add a step after build, before push:

```yaml
- name: Smoke-test the image
  run: |
    docker run --rm ghcr.io/metanorma/suma-docker:latest bash -c '
      eengine --version || eengine --help || true
      eep --help || true
      metanorma --version
    '
```

Kills the silent-broken-image class for both manual and future auto releases.

**Part B: Auto-sync receiver** (~1-2 hrs, sequential after A).

Two candidate shapes, pick at implementation:

- **Shape 1 (preferred)** — Extend metanorma-docker's `announce` job (currently dispatches to `mn-samples-*` on tag push) to also fire a `repository_dispatch` of type `base-image-updated` to `metanorma/suma-docker`. Receiver workflow in suma-docker parses the dispatch payload, `sed`-bumps `FROM metanorma/metanorma:X.Y.Z` in both Dockerfiles, commits to main via bot, dispatches `release-tag.yml` with a patch-bumped `next_version`.
- **Shape 2 (fallback)** — Scheduled cron on suma-docker that polls metanorma-docker's latest release tag and executes the same bump-commit-release when it detects a newer version. Simpler, higher latency.

Optional gate: receiver auto-releases for patch/minor bumps only (`^X\.Y+\.\d+$` matches; major bump forces manual review).

### Manual v1.16.8 bump

Owner has taken the manual v1.16.8 bump personally in this cycle. Sequence for reference: edit `Dockerfile` line 1 from `metanorma/metanorma:1.16.6` to `:1.16.8`, edit `Dockerfile.windows` line 1 similarly, commit to main, workflow_dispatch `release-tag.yml` with `next_version: 0.3.0`. `build-push.yml` publishes `ghcr.io/metanorma/suma-docker:0.3.0` for `linux/amd64` + `linux/arm64` on tag push.

### Related

- Fits under the existing release-chain observability design gap logged in the tripwire-lesson section of this SSOT.
- Adjacent to [`ci#274`](https://github.com/metanorma/ci/issues/274), [`ci#341`](https://github.com/metanorma/ci/pull/341), [`ci#342`](https://github.com/metanorma/ci/issues/342).

🤖

---

## Outcome — 2026-07-08 evening: A/B/C batch shipped + Koonwa fix + pre-wave prep

### What shipped tonight (pre-wave)

**A — Ruby-floor drift audit (class (f) in cimas-drift-audit)**. Extended `metanorma/ci:.github/scripts/cimas-drift-audit.rb` with an 8th class that walks `.github/workflows/*.yml` + `Dockerfile*` across cimas-managed repos, extracts `ruby-version:` from `ruby/setup-ruby@*` steps + matrix lists + `FROM ruby:X.Y.Z` tags, compares against a hardcoded `RUBY_FLOOR = "3.3"` constant. Dynamic `${{ ... }}` refs and reusable-workflow-driven matrices are skipped as unverifiable statically. New `PHASE_5_RUBY_FLOOR_ONLY=1` harness with `LIMIT=N` + `ONLY_REPO=name1,name2` filters. Shipped as [`metanorma/ci#348`](https://github.com/metanorma/ci/pull/348) on branch `feature/drift-audit-ruby-floor`. Full sweep across 155 cimas.yml entries surfaced 24 findings across 9 repos, 146 clean, 0 false positives; findings [posted as a PR comment](https://github.com/metanorma/ci/pull/348#issuecomment-4904433316). Scope is cimas.yml-only; fleet-wide extension (to cover `metanorma-docker` and other non-cimas release-adjacent repos) remains a follow-up.

**B — `release-tag.yml` silent-index touch-fix on suma-docker**. The workflow file had existed since 2026-05-14 but GitHub Actions never indexed it as dispatchable — `gh workflow run` returned 404, and the workflows list only showed `build-push` + `CodeQL`. Fixed via a header-comment addition at [`metanorma/suma-docker:14589ae`](https://github.com/metanorma/suma-docker/commit/14589ae). Verified: workflow now shows state `active`; the header also documents the manual `git tag` fallback used for the v0.3.0 release earlier the same day.

**C — Bulk-merge of the 8 cleanup-orphans-2026-07-05 PRs**. All admin-force-merged with `--delete-branch`. Failing CI on those PRs was pre-existing docker.yml build failures on the doc repos themselves, not regressions from the cleanup (verified against representative runs). PRs: ietf-rfc-3339#7, C-17-Publication#4, iec-iso-jseg-15#11, rfc-divination-cfapi#15, rfc-asciidoc-rfc#42, rfc-asciirfc-minimal#22, iso-19626-1#13, iso-tc184-sc4-directives#11. ci#347 remediation loop now fully closed.

### Discovery + fix — Koonwa's `release.yml` gap

While reviewing [`ci#339`](https://github.com/metanorma/ci/pull/339) (least-privilege `permissions:` on six master caller templates — clean, uncontroversial; deferred to the next wave pending review), a [prior comment from @kwkwan on metanorma-plugin-lutaml#285](https://github.com/metanorma/metanorma-plugin-lutaml/pull/285#discussion_r3517110963) surfaced: `bundle install is needed when running do-release. Otherwise, the build will fail.`

Root cause: [`ci#314`](https://github.com/metanorma/ci/issues/314) deprecated `bundler_cache` (hardcoded to `false` in the release job, after the metanorma-cli v1.16.6 `Bundler::GemNotFound: metanorma-nist` incident), but the master `release.yml` template still relied on the implicit `bundle install` that `ruby/setup-ruby`'s `bundler-cache: true` used to provide. The reusable's default `release_command: bundle exec rake release` then fires against uninstalled gems and fails. Koonwa's live workflow carried a local `release_command: | bundle install\n bundle exec rake release` override; the closed sync PR #285 would have erased it on next resync. **This is a specific instance of the release-chain observability gap** logged in the tripwire-lesson section — same class, distinct undiscovered gotcha, high blast radius (every gem using `release.yml` would have broken on next release).

**Fixed at [`metanorma/ci:f994f4c`](https://github.com/metanorma/ci/commit/f994f4c)** — direct-push to main (matches the `a864ed9` / `949efb2` precedent for template/cimas.yml corrections). Master `release.yml` now passes an explicit `release_command: | bundle install\n bundle exec rake release` with a rationale comment naming ci#314 and the surfacing. Redistributes on the 2026-07-08 wave.

A [threaded reply](https://github.com/metanorma/metanorma-plugin-lutaml/pull/285#discussion_r3537078657) on Koonwa's comment credits the finding, explains root cause + fix, and links the follow-up ticket.

### Queued follow-up — [`metanorma/ci#349`](https://github.com/metanorma/ci/issues/349)

Filed to track the deeper fix: run `bundle install` inside `rubygems-release.yml`'s release job itself so callers don't need to remember the two-liner. Two candidate shapes documented:

- **A** — Explicit `bundle install` step in the release job before the step running `release_command`. Simple, safe; `release_command` stays user-controlled.
- **B** — Update the default of `release_command` from `bundle exec rake release` to `bundle install && bundle exec rake release`. Backwards-compatible; slightly less clean semantically since the input's name suggests just "the release command."

Non-goals: not re-enabling `bundler_cache` in any form (the ci#314 remediation stands); not touching the preflight logic (separate job by design).

### Pre-wave state — about to fire

Both `metanorma/ci` at `f994f4c` (Koonwa fix on main) and the held rubocop template change `a864ed9` are ready for distribution. Broader-orphan catalog prepped from 2026-07-05. The wave carries:

1. **Rubocop template correction** (`a864ed9`) — appended `.rubocop_todo.yml` as the last `inherit_from` entry so per-gem todos take effect against the shared oss-guides config.
2. **Koonwa fix** (`f994f4c`) — explicit `release_command` in master `release.yml`.
3. **Broader-orphan cleanup wave** — ~40-45 repos × `.hound.yml` + orphan `rake.yml` / `notify.yml` / `integration.yml` / `test.yml`.

Andrew's [`ci#339`](https://github.com/metanorma/ci/pull/339) is deliberately NOT in this wave — awaiting review, rides the next.

Wave outcome section to follow immediately below.

🤖

---

## Outcome — 2026-07-08 wave complete

### Sync wave (`cimas-sync-2026-07-08`)

- **58 PRs open**, plus prior stale `cimas-sync-*` PRs auto-closed via `--flatten-stale`. Distributes:
  - `.rubocop.yml` correction (`.rubocop_todo.yml` as last `inherit_from`, per [`metanorma/ci:a864ed9`](https://github.com/metanorma/ci/commit/a864ed9)) — 54 gems mapping this template got the fix.
  - `.github/workflows/release.yml` Koonwa fix (explicit `release_command`, per [`metanorma/ci:f994f4c`](https://github.com/metanorma/ci/commit/f994f4c)) — every gem mapping release.yml.
- 3 "on par" skips (`tex2mn`, `mnconvert`, `bipm-data-outcomes`) — target branch already matched, no PR needed.
- Sync-step warnings on 2 gems' `ruby_version` patch (`metanorma-plugin-datastruct`, `tex2mn`) — pre-existing, unrelated to templates, non-blocking.

### Cleanup wave (`cleanup-orphans-broader-2026-07-08`)

- **43 PRs open**, **25 prior stale cleanup PRs auto-closed** via `--flatten-stale`. Purges:
  - `.hound.yml` (Hound defunct since ~2020).
  - Orphan `.github/workflows/rake.yml` / `notify.yml` / `integration.yml` / `test.yml`.
- 1 push failure: `sample-ogc-discussion-paper` — write permission gap, non-blocking, skipped.

### CodeQL noise — expected, addressed by pending PR

Sync-wave PRs that touched `release.yml` pick up a `github-advanced-security[bot]` CodeQL comment about the missing top-level `permissions:` block. **Exactly the class [`ci#339`](https://github.com/metanorma/ci/pull/339) fixes** — deferred to the next wave pending review. Paper trail posted on the first-observed instance ([coradoc#248 issuecomment-4905537362](https://github.com/metanorma/coradoc/pull/248#issuecomment-4905537362)); the PR-#339 author was pinged on the PR itself ([issuecomment-4905553442](https://github.com/metanorma/ci/pull/339#issuecomment-4905553442)) with coradoc#248 named as the representative case. Once ci#339 merges, the next wave's distribution retires the finding fleet-wide.

### What ripens next

- **Merge review** on the 101 wave PRs as CI settles. Transient rubocop-drift red-CI expected on gems whose `.rubocop_todo.yml` predates the ci#334 plugin additions (per-gem `bundle exec rubocop --regenerate-todo` recipe from sts-ruby / suma 2026-07-05).
- [`ci#348`](https://github.com/metanorma/ci/pull/348) — class (f) drift audit awaiting review/merge.
- [`ci#349`](https://github.com/metanorma/ci/issues/349) — deeper bundle-install fix inside `rubygems-release.yml`, follow-up.
- [`ci#339`](https://github.com/metanorma/ci/pull/339) — permissions blocks, review-pending, folds into next wave.
- `cleanup-merged-prs` sweep after this wave's PRs merge.

🤖

---

## Outcome — 2026-07-12: full wave closure + queued ci merges

### ci merges

- [`metanorma/ci#339`](https://github.com/metanorma/ci/pull/339) merged — Andrew's least-privilege `permissions:` blocks on the six master caller templates. Now on main; distributes on the next cimas wave and retires the CodeQL missing-permissions finding class fleet-wide.
- [`metanorma/ci#348`](https://github.com/metanorma/ci/pull/348) merged — class (f) Ruby-floor drift audit. Runs on the next scheduled Wed 09:00 UTC drift-audit; findings will post to [ci#342](https://github.com/metanorma/ci/issues/342).
- [`metanorma/ci#349`](https://github.com/metanorma/ci/issues/349) stays open — deeper bundle-install fix for `rubygems-release.yml`'s release job, follow-up.

### Wave PR closure — all 82 open PRs handled

Categorised the 58 open sync-wave + 24 open cleanup-wave PRs by mergeState. Batches:

- **CLEAN (37)** — admin-merged (25 sync + 12 cleanup).
- **UNSTABLE mn-templates-* (9)** — mass-fail CI attributable to the 2026-07-09 `lutaml/xmi` gem-yank fallout (per [metanorma-plugin-lutaml#290](https://github.com/metanorma/metanorma-plugin-lutaml/issues/290)); admin-merged since the wave content itself is sound.
- **UNSTABLE other (31)** — mostly the same yank fallout on doc + gem repos, plus some rubocop-drift on gems whose local `.rubocop_todo.yml` predates ci#334's plugin additions. Admin-merged; per-gem `--regenerate-todo` remains a per-maintainer hygiene item.
- **DIRTY (3)** — merge conflicts on `modspec-ruby#20`, `coradoc#248`, `pubid#90`. Closed with note explaining they'll re-emit on the next wave with a fresh branch base.
- **Wrong org (1)** — `ammitto/ammitto#11` retried under the correct org, merged.

Total: **78 merged + 3 closed + 1 pre-existing = all 82 wave PRs closed.**

### Branch cleanup — `cimas cleanup-merged-prs` on both waves

Two sweeps ran across the fleet's cimas-wd checkouts:

- Sync-wave sweep: 18 `[deleted-merged]` + 54 `[deleted-no-pr]` + a handful of `[absent]`. The high no-pr count reflects wave-time silent pushes where `open-prs` skipped because target-branch was on-par with the new branch — the branches existed on origin but never turned into PRs.
- Cleanup-wave sweep: 18 `[deleted-merged]` + 3 `[deleted-no-pr]`.

**Total: ~93 branches cleaned across origin + local checkouts.**

### Net wave impact

Distributed and merged fleet-wide on this cadence:

- Rubocop template correction (`.rubocop_todo.yml` as last `inherit_from`).
- `release.yml` `release_command` fix (explicit `bundle install` + `bundle exec rake release`).
- Broader-orphan cleanup: `.hound.yml` + orphan `rake/notify/integration/test.yml`.

`metanorma/ci` main now carries Andrew's `permissions:` blocks and the class (f) drift audit; both queued to distribute / activate on the next cadence.

### What ripens next

- **ci#349** — deeper bundle-install fix, self-owned; land when time permits.
- **Wed 2026-07-15 drift audit** — first scheduled run with class (f) live.
- **Next fortnightly wave (~2026-07-22)** — will distribute Andrew's permissions blocks and any new template deltas.
- **Per-gem rubocop-drift regeneration** — non-urgent; per-gem maintainers can handle at their pace, or a targeted sweep can automate.

🤖

---

## Outcome — 2026-07-12 late-evening: ci#347 Option B shipped end-to-end

### What shipped

**[`metanorma/cimas#66`](https://github.com/metanorma/cimas/pull/66)** merged — `sync: support visibility-conditional files: values`. Adds `resolve_source(source, repo)` + `repo_visibility_private?(repo)` + `fetch_repo_visibility(slug)` helpers. Sync loop handles Hash-shaped `files:` values of the form `{ 'if_public' => path1, 'if_private' => path2 }` by picking the concrete template at sync time from `github_client.repo(slug).private`, cached per invocation. Backward-compatible: String values unchanged. Safer-default fallback: unreachable visibility → `private` (never deploys). 5 new specs; full 30-example suite passes.

**[`metanorma/ci#350`](https://github.com/metanorma/ci/pull/350)** merged — `cimas.yml + drift-audit: visibility-driven docker template selection`. Refactored 63 doc-repo `docker.yml` mappings to the Hash shape (58 currently `public-docker.yml` + 5 currently `private-docker.yml.erb` — all become identical Hash values; cimas picks per-repo). Removed the `private-docs` group (visibility is now systematic, not hand-curated). Updated `.github/scripts/cimas-drift-audit.rb` with `resolve_template_path` + `repo_visibility_private?` helpers so the weekly scheduled audit handles Hash template_paths.

### Auto-migration on next wave

The 16 GitHub-private doc repos previously wrongly mapped to `public-docker.yml` (per the 2026-07-06 ci#347 visibility audit) auto-migrate to `private-docker.yml.erb` on the next `cimas sync`. Also `mn-samples-ribose` — currently in the now-defunct `private-docs` group but public on GitHub — gets `public-docker.yml` per its actual visibility. Latent-leak class closed.

### Follow-up

- **Wed 2026-07-15 drift audit** — first scheduled run under the new cimas.yml + updated drift-audit. Will visibility-lookup on the 63 doc repos (well within API limits).
- **Next cimas wave (~2026-07-22)** — will auto-migrate the 16 mis-classified private repos. Wave PR bodies should call out the auto-migration for reviewer context.
- **Visibility-conditional opt-outs** — the current opt-out parser (`scan_opt_outs` in drift-audit) doesn't recognise commented-out Hash-shape entries. Non-urgent (nobody's opted out of a Hash entry yet); filed as a follow-up refinement if it comes up.

🤖

---

## Outcome — 2026-07-12 ~22:50: class (f) fleet-wide extension + residual generate.yml sweep

### Fleet-wide class (f) extension — [`metanorma/ci#351`](https://github.com/metanorma/ci/pull/351) merged

Closes the scope gap noted in [`#348`](https://github.com/metanorma/ci/pull/348)'s PR body: the class (f) audit was cimas.yml-only, which meant metanorma-docker's 2026-07-07 `release-tag.yml` Ruby-3.2 pin miss — the exact case that motivated the audit — was not covered because metanorma-docker isn't in cimas.yml.

Added a small `SUPPLEMENTARY_RUBY_FLOOR_REPOS` allowlist for release-adjacent non-cimas repos:

- `metanorma/metanorma-docker`
- `metanorma/suma-docker`
- `metanorma/ci`
- `metanorma/packed-mn`

Supplementary entries receive class (f) scanning only; classes (a)-(e3) don't apply. Minimal change: append `supplementary_entries` to the entries list in the `PHASE_4` (full report) and `PHASE_5` (class F isolated) harnesses. `audit_entry` naturally no-ops on file-drift / opt-outs for entries with empty file mappings.

Locally verified: all 4 supplementary repos scan clean under the current (post-2026-07-07 fix) state.

### Residual generate.yml orphan sweep — no live orphans

Fired `cimas cleanup-orphan-files --only-target=.github/workflows/generate.yml` against the fleet. 8 orphans detected on the local checkout — investigation confirmed all 8 are the same repos whose 2026-07-05 cleanup PRs were admin-force-merged earlier the same evening. The stale local `cimas-wd` still carried the `generate.yml` files that were already removed on origin `main`. Cimas correctly pushed no-op deletion branches to origin.

Deleted the 8 no-op branches from origin. The ci#347 follow-up on live `generate.yml` deletion is de facto complete — the 2026-07-05 orphan-cleanup wave + the same-evening admin-force-merge together handled every case.

### Operational hygiene note

`cimas-wd-2026-06-29` local state can drift from origin after admin-force-merges. Fix: `cimas pull` before firing `cleanup-orphan-files` (or any command that reads local state).

### What ripens next

- **Wed 2026-07-15 drift audit** — first scheduled run under the fully-extended class (f) scope (cimas + supplementary).
- **Next cimas wave ~2026-07-22** — will pick up any new template deltas.

🤖

---

## Outcome — 2026-07-12 ~23:00-23:35: ci#349 discovery + metanorma-docker smoke gate + rubocop drift spot-check

### ci#349 closed as pre-implemented — [`ci#352`](https://github.com/metanorma/ci/pull/352) merged

Investigation for the ticket revealed that the "deeper fix" (explicit `bundle install` step inside `rubygems-release.yml`'s release job) was already implemented in [`#316`](https://github.com/metanorma/ci/pull/316) on 2026-06-29 — before Koonwa's original comment. Later refined by [`#328`](https://github.com/metanorma/ci/pull/328) to skip `development` + `test` groups.

Closed [`ci#349`](https://github.com/metanorma/ci/issues/349) with an explanatory comment. [`ci#352`](https://github.com/metanorma/ci/pull/352) reverts the redundant `release_command: bundle install && bundle exec rake release` two-liner from the master `release.yml` template (added tonight at `f994f4c` as defense-in-depth against a bug that was already fixed). Downstream gems currently carrying the two-liner (from tonight's 2026-07-08 wave) keep it until their next resync — harmless double-install in the interim.

### Metanorma-docker smoke gate — [`#238`](https://github.com/metanorma/metanorma-docker/pull/238) merged

Parallel to Ronald's suma-docker smoke framework, but simpler — one-line `docker run --rm <image> metanorma version` gate before publish, on both Linux and Windows workflows. Closes the "image builds green but metanorma is broken" observability gap on the base image the whole fleet depends on. Placement: Linux in `lint` job after `Load image`; Windows in `build` job after `Build Docker Image` (Windows push happens inside the build job, unlike Linux).

### Per-gem rubocop-drift regen — 1 gem shipped + a structural finding

- `metanorma/coradoc` — clean, no drift.
- `metanorma/pubid-etsi` — real drift, 49 offenses. Regenerated `.rubocop_todo.yml`, fixed `.rubocop.yml` inherit_from order (last-wins), updated oss-guides URL from `master` to `main`. Verified clean; shipped as [`pubid-etsi#8`](https://github.com/metanorma/pubid-etsi/pull/8).
- Two other candidates (metanorma-document, html2doc) hit bundler friction; skipped rather than chase.

### Structural finding: wave content didn't universally land

pubid-etsi's live `.rubocop.yml` on origin `main` did NOT have the 2026-07-07 template correction (`.rubocop_todo.yml` as last inherit_from entry). Yet the 2026-07-08 sync-wave PR on pubid-etsi merged. Hypothesis: `cimas sync` produced no diff for pubid-etsi because the local `cimas-wd` checkout was already at a divergent state (prior partial sync or manual local edits), so cimas skipped emitting the template change. An unknown number of other gems may have similar drift.

Follow-up recommendation:

1. Run a scoped diff of every cimas-managed repo's live `.rubocop.yml` against the current master template. Repos where they differ should be manually resync'd, or the wave protocol updated so cimas sync forces the diff rather than skipping "no-diff" cases.
2. Run `cimas pull` before the next wave to eliminate the stale-checkout class.

Not urgent — affected gems still have working CI locally, just latent drift that surfaces when the todo actually gets consulted.

### What ripens next (updated)

- **Wed 2026-07-15 drift audit** — first scheduled run under fully-extended class (f) scope.
- **Next cimas wave ~2026-07-22** — should fresh-`cimas pull` before firing, and audit template propagation post-wave to catch gems where the diff was silently no-op'd.
- **Rubocop-drift follow-up sweep** — scoped by the audit above; not urgent.

🤖
