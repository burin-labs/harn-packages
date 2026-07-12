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
- A released version must use exactly one immutable `rev`, normally an
  annotated release tag. Use a `branch` only for an intentionally unreleased
  development record.
- Keep `git`, `package`, and `provenance` links public and resolvable. Do not
  add local paths, credentials, access tokens, or source archives.

## Validation

Run the same check as CI before committing an index change:

```sh
python3 scripts/validate_index.py
```

The script checks package/version uniqueness, requires exactly one `rev` or
`branch` per version, and confirms every remote reference exists.

## Pages

Merges to `main` publish only `harn-package-index.toml`, `CNAME`, and
`.nojekyll` to GitHub Pages. Do not add a static-site build system for this
single-file registry.
