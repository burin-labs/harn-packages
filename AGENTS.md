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
published `harn.toml`. It reports four kinds of drift and exits non-zero on
any of them:

- `unrecorded_release` — an upstream `v*` tag with no version record.
- `rev_mismatch` — a record whose `rev` is no longer what its tag resolves to.
- `missing_upstream_tag` — a record naming a tag that no longer exists.
- `metadata_drift` — package-level `harn` or `exports` disagreeing with the
  manifest at the newest non-yanked record.

The `Reconcile index` workflow runs it daily and on demand. It only reports;
fixing drift is still a reviewed index edit. Cover changes to it with
`harn test reconcile-index.test.harn`, which runs on every pull request.

The job runs under the sandbox with `--allow-process-network` plus `/etc` and
`/run` read roots. Both roots are needed for DNS: `/etc/resolv.conf` is a
symlink into `/run` on Linux runners. Every network read goes through a
subprocess, because `harness.net` egress is governed separately from
subprocess sockets and cannot be granted without `--no-sandbox`. Checkout runs
with `persist-credentials: false`, since the credential config it otherwise
writes points outside the sandbox and makes every `git` call in the worktree
fail to parse `.git/config`.

If a future change has the reconciler open pull requests rather than only
report, it must be idempotent across runs — a stable branch name, or a check
against already-open reconciler PRs — so a daily schedule cannot accumulate
one stale PR per day. It must also close or update its own superseded PR when
upstream moves again before that PR merges.

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
