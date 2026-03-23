#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys


def read_version(zon_path: pathlib.Path) -> tuple[str, str]:
    text = zon_path.read_text(encoding="utf-8")

    name_match = re.search(r"\.name\s*=\s*\.([A-Za-z0-9_]+)", text)
    version_match = re.search(r'\.version\s*=\s*"([^"]+)"', text)
    if not name_match or not version_match:
        raise SystemExit(f"failed to read package name/version from {zon_path}")
    return name_match.group(1), version_match.group(1)


def file_sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run_text(argv: list[str]) -> str:
    return subprocess.check_output(argv, text=True).strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--zon", required=True)
    parser.add_argument("--artifact", action="append", required=True)
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()

    repo_root = pathlib.Path.cwd()
    zon_path = repo_root / args.zon
    out_dir = repo_root / args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    package_name, version = read_version(zon_path)
    artifacts = []
    checksum_lines = []

    for artifact_arg in args.artifact:
        artifact_path = repo_root / artifact_arg
        if not artifact_path.is_file():
            raise SystemExit(f"missing artifact: {artifact_path}")
        sha256 = file_sha256(artifact_path)
        relpath = artifact_path.relative_to(repo_root).as_posix()
        checksum_lines.append(f"{sha256}  {relpath}")
        artifacts.append(
            {
                "path": relpath,
                "sha256": sha256,
                "bytes": artifact_path.stat().st_size,
            }
        )

    manifest = {
        "package": package_name,
        "version": version,
        "commit": run_text(["git", "rev-parse", "HEAD"]),
        "zig_version": run_text(["zig", "version"]),
        "artifacts": artifacts,
        "cwd": os.getcwd(),
    }

    (out_dir / "SHA256SUMS").write_text("\n".join(checksum_lines) + "\n", encoding="utf-8")
    (out_dir / "release-manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
