# Harn package index

This repository hosts the public package index for the
[Harn](https://github.com/burin-labs/harn) ecosystem. The single source of
truth is [`harn-package-index.toml`](./harn-package-index.toml), which lists
every public `@burin/*` package and its immutable release or development refs.

## Canonical URL

The index is served over HTTPS by GitHub Pages at the project's custom domain:

```text
https://packages.harnlang.com/harn-package-index.toml
```

The `harn` CLI defaults to this URL — no configuration is needed:

```sh
harn add @burin/notion-sdk@^0.1   # resolves against packages.harnlang.com
harn package outdated             # compare registry pins with the index
```

Override the index for a single command with `--registry <url|path>`, or set
`HARN_PACKAGE_REGISTRY` to point at a different index.

## Publishing

Package authors publish with `harn publish`, which tags the package's own
repository and opens a pull request against this repo to add the new version
to `harn-package-index.toml`. Each entry points at a public, tagged Git
release; this index stores metadata only, never package source or secrets.

## Validate an index change

Run the same validator as CI before opening a pull request:

```sh
python3 scripts/validate_index.py
```

It checks package and version uniqueness, requires every version to use exactly
one `rev` or `branch`, and resolves each declared remote reference.
