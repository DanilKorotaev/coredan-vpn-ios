#!/usr/bin/env python3
"""
Prepare the next iOS SemVer release metadata for a main→TestFlight deploy.

Default: bump PATCH vs last ios/v* tag (one shippable push ≈ one patch release).
Overrides:
  - VERSION file already newer than last tag → keep it (manual minor/major)
  - commit trailer / subject `release-bump: minor|major` since last tag
  - env RELEASE_BUMP=patch|minor|major|none

Writes VERSION, CHANGELOG.md, docs/RELEASES.md locally (no git commit).
Commit + tag happen only after a successful TestFlight upload.
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
VERSION_PATH = REPO_ROOT / "VERSION"
CHANGELOG_PATH = REPO_ROOT / "CHANGELOG.md"
RELEASES_PATH = REPO_ROOT / "docs" / "RELEASES.md"
TAG_PREFIX = "ios/v"

SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
RELEASE_COMMIT_RE = re.compile(
    r"^(chore\(release\)|chore: release)\b", re.IGNORECASE
)
BUMP_TRAILER_RE = re.compile(
    r"release-bump:\s*(patch|minor|major)\b", re.IGNORECASE
)
SKIP_SUBJECT_RE = re.compile(
    r"^(\[skip ci\]|merge\b|chore\(release\)|chore: release)", re.IGNORECASE
)


def run(args: list[str]) -> str:
    proc = subprocess.run(
        args,
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"command failed ({proc.returncode}): {' '.join(args)}\n{proc.stderr}"
        )
    return proc.stdout


def parse_semver(value: str) -> tuple[int, int, int]:
    match = SEMVER_RE.match(value.strip())
    if not match:
        raise ValueError(f"invalid SemVer: {value!r}")
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


def format_semver(parts: tuple[int, int, int]) -> str:
    return f"{parts[0]}.{parts[1]}.{parts[2]}"


def bump(parts: tuple[int, int, int], kind: str) -> tuple[int, int, int]:
    major, minor, patch = parts
    if kind == "major":
        return major + 1, 0, 0
    if kind == "minor":
        return major, minor + 1, 0
    if kind == "patch":
        return major, minor, patch + 1
    raise ValueError(f"unknown bump kind: {kind}")


def read_version_file() -> str:
    if not VERSION_PATH.is_file():
        return "0.0.0"
    text = VERSION_PATH.read_text(encoding="utf-8").strip()
    return text or "0.0.0"


def latest_ios_tag() -> tuple[str | None, str | None]:
    """Return (tag_name, version) for highest ios/v* tag, if any."""
    proc = subprocess.run(
        ["git", "tag", "-l", f"{TAG_PREFIX}*"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        return None, None
    best_tag = None
    best_ver: tuple[int, int, int] | None = None
    for line in proc.stdout.splitlines():
        tag = line.strip()
        if not tag.startswith(TAG_PREFIX):
            continue
        ver_s = tag[len(TAG_PREFIX) :]
        try:
            ver = parse_semver(ver_s)
        except ValueError:
            continue
        if best_ver is None or ver > best_ver:
            best_ver = ver
            best_tag = tag
    if best_tag is None or best_ver is None:
        return None, None
    return best_tag, format_semver(best_ver)


def commits_since(tag: str | None) -> list[tuple[str, str]]:
    """Return list of (subject, body) from oldest to newest."""
    rev_range = f"{tag}..HEAD" if tag else "HEAD"
    fmt = "%s%x1f%b%x1e"
    out = run(["git", "log", "--reverse", f"--format={fmt}", rev_range])
    items: list[tuple[str, str]] = []
    for chunk in out.split("\x1e"):
        chunk = chunk.strip("\n")
        if not chunk.strip():
            continue
        if "\x1f" in chunk:
            subject, body = chunk.split("\x1f", 1)
        else:
            subject, body = chunk, ""
        subject = subject.strip()
        body = body.strip()
        if not subject or RELEASE_COMMIT_RE.search(subject):
            continue
        if subject.lower().startswith("[skip ci]"):
            continue
        items.append((subject, body))
    return items


def detect_bump_kind(commits: list[tuple[str, str]], env_bump: str) -> str | None:
    env_bump = (env_bump or "auto").strip().lower()
    if env_bump in {"patch", "minor", "major", "none"}:
        return env_bump
    # Prefer explicit trailer in newest commits first
    for subject, body in reversed(commits):
        for text in (subject, body):
            match = BUMP_TRAILER_RE.search(text)
            if match:
                return match.group(1).lower()
    return None


def classify_subject(subject: str) -> str:
    lower = subject.lower()
    if lower.startswith("feat"):
        return "Added"
    if lower.startswith("fix"):
        return "Fixed"
    if lower.startswith(("docs", "doc")):
        return "Changed"
    if lower.startswith(("refactor", "perf", "test", "ci", "build", "chore")):
        return "Changed"
    return "Changed"


def clean_subject(subject: str) -> str:
    subject = re.sub(
        r"^(feat|fix|docs|doc|refactor|perf|test|ci|build|chore)(\([^)]*\))?:\s*",
        "",
        subject,
        flags=re.IGNORECASE,
    )
    subject = BUMP_TRAILER_RE.sub("", subject).strip(" -:")
    return subject[0].upper() + subject[1:] if subject else subject


def extract_unreleased_bullets(changelog: str) -> list[str]:
    match = re.search(
        r"(?ms)^## \[Unreleased\][^\n]*\n(.*?)(?=^## \[|\Z)",
        changelog,
    )
    if not match:
        return []
    bullets: list[str] = []
    for line in match.group(1).splitlines():
        stripped = line.strip()
        if stripped.startswith("- "):
            bullets.append(stripped[2:].strip())
    return bullets


def build_notes(
    commits: list[tuple[str, str]], unreleased: list[str]
) -> dict[str, list[str]]:
    sections: dict[str, list[str]] = {"Added": [], "Changed": [], "Fixed": []}
    seen: set[str] = set()
    for bullet in unreleased:
        key = bullet.lower()
        if key in seen:
            continue
        seen.add(key)
        sections["Changed"].append(bullet)
    for subject, _body in commits:
        if SKIP_SUBJECT_RE.search(subject):
            continue
        note = clean_subject(subject)
        if not note:
            continue
        key = note.lower()
        if key in seen:
            continue
        seen.add(key)
        sections[classify_subject(subject)].append(note)
    return {k: v for k, v in sections.items() if v}


def render_version_section(
    version: str, date: str, notes: dict[str, list[str]]
) -> str:
    lines = [f"## [{version}] - {date}", ""]
    if not notes:
        lines.extend(["### Changed", "", "- Release packaging / TestFlight upload.", ""])
        return "\n".join(lines)
    for heading in ("Added", "Changed", "Fixed"):
        items = notes.get(heading) or []
        if not items:
            continue
        lines.append(f"### {heading}")
        lines.append("")
        for item in items:
            lines.append(f"- {item}")
        lines.append("")
    return "\n".join(lines)


def update_changelog(
    version: str,
    date: str,
    notes: dict[str, list[str]],
    *,
    keep_existing_body: bool,
) -> None:
    text = CHANGELOG_PATH.read_text(encoding="utf-8") if CHANGELOG_PATH.is_file() else ""
    if not text.strip():
        text = (
            "# Changelog\n\n"
            "All notable changes to the CoreDan VPN iOS app are documented in this file.\n\n"
            "## [Unreleased]\n\n"
        )

    repo = os.environ.get("GITHUB_REPOSITORY", "DanilKorotaev/coredan-vpn-ios").strip()
    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com").rstrip("/")

    # Split off Keep-a-Changelog footer links (lines like `[label]: url`)
    body, footer_links = _split_changelog_footer(text)

    # Clear Unreleased body (keep heading). Do not use \s* before the first
    # newline — it would consume the blank line before the next ## section and
    # then swallow that section into Unreleased.
    if "## [Unreleased]" in body:
        body = re.sub(
            r"(?ms)^## \[Unreleased\][^\n]*\n(.*?)(?=^## \[|\Z)",
            "## [Unreleased]\n\n",
            body,
            count=1,
        )
    else:
        body = body.rstrip() + "\n\n## [Unreleased]\n\n"

    section_pattern = (
        rf"## \[{re.escape(version)}\] - [^\n]*\n" rf"(.*?)(?=\n## \[|\Z)"
    )
    has_section = re.search(rf"## \[{re.escape(version)}\]", body) is not None

    if keep_existing_body and has_section:
        # Leave the narrative as authored; Unreleased already cleared.
        pass
    else:
        section = render_version_section(version, date, notes)
        if has_section:
            body = re.sub(
                section_pattern,
                section.rstrip() + "\n\n",
                body,
                count=1,
                flags=re.DOTALL,
            )
        else:
            body = re.sub(
                r"(## \[Unreleased\]\s*\n\n)",
                r"\1" + section + "\n",
                body,
                count=1,
            )

    # Refresh Unreleased + this version footer links; keep other version links
    links: dict[str, str] = {}
    for line in footer_links.splitlines():
        m = re.match(r"^\[([^\]]+)\]:\s+(\S+)\s*$", line.strip())
        if m:
            links[m.group(1)] = m.group(2)
    links["Unreleased"] = f"{server}/{repo}/compare/{TAG_PREFIX}{version}...HEAD"
    links[version] = f"{server}/{repo}/releases/tag/{TAG_PREFIX}{version}"

    footer_lines = [f"[Unreleased]: {links.pop('Unreleased')}"]
    version_keys = [k for k in links if SEMVER_RE.match(k)]
    other_keys = [k for k in links if k not in version_keys]
    version_keys.sort(key=parse_semver, reverse=True)
    for key in version_keys + other_keys:
        footer_lines.append(f"[{key}]: {links[key]}")
    footer = "\n".join(footer_lines)
    out = body.rstrip() + "\n\n" + footer + "\n"
    CHANGELOG_PATH.write_text(out, encoding="utf-8")


def _split_changelog_footer(text: str) -> tuple[str, str]:
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


def update_releases(version: str, build: str, date: str, notes: str) -> None:
    header = (
        "# iOS releases\n\n"
        "Mapping of marketing SemVer ↔ TestFlight build ↔ git tag.\n\n"
        "Rows are appended by `scripts/ci/prepare_release.py` on each successful "
        "main→TestFlight ship (commit lands after upload).\n\n"
        "| Version | Build (CI) | Git tag | Date | Notes |\n"
        "|---------|------------|---------|------|-------|\n"
    )
    row = (
        f"| {version} | {build or '—'} | `{TAG_PREFIX}{version}` | {date} | {notes} |"
    )
    if not RELEASES_PATH.is_file():
        RELEASES_PATH.parent.mkdir(parents=True, exist_ok=True)
        RELEASES_PATH.write_text(header + row + "\n", encoding="utf-8")
        return

    text = RELEASES_PATH.read_text(encoding="utf-8")
    lines = text.splitlines()
    # Remove existing row for this version (retry-safe)
    filtered = [
        line
        for line in lines
        if not re.match(rf"^\|\s*{re.escape(version)}\s*\|", line)
    ]
    # Insert new row after table header separator
    out: list[str] = []
    inserted = False
    for i, line in enumerate(filtered):
        out.append(line)
        if (
            not inserted
            and line.startswith("|---")
            and i > 0
            and filtered[i - 1].lower().startswith("| version")
        ):
            out.append(row)
            inserted = True
    if not inserted:
        if not any(l.startswith("| Version") for l in out):
            out = header.rstrip().splitlines()
            out.append(row)
        else:
            out.append(row)
    RELEASES_PATH.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")


def resolve_version(
    file_ver: str,
    last_ver: str | None,
    commits: list[tuple[str, str]],
    env_bump: str,
) -> tuple[str, str]:
    """Return (new_version, reason)."""
    kind = detect_bump_kind(commits, env_bump)
    file_parts = parse_semver(file_ver)
    last_parts = parse_semver(last_ver) if last_ver else None

    if kind == "none":
        return file_ver, "RELEASE_BUMP=none (keep VERSION file)"

    if kind in {"patch", "minor", "major"}:
        base = last_parts or file_parts
        # Explicit bump from last released version when available
        if last_parts and kind != "patch":
            base = last_parts
        elif last_parts and file_parts == last_parts:
            base = last_parts
        elif last_parts and file_parts > last_parts and kind == "patch":
            # Already manually ahead — keep unless forcing patch from env
            if (env_bump or "").lower() == "patch":
                return format_semver(bump(file_parts, "patch")), "forced patch from VERSION"
            return file_ver, "VERSION already ahead of last tag"
        return format_semver(bump(base, kind)), f"explicit {kind} bump"

    # auto
    if last_parts is None:
        return file_ver, "first release (no ios/v* tag yet)"

    if file_parts > last_parts:
        return file_ver, "VERSION already ahead of last tag (manual minor/major)"

    if file_parts < last_parts:
        # Repair: continue from last tag
        return format_semver(bump(last_parts, "patch")), "VERSION behind tag; patch from last tag"

    if not commits:
        return file_ver, "redeploy of same release (no new commits since tag)"

    return format_semver(bump(last_parts, "patch")), "auto patch (new commits since last tag)"


def write_github_output(version: str, previous: str | None, reason: str, changed: bool) -> None:
    path = os.environ.get("GITHUB_OUTPUT")
    if not path:
        return
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(f"version={version}\n")
        fh.write(f"previous={previous or ''}\n")
        fh.write(f"reason={reason}\n")
        fh.write(f"changed={'true' if changed else 'false'}\n")
        fh.write(f"tag={TAG_PREFIX}{version}\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Prepare iOS SemVer release metadata")
    parser.add_argument(
        "--bump",
        default=os.environ.get("RELEASE_BUMP", "auto"),
        help="auto|patch|minor|major|none (default: env RELEASE_BUMP or auto)",
    )
    parser.add_argument(
        "--build",
        default=os.environ.get("GITHUB_RUN_NUMBER", ""),
        help="CI build number for RELEASES.md",
    )
    parser.add_argument(
        "--date",
        default=dt.date.today().isoformat(),
        help="Release date YYYY-MM-DD",
    )
    args = parser.parse_args()

    subprocess.run(["git", "fetch", "--tags", "--force"], cwd=REPO_ROOT, check=False)

    file_ver = read_version_file()
    last_tag, last_ver = latest_ios_tag()
    commits = commits_since(last_tag)
    # Bootstrap without tags: don't dump entire history into CHANGELOG
    if last_tag is None and len(commits) > 20:
        commits = commits[-20:]

    new_ver, reason = resolve_version(file_ver, last_ver, commits, args.bump)

    changelog = CHANGELOG_PATH.read_text(encoding="utf-8") if CHANGELOG_PATH.is_file() else ""
    unreleased = extract_unreleased_bullets(changelog)
    keep_existing = (
        last_ver is None
        and new_ver == file_ver
        and f"## [{new_ver}]" in changelog
    )
    if keep_existing:
        notes = build_notes([], unreleased)
    else:
        notes = build_notes(commits, unreleased)

    note_summary = next(
        (clean_subject(s) for s, _ in reversed(commits) if not SKIP_SUBJECT_RE.search(s)),
        "TestFlight release",
    )
    # Keep RELEASES notes short
    note_summary = note_summary.replace("|", "/")
    if len(note_summary) > 80:
        note_summary = note_summary[:77] + "..."

    VERSION_PATH.write_text(new_ver + "\n", encoding="utf-8")
    update_changelog(new_ver, args.date, notes, keep_existing_body=keep_existing)
    update_releases(new_ver, str(args.build or "—"), args.date, note_summary)

    changed = new_ver != file_ver or bool(commits) or bool(unreleased)
    print(f"prepare_release: {file_ver} -> {new_ver} ({reason})")
    print(f"last_tag={last_tag or '-'} commits={len(commits)}")
    write_github_output(new_ver, last_ver, reason, changed)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001 — CI entrypoint
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
