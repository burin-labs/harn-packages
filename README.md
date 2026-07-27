# Harn package index

This repository hosts the public package index for the
[Harn](https://github.com/burin-labs/harn) ecosystem. The single source of
truth is [`harn-package-index.toml`](./harn-package-index.toml), which lists
every public `@burin/*` package and its immutable releases.

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
to `harn-package-index.toml`. Registry v2 binds each version to both its public
tag and the full commit SHA resolved from that tag. The index stores metadata
only, never package source or secrets.

## Validate an index change

Run the same validator as CI before opening a pull request:

```sh
harn package registry verify harn-package-index.toml \
  --remote \
  --receipt-out registry-verification.json
```

Use the Harn version pinned by [`.harn-version`](./.harn-version). The Harn
verifier owns the registry contract: strict schema validation, package and
version identity, provenance/repository coherence, immutable tag/commit
binding, and remote resolution. CI publishes its structured verification
receipt as an artifact.
