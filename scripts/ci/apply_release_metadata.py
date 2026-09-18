#!/usr/bin/env python3
"""
Apply a deploy's prepared VERSION/CHANGELOG/RELEASES onto the current tip of main.

Used after TestFlight upload instead of rebasing a release commit (rebases conflict
when another deploy already pushed VERSION/CHANGELOG/RELEASES).
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from prepare_release import (  # noqa: E402
    CHANGELOG_PATH,
    VERSION_PATH,
    parse_semver,
    read_version_file,
    update_releases,
)

SECTION_RE = re.compile(
    r"(?ms)^## \[([^\]]+)\] - [^\n]*\n(.*?)(?=^## \[|\Z)"
)


def extract_version_section(changelog: str, version: str) -> str | None:
    for match in SECTION_RE.finditer(changelog):
        if match.group(1) == version:
            return match.group(0).rstrip() + "\n"
    return None


def extract_releases_notes(releases_text: str, version: str) -> str:
    for line in releases_text.splitlines():
        m = re.match(
            rf"^\|\s*{re.escape(version)}\s*\|\s*[^|]*\|\s*[^|]*\|\s*[^|]*\|\s*(.*)$",
            line,
        )
        if m:
            return m.group(1).strip().rstrip("|").strip() or "TestFlight release"
    return "TestFlight release"


def insert_changelog_section(body: str, section: str, version: str) -> str:
    if re.search(rf"## \[{re.escape(version)}\]", body):
        return body
    if "## [Unreleased]" in body:
        return re.sub(
            r"(## \[Unreleased\]\s*\n\n)",
            r"\1" + section.rstrip() + "\n\n",
            body,
            count=1,
        )
    return body.rstrip() + "\n\n" + section.rstrip() + "\n"


def split_footer(text: str) -> tuple[str, str]:
    lines = text.splitlines()
    footer_start = len(lines)
    for i in range(len(lines) - 1, -1, -1):
        stripped = lines[i].strip()
        if not stripped or re.match(r"^\[[^\]]+\]:\s+\S+", stripped):
            footer_start = i
            continue
        break
    body = "\n".join(lines[:footer_start]).rstrip() + "\n"
    footer = "\n".join(lines[footer_start:]).strip()
    return body, footer


def refresh_footer(footer: str, version: str) -> str:
    repo = os.environ.get(
        "GITHUB_REPOSITORY", "DanilKorotaev/coredan-vpn-ios"
    ).strip()
    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com").rstrip("/")
    links: dict[str, str] = {}
    for line in footer.splitlines():
        m = re.match(r"^\[([^\]]+)\]:\s+(\S+)\s*$", line.strip())
        if m:
            links[m.group(1)] = m.group(2)
    links["Unreleased"] = f"{server}/{repo}/compare/ios/v{version}...HEAD"
    links[version] = f"{server}/{repo}/releases/tag/ios/v{version}"
    version_keys = sorted(
        (k for k in links if re.match(r"^\d+\.\d+\.\d+$", k)),
        key=parse_semver,
        reverse=True,
    )
    other = [k for k in links if k != "Unreleased" and k not in version_keys]
    lines = [f"[Unreleased]: {links['Unreleased']}"]
    for key in version_keys + other:
        lines.append(f"[{key}]: {links[key]}")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--snapshot-dir",
        required=True,
        type=Path,
        help="Directory with VERSION, CHANGELOG.md, docs/RELEASES.md from prepare_release",
    )
    parser.add_argument("--build", default="")
    parser.add_argument("--date", default=dt.date.today().isoformat())
    args = parser.parse_args()

    snap = args.snapshot_dir
    intended = (snap / "VERSION").read_text(encoding="utf-8").strip()
    if not intended:
        print("error: snapshot VERSION is empty", file=sys.stderr)
        return 1

    snap_changelog = (snap / "CHANGELOG.md").read_text(encoding="utf-8")
    section = extract_version_section(snap_changelog, intended)
    if section is None:
        print(
            f"error: snapshot CHANGELOG has no ## [{intended}] section",
            file=sys.stderr,
        )
        return 1

    releases_snap = ""
    for candidate in (snap / "docs" / "RELEASES.md", snap / "RELEASES.md"):
        if candidate.is_file():
            releases_snap = candidate.read_text(encoding="utf-8")
            break
    notes = extract_releases_notes(releases_snap, intended)

    tip_ver = read_version_file()
    version_for_unreleased_link = tip_ver
    if parse_semver(intended) >= parse_semver(tip_ver):
        VERSION_PATH.write_text(intended + "\n", encoding="utf-8")
        version_for_unreleased_link = intended
        print(f"VERSION -> {intended}")
    else:
        print(
            f"VERSION kept at {tip_ver} (not downgrading below uploaded {intended})"
        )

    text = CHANGELOG_PATH.read_text(encoding="utf-8") if CHANGELOG_PATH.is_file() else ""
    body, footer = split_footer(text)
    body = insert_changelog_section(body, section, intended)
    footer = refresh_footer(footer, version_for_unreleased_link)
    # Ensure tag link for this marketing version exists even if VERSION file stayed higher
    if intended != version_for_unreleased_link:
        footer = refresh_footer(footer, intended)
        # Restore Unreleased → highest version
        footer = refresh_footer(footer, version_for_unreleased_link)
    CHANGELOG_PATH.write_text(body.rstrip() + "\n\n" + footer + "\n", encoding="utf-8")
    print(f"CHANGELOG: ensured section [{intended}]")

    update_releases(intended, str(args.build or "—"), args.date, notes)
    print(f"RELEASES.md: row for {intended} (build {args.build or '—'})")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
