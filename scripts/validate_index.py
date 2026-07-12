#!/usr/bin/env python3
"""Validate package-index structure and referenced Git refs."""

from collections import Counter
from pathlib import Path
import subprocess
import tomllib


INDEX_PATH = Path("harn-package-index.toml")


def fail(message: str) -> None:
    raise SystemExit(message)


def validate_ref(remote: str, kind: str, ref: str) -> None:
    namespace = "--tags" if kind == "rev" else "--heads"
    result = subprocess.run(
        ["git", "ls-remote", "--exit-code", namespace, remote, ref],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        fail(f"{remote} {kind} {ref} does not resolve{': ' + detail if detail else ''}")


def main() -> None:
    index = tomllib.loads(INDEX_PATH.read_text())
    if index.get("version") != 1:
        fail("index version must be 1")

    packages = index.get("package", [])
    if not isinstance(packages, list):
        fail("package must be an array of package tables")

    names = [package.get("name") for package in packages]
    missing_names = [str(position + 1) for position, name in enumerate(names) if not name]
    if missing_names:
        fail(f"packages without names at positions: {', '.join(missing_names)}")
    duplicated_names = [name for name, count in Counter(names).items() if count > 1]
    if duplicated_names:
        fail(f"duplicate package names: {', '.join(duplicated_names)}")

    for package in packages:
        package_name = package["name"]
        versions = package.get("version", [])
        if not isinstance(versions, list):
            fail(f"{package_name} version must be an array of version tables")
        version_names = [version.get("version") for version in versions]
        missing_versions = [
            str(position + 1) for position, version in enumerate(version_names) if not version
        ]
        if missing_versions:
            fail(f"{package_name} has versions without names at positions: {', '.join(missing_versions)}")
        duplicated_versions = [version for version, count in Counter(version_names).items() if count > 1]
        if duplicated_versions:
            fail(f"{package_name} declares duplicate versions: {', '.join(duplicated_versions)}")

        for version in versions:
            version_name = version["version"]
            remote = version.get("git")
            if not remote:
                fail(f"{package_name}@{version_name} is missing git")
            ref_keys = [key for key in ("rev", "branch") if key in version]
            if len(ref_keys) != 1:
                fail(f"{package_name}@{version_name} must declare exactly one of rev or branch")
            kind = ref_keys[0]
            validate_ref(remote, kind, version[kind])


if __name__ == "__main__":
    main()
