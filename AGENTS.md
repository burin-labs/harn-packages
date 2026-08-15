# AGENTS.md - Harn package index

This repository serves the public Harn package index at
`https://packages.harnlang.com/harn-package-index.toml`. The index contains
package metadata and immutable source references, never package source or
credentials.

## Index changes

- Edit `harn-package-index.toml` directly. Keep existing packages and release
  records intact; add a new `[[package.version]]` block for each release.
- Before changing an entry, inspect the referenced package's exact
  `harn.toml`. Keep its package name, Harn compatibility range, exports, and
  release ref aligned with the published manifest.
- Every version must name its published `tag` and the full commit SHA that tag
  resolves to in `rev`. Mutable branches and symbolic revisions are forbidden.
- Keep `git`, `package`, and `provenance` links public and resolvable. Do not
  add local paths, credentials, access tokens, or source archives.

## Validation

Install the version pinned by `.harn-version`, then run the same Harn-owned
check as CI before committing an index change:

```sh
harn package registry verify harn-package-index.toml --remote
```

The verifier owns registry-v2 structure, uniqueness, provenance/repository
coherence, immutable tag/commit identity, and remote tag resolution.

## Reconciliation

The verifier proves the index is internally consistent and that every recorded
tag resolves. It cannot know about a release that was never written down.
Nothing else closes that gap — `harn publish` is author-invoked and is wired
into no release pipeline — so `reconcile-index.harn` is the observer:

```sh
harn run --allow-process-network reconcile-index.harn
```

It reads the index through `harn package search --json` rather than parsing
TOML itself, then compares every package against `git ls-remote` and the
published `harn.toml`. It reports five kinds of drift, and in the default
`report` mode exits non-zero on any of them:

- `unrecorded_release` — an upstream `v*` tag with no version record.
- `rev_mismatch` — a record whose `rev` is no longer what its tag resolves to.
- `missing_upstream_tag` — a record naming a tag that no longer exists.
- `metadata_drift` — package-level `harn` or `exports` disagreeing with the
  manifest at the newest published release.
- `manifest_unreadable` — a repository whose `harn.toml` could not be read at
  that release, so its metadata was not checked.

The `Reconcile index` workflow runs it daily, on demand, and whenever a package
repository reports a release. Cover changes to it with
`harn test reconcile-index.test.harn`, which runs on every pull request.

The job runs under the sandbox with `--allow-process-network` plus `/etc` and
`/run` read roots. Both roots are needed for DNS: `/etc/resolv.conf` is a
symlink into `/run` on Linux runners. Every network read goes through a
subprocess, because `harness.net` egress is governed separately from
subprocess sockets and cannot be granted without `--no-sandbox`. Checkout runs
with `persist-credentials: false`, since the credential config it otherwise
writes points outside the sandbox and makes every `git` call in the worktree
fail to parse `.git/config`.

## Proposing

`RECONCILE_MODE` selects what a run does with what it found. `report` is the
default, so a local run and any host that forgets to set the variable observes
without editing anything. `propose` also writes the correction:

```sh
RECONCILE_MODE=propose harn run --allow-process-network reconcile-index.harn
```

A finding is proposed only when the correction is mechanical:

- `unrecorded_release` becomes a `[[package.version]]` block, naming the tag,
  the commit it resolves to, and the package name read from the manifest at
  that tag.
- `metadata_drift` becomes a replacement for the package-level `harn` or
  `exports` line, provided the existing value is a complete TOML value on one
  line.
- `rev_mismatch` and `missing_upstream_tag` are never proposed. A tag that
  moved or vanished is a repository incident or a rewritten release, and
  editing the index to agree with it would launder that away.
- `manifest_unreadable` is never proposed, because a version record names its
  package by the manifest name and there is nothing to read it from.

Package metadata is compared against the manifest at the newest published
release, not the newest recorded one, so a run that records a release also
aligns the metadata that release shipped with.

The edited index is re-verified with
`harn package registry verify harn-package-index.toml --remote` before anything
is pushed, so a proposal that would fail review never reaches a pull request. A
propose run exits zero when everything it found became a proposal, because the
pull request is the alarm and it outlives the run. It still fails when a
finding has no mechanical correction.

The script decides what the index should say and renders the title and body
into `reconcile-proposal.json`. `scripts/propose-index-drift.sh` transports
that to GitHub: the branch, the commit, and the credential stay outside the
Harn sandbox, which strips `*TOKEN` variables from subprocesses anyway. Commits
go through the contents API so GitHub signs them, and the checkout keeps
`persist-credentials: false`.

`reconcile/index-drift` is bot-owned. Every run resets it to current main and
re-applies the current proposal, so a daily schedule updates one pull request
rather than accumulating one per day, and a run that finds no drift closes the
superseded proposal. Do not push review fixes to that branch; merge the
proposal and correct in a follow-up, or close it and edit the index directly.

## Release-triggered reconciliation

Package repositories call
`burin-labs/.github/.github/workflows/register-package-release.yml` on a
release tag, which dispatches this workflow in `propose` mode and fails the
calling run if it does not succeed. The trigger is hosted once in the
organization repository rather than copied into every package repository, and
the token it uses can only dispatch: writing the index stays here.

## Downstream projection

This repository is the source of truth for the index. `harn-cloud` carries a
fleet-projected copy at `package-index/harn-package-index.toml`, propagated by
the nightly fleet-convergence run rather than by anything here.

Do not read, diff, or edit that copy as part of index work, and do not treat a
difference between the two as index drift. A change merged here reaches
`harn-cloud` at the next nightly convergence, so the two are expected to differ
for up to a day. The reconciler deliberately looks only at this repository's
index and at upstream package repositories.

## Pages

Merges to `main` publish only `harn-package-index.toml`, `CNAME`, and
`.nojekyll` to GitHub Pages. Do not add a static-site build system for this
single-file registry.

<!-- BEGIN HARN SHARED AGENT CONTRACT: managed by harn-bump-fleet -->

## Ecosystem working agreement

- Pursue the ambitious product outcome; make the seams boring with small typed
  interfaces, explicit invariants, and deterministic projections.
- Give each behavior one semantic owner. Generate or parity-test other surfaces
  instead of maintaining competing implementations.
- Work autonomously inside approved scope. Pause for destructive, production,
  high-spend, ambiguous, or authority-expanding actions—not routine reversible work.
- Treat stop, wait, stand down, and pivot as control events for long-lived work.
- Match evidence to the claim: exercise the canonical user path, state the
  falsifier, verify liveness and recovery, and record residual blind spots.
- "Ship" means landed on main with required deploy and post-merge checks complete.

<!-- END HARN SHARED AGENT CONTRACT -->
