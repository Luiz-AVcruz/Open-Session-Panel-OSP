#!/usr/bin/env python3
"""Build reproducible installable and full-source Open Session Panel archives."""

from __future__ import annotations

import hashlib
import os
import re
import sys
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "mod"
DIST = ROOT / "dist"
MOD_ARCHIVE_ROOT = "Open Session Panel"
SOURCE_ARCHIVE_ROOT = "OpenSessionPanel-source"
ZIP_TIME = (1980, 1, 1, 0, 0, 0)
PUBLICATION_FILES = ("preview.jpg", "preview-menu.png", "WORKSHOP-DESCRIPTION.txt")


def product_version() -> str:
    common = MOD / "scripts" / "common.lua"
    content = common.read_text(encoding="utf-8")
    match = re.search(r'OSP\s*=\s*\{\s*version\s*=\s*"(\d+\.\d+\.\d+)"', content)
    if match is None:
        raise ValueError(f"No semantic product version in {common.relative_to(ROOT)}")
    return match.group(1)


def required_install_files() -> list[Path]:
    required = [
        MOD / "info.txt",
        MOD / "main.lua",
        MOD / "options.lua",
        MOD / "scripts" / "common.lua",
        MOD / "scripts" / "server.lua",
        MOD / "scripts" / "ui.lua",
        MOD / "scripts" / "strings.lua",
        MOD / "scripts" / "theme.lua",
        MOD / "scripts" / "permissions.lua",
        MOD / "scripts" / "permissions_ui.lua",
        MOD / "SOURCE.md",
        ROOT / "LICENSE",
        ROOT / "ADDITIONAL-PERMISSION",
    ]
    required.extend(MOD / name for name in PUBLICATION_FILES)
    missing = [p.relative_to(ROOT).as_posix() for p in required if not p.is_file()]
    if missing:
        raise FileNotFoundError("Required package files are missing: " + ", ".join(missing))

    info = (MOD / "info.txt").read_text(encoding="utf-8")
    if not re.search(r"(?m)^version\s*=\s*2\s*$", info):
        raise ValueError("mod/info.txt must declare Teardown multiplayer script version = 2")
    if not re.search(r"(?m)^preview\s*=\s*preview-menu\.png\s*$", info):
        raise ValueError("mod/info.txt must reference preview-menu.png")
    description = re.search(r"(?m)^description\s*=\s*(.*)$", info)
    workshop_text = (MOD / "WORKSHOP-DESCRIPTION.txt").read_text(encoding="utf-8")
    if description is None or description.group(1).strip() != " ".join(workshop_text.split()):
        raise ValueError("info.txt description must match WORKSHOP-DESCRIPTION.txt content")
    steam_preview = (MOD / "preview.jpg").read_bytes()
    if not steam_preview.startswith(b"\xff\xd8\xff") or len(steam_preview) > 1_000_000:
        raise ValueError("preview.jpg must be a JPEG no larger than 1 MB")
    menu_preview = (MOD / "preview-menu.png").read_bytes()
    if (menu_preview[:8] != b"\x89PNG\r\n\x1a\n" or menu_preview[12:16] != b"IHDR"
            or int.from_bytes(menu_preview[16:20], "big") != 512
            or int.from_bytes(menu_preview[20:24], "big") != 292):
        raise ValueError("preview-menu.png must be a 512 x 292 PNG")

    # If runtime copies are kept in the project tree, ensure they match the
    # canonical notices. The install ZIP always maps the canonical copies in.
    for name in ("LICENSE", "ADDITIONAL-PERMISSION"):
        copy = MOD / name
        canonical = ROOT / name
        if copy.exists() and copy.read_bytes() != canonical.read_bytes():
            raise ValueError(f"mod/{name} differs from the canonical root notice")
    return required


def add_file(zf: zipfile.ZipFile, path: Path, archive_name: str) -> None:
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"Expected a regular file: {path.relative_to(ROOT)}")
    data = path.read_bytes()
    info = zipfile.ZipInfo(archive_name, date_time=ZIP_TIME)
    info.create_system = 3
    info.external_attr = (0o100644 & 0xFFFF) << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    info.file_size = len(data)
    zf.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def install_members() -> list[tuple[Path, str]]:
    files = [MOD / "info.txt", MOD / "main.lua", MOD / "options.lua", MOD / "SOURCE.md"]
    files.extend(MOD / name for name in PUBLICATION_FILES)
    files.extend(path for path in (MOD / "scripts").rglob("*.lua") if path.is_file())
    members: list[tuple[Path, str]] = []
    for path in sorted(files):
        if not path.is_file():
            raise FileNotFoundError(f"Missing install member: {path.relative_to(ROOT)}")
        rel = path.relative_to(MOD).as_posix()
        if path.is_symlink():
            raise ValueError(f"Symlinks are not allowed in the mod: {rel}")
        members.append((path, f"{MOD_ARCHIVE_ROOT}/{rel}"))

    for name in ("LICENSE", "ADDITIONAL-PERMISSION"):
        target = f"{MOD_ARCHIVE_ROOT}/{name}"
        if any(existing == target for _, existing in members):
            continue
        members.append((ROOT / name, target))
    return sorted(members, key=lambda entry: entry[1])


