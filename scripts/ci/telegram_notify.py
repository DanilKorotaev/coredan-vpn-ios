#!/usr/bin/env python3
"""
Send CoreDan VPN iOS CI/CD notifications to Telegram.

Requires secrets (GitHub Actions or env):
  TELEGRAM_BOT_TOKEN — bot token from @BotFather
  TELEGRAM_CHAT_ID   — chat / channel id (e.g. from @userinfobot)

Optional:
  TELEGRAM_NOTIFY_DISABLED=1 — skip sending (no error)
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TEST_OUTPUT = REPO_ROOT / "fastlane" / "test_output"
APP_COVERAGE_TARGET = "CoreDanVPNApp.app"
MAX_FAILED_TESTS = 25


def html_escape(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def github_run_url() -> str | None:
    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com").rstrip("/")
    repo = os.environ.get("GITHUB_REPOSITORY", "").strip()
    run_id = os.environ.get("GITHUB_RUN_ID", "").strip()
    if repo and run_id:
        return f"{server}/{repo}/actions/runs/{run_id}"
    return None


def ci_context_lines() -> list[str]:
    lines: list[str] = []
    ref = os.environ.get("GITHUB_REF_NAME", "").strip()
    event = os.environ.get("GITHUB_EVENT_NAME", "").strip()
    if ref:
        lines.append(f"Ветка: <code>{html_escape(ref)}</code>")
    if event:
        lines.append(f"Событие: <code>{html_escape(event)}</code>")
    url = github_run_url()
    if url:
        lines.append(f'<a href="{html_escape(url)}">Workflow run</a>')
    return lines


def send_telegram(text: str) -> None:
    if os.environ.get("TELEGRAM_NOTIFY_DISABLED", "").strip() in ("1", "true", "yes"):
        print("TELEGRAM_NOTIFY_DISABLED: skip")
        return

    token = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
    chat_id = os.environ.get("TELEGRAM_CHAT_ID", "").strip()
    if not token or not chat_id:
        print("TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set; skip notify")
        return

    url = f"https://api.telegram.org/bot{token}/sendMessage"
    payload = urllib.parse.urlencode(
        {
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "HTML",
            "disable_web_page_preview": "true",
        }
    ).encode("utf-8")
    request = urllib.request.Request(url, data=payload, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        err_body = exc.read().decode("utf-8", errors="replace")
        print(f"Telegram API HTTP {exc.code}: {err_body}", file=sys.stderr)
        sys.exit(1)

    if not body.get("ok"):
        print(f"Telegram API error: {body}", file=sys.stderr)
        sys.exit(1)


def run_command(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, capture_output=True, text=True)


def find_xcresult(output_dir: Path) -> Path | None:
    if not output_dir.is_dir():
        return None
    results = sorted(output_dir.glob("*.xcresult"), key=lambda p: p.stat().st_mtime, reverse=True)
    return results[0] if results else None


def parse_test_summary(xcresult: Path) -> dict[str, int]:
    proc = run_command(
        ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(xcresult)]
    )
    if proc.returncode != 0:
        print(proc.stderr or proc.stdout, file=sys.stderr)
        return {"passed": 0, "failed": 0, "skipped": 0}

    data = json.loads(proc.stdout)
    passed = failed = skipped = 0
    for block in data.get("devicesAndConfigurations", []):
        passed += int(block.get("passedTests", 0))
        failed += int(block.get("failedTests", 0))
        skipped += int(block.get("skippedTests", 0))
    return {"passed": passed, "failed": failed, "skipped": skipped}


def collect_failed_tests(xcresult: Path) -> list[str]:
    proc = run_command(
        [
            "xcrun",
            "xcresulttool",
            "get",
            "test-results",
            "tests",
            "--path",
            str(xcresult),
            "--format",
            "json",
            "--legacy",
        ]
    )
    if proc.returncode != 0:
        return []

    data = json.loads(proc.stdout)
    failed: list[str] = []

    def walk(nodes: list[dict[str, Any]] | None) -> None:
        for node in nodes or []:
            result = str(node.get("result", "")).lower()
            node_type = node.get("nodeType", "")
            if node_type == "Test Case" and result in ("failed", "failure"):
                identifier = node.get("nodeIdentifier") or node.get("name", "")
                failed.append(str(identifier))
            walk(node.get("children"))

    walk(data.get("testNodes"))
    return failed


def parse_coverage_percent(output_dir: Path) -> float | None:
    xcresult = find_xcresult(output_dir)
    if not xcresult:
        return None

    proc = run_command(["xcrun", "xccov", "view", "--report", "--json", str(xcresult)])
    if proc.returncode != 0:
        return None

    data = json.loads(proc.stdout)
    for target in data.get("targets", []):
        if target.get("name") == APP_COVERAGE_TARGET:
            return round(float(target.get("lineCoverage", 0)) * 100, 2)
    return None


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def build_tests_message(outcome: str, output_dir: Path) -> str:
    xcresult = find_xcresult(output_dir)
    counts = parse_test_summary(xcresult) if xcresult else {"passed": 0, "failed": 0, "skipped": 0}
    coverage = parse_coverage_percent(output_dir)
    min_cov = os.environ.get("MIN_COVERAGE", "15").strip()

    success = outcome == "success" and counts["failed"] == 0
    title = (
        "✅ <b>CoreDan VPN — тесты пройдены</b>"
        if success
        else "❌ <b>CoreDan VPN — тесты упали</b>"
    )

    lines = [title, ""] + ci_context_lines() + [
        "",
        f"Успешно: <b>{counts['passed']}</b>",
        f"Провалено: <b>{counts['failed']}</b>",
        f"Пропущено: <b>{counts['skipped']}</b>",
    ]

    if coverage is not None:
        lines.append(f"Покрытие (app): <b>{coverage}%</b> (мин. {html_escape(min_cov)}%)")
    elif not success:
        lines.append("Покрытие: не удалось прочитать из .xcresult")

    if xcresult and counts["failed"] > 0:
        failed_tests = collect_failed_tests(xcresult)
        if failed_tests:
            lines.append("")
            lines.append("<b>Упавшие тесты:</b>")
            for name in failed_tests[:MAX_FAILED_TESTS]:
                lines.append(f"• <code>{html_escape(name)}</code>")
            if len(failed_tests) > MAX_FAILED_TESTS:
                lines.append(f"• … и ещё {len(failed_tests) - MAX_FAILED_TESTS}")

    if outcome != "success" and counts["failed"] == 0:
        lines.append("")
        lines.append(
            "<i>Шаг тестов завершился с ошибкой (сборка, покрытие или fastlane), "
            "но отдельные test case в отчёте не помечены как Failed.</i>"
        )

    return "\n".join(lines)


def build_testflight_message(outcome: str, output_dir: Path) -> str:
    meta = load_json(output_dir / "ci_testflight.json") or {}
    version = str(meta.get("marketing_version", "?"))
    build = str(meta.get("build_number", "?"))
    app_id = str(meta.get("app_identifier", ""))

    success = outcome == "success"
    title = (
        "✅ <b>CoreDan VPN — TestFlight</b>"
        if success
        else "❌ <b>CoreDan VPN — сборка TestFlight не удалась</b>"
    )

    lines = [
        title,
        "",
        *ci_context_lines(),
        "",
        f"Версия: <b>{html_escape(version)}</b> ({html_escape(build)})",
    ]
    if app_id:
        lines.append(f"Bundle ID: <code>{html_escape(app_id)}</code>")

    if success:
        lines.append("")
        lines.append("Сборка отправлена в App Store Connect (TestFlight).")
    else:
        lines.append("")
        lines.append("См. логи workflow для деталей (match, archive, upload).")

    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Telegram CI notifications for CoreDan VPN iOS")
    parser.add_argument(
        "event",
        choices=["tests", "testflight"],
        help="Notification type",
    )
    parser.add_argument(
        "--outcome",
        required=True,
        choices=["success", "failure", "cancelled", "skipped"],
        help="GitHub Actions step outcome",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_TEST_OUTPUT,
        help="fastlane test_output directory",
    )
    args = parser.parse_args()

    if args.event == "tests":
        message = build_tests_message(args.outcome, args.output_dir)
    else:
        message = build_testflight_message(args.outcome, args.output_dir)

    send_telegram(message)
    print("Telegram notification sent.")


if __name__ == "__main__":
    main()