def source_members() -> list[tuple[Path, str]]:
    paths: list[Path] = [
        ROOT / "README.md",
        ROOT / ".gitignore",
        ROOT / "LICENSE",
        ROOT / "ADDITIONAL-PERMISSION",
        ROOT / "Docs" / "PROJETO.md",
    ]
    paths.extend([MOD / "info.txt", MOD / "main.lua", MOD / "options.lua", MOD / "SOURCE.md"])
    paths.extend(MOD / name for name in PUBLICATION_FILES)
    paths.extend(path for path in (MOD / "scripts").rglob("*.lua") if path.is_file())
    paths.extend(path for path in (ROOT / "tests").rglob("test_*.lua") if path.is_file())
    paths.extend(path for path in (ROOT / "tools").rglob("*.py") if path.is_file())

    if not (ROOT / "tests").is_dir() or not any((ROOT / "tests").rglob("*")):
        raise ValueError("The complete source archive requires the project's tests")

    members: list[tuple[Path, str]] = []
    for path in paths:
        if path.is_symlink():
            raise ValueError(f"Symlinks are not allowed in the source archive: {path.relative_to(ROOT)}")
        rel = path.relative_to(ROOT).as_posix()
        members.append((path, f"{SOURCE_ARCHIVE_ROOT}/{rel}"))
    # A canonical fallback (when no working-tree copy exists) still maps to
    # the exact mod-root path in the source archive.
    for name in ("LICENSE", "ADDITIONAL-PERMISSION"):
        path = MOD / name if (MOD / name).is_file() else ROOT / name
        members.append((path, f"{SOURCE_ARCHIVE_ROOT}/mod/{name}"))
    return sorted(members, key=lambda entry: entry[1])


def write_zip(destination: Path, members: list[tuple[Path, str]]) -> None:
    with zipfile.ZipFile(destination, mode="w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for path, archive_name in members:
            add_file(zf, path, archive_name)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_archive(path: Path, expected_root: str, require_license: bool = True) -> None:
    with zipfile.ZipFile(path) as zf:
        broken = zf.testzip()
        if broken:
            raise ValueError(f"Corrupt member {broken!r} in {path.name}")
        names = zf.namelist()
        if len(names) != len(set(names)):
            raise ValueError(f"Duplicate archive paths in {path.name}")
        required = {f"{expected_root}/main.lua", f"{expected_root}/info.txt"}
        if require_license:
            required.update({
                f"{expected_root}/LICENSE",
                f"{expected_root}/ADDITIONAL-PERMISSION",
                f"{expected_root}/SOURCE.md",
            })
        missing = sorted(required - set(names))
        if missing:
            raise ValueError(f"{path.name} is missing: {', '.join(missing)}")
        if any(name.lower().endswith("/id.txt") for name in names):
            raise ValueError(f"Workshop IDs must not be packaged in {path.name}")


def main() -> int:
    try:
        required_install_files()
        version = product_version()
        DIST.mkdir(exist_ok=True)
        install = DIST / f"OpenSessionPanel-{version}.zip"
        source = DIST / f"OpenSessionPanel-{version}-source.zip"
        sums = DIST / "SHA256SUMS"
        # Build and validate the complete replacement set before publishing any
        # of it. Re-running the helper refreshes only its own three named outputs.
        with tempfile.TemporaryDirectory(prefix=".package-", dir=DIST) as tmp:
            staging = Path(tmp)
            staged_install = staging / install.name
            staged_source = staging / source.name
            staged_sums = staging / sums.name
            write_zip(staged_install, install_members())
            write_zip(staged_source, source_members())
            verify_archive(staged_install, MOD_ARCHIVE_ROOT)
            with zipfile.ZipFile(staged_source) as zf:
                if zf.testzip():
                    raise ValueError("The source archive failed its CRC check")
                names = set(zf.namelist())
                expected = {
                    f"{SOURCE_ARCHIVE_ROOT}/mod/main.lua",
                    f"{SOURCE_ARCHIVE_ROOT}/LICENSE",
                    f"{SOURCE_ARCHIVE_ROOT}/ADDITIONAL-PERMISSION",
                }
                if not expected.issubset(names) or not any(
                    name.startswith(f"{SOURCE_ARCHIVE_ROOT}/tests/") for name in names
                ):
                    raise ValueError("The source archive is incomplete")
            staged_sums.write_text(
                "".join(
                    f"{sha256(path)}  {path.name}\n"
                    for path in sorted((staged_install, staged_source), key=lambda p: p.name)
                ),
                encoding="ascii",
            )
            os.replace(staged_install, install)
            os.replace(staged_source, source)
            os.replace(staged_sums, sums)

        print(f"Install: {install.relative_to(ROOT)} ({sha256(install)})")
        print(f"Source:  {source.relative_to(ROOT)} ({sha256(source)})")
        print(f"Hashes:  {sums.relative_to(ROOT)}")
        return 0
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print(f"Packaging failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
