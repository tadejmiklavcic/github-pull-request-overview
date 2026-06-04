#!/usr/bin/env python3
"""
List GitHub pull requests for multiple repositories, count approvals, and group
the result by ticket.

Examples:
  ./viewPr.sh
  ./viewPr.sh --only-ready
  ./viewPr.sh --format html --output pr-report.html
  ./viewPr.sh base-carmarket/di other-org/other-repo
  ./viewPr.sh --repos-file repos.txt --only-ready
  ./viewPr.sh --format json --state all base-carmarket/di

Authentication:
  Preferred: install and login with GitHub CLI (`gh auth login`).
  Fallback: export GITHUB_TOKEN with repo read access.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Any


ALLOWED_PROJECTS = ("DI", "CM", "VIV", "ABMAT", "AB", "BRIEFD", "LK")
TICKET_RE = re.compile(
    r"\[(?P<project>DI|CM|VIV|ABMAT|AB|BRIEFD|LK)-(?P<number>\d+)\]\[(?P<type>[FfHhBb])\]"
)
TYPE_ORDER = {"H": 0, "B": 1, "F": 2, "?": 3}
DEFAULT_REPOS = [
    "git@github.com:Preskok/account.git",
    "git@github.com:Preskok/address.git",
    "git@github.com:Preskok/admin.git",
    "git@github.com:Preskok/api-server.git",
    "git@github.com:Preskok/asset.git",
    "git@github.com:Preskok/backend.git",
    "git@github.com:Preskok/config.git",
    "git@github.com:Preskok/consoleapp.git",
    "git@github.com:Preskok/contact.git",
    "git@github.com:Preskok/common.git",
    "git@github.com:Preskok/core.git",
    "git@github.com:Preskok/core-api.git",
    "git@github.com:Preskok/core-http.git",
    "git@github.com:Preskok/exception.git",
    "git@github.com:Preskok/document.git",
    "git@github.com:Preskok/editor.git",
    "git@github.com:Preskok/excel.git",
    "git@github.com:Preskok/file.git",
    "git@github.com:Preskok/log.git",
    "git@github.com:Preskok/markdown.git",
    "git@github.com:Preskok/navigation.git",
    "git@github.com:Preskok/notification.git",
    "git@github.com:Preskok/oauth-identity.git",
    "git@github.com:Preskok/pdf.git",
    "git@github.com:Preskok/service.git",
    "git@github.com:Preskok/stream.git",
    "git@github.com:Preskok/tyre.git",
    "git@github.com:Preskok/view-builder.git",
    "git@github.com:Preskok/cache.git",
    "git@github.com:Preskok/signature.git",
    "git@github.com:Preskok/object-condition.git",
    "git@github.com:Preskok/mail.git",
    "git@github.com:Preskok/mailer.git",
    "git@github.com:Preskok/queue.git",
    "git@github.com:Preskok/oauth-authenticator.git",
    "git@github.com:Preskok/simple-ocr.git",
    "git@github.com:Preskok/digital-inspection.git",
    "git@github.com:Preskok/sso.git",
    "git@github.com:Preskok/laminas-oauth2.git",
    "git@github.com:Preskok/commercial-images.git",
    "git@github.com:Preskok/api-client.git",
    "git@github.com:Preskok/oauth2-server-php.git",
    "git@github.com:Preskok/zf-api-problem.git",
    "git@github.com:Preskok/zf-hal.git",
    "git@github.com:Preskok/zf-content-negotiation.git",
    "git@github.com:Preskok/zf-oauth2.git",
    "git@github.com:Preskok/b2bcario-client.git",
    "git@github.com:Preskok/equipment.git",
    "git@github.com:Preskok/document-viewer.git",
    "git@github.com:Preskok/workflow.git",
    "git@github.com:Preskok/rentacar-inspection.git",
    "git@github.com:Preskok/rentacar-export.git",
    "git@github.com:Preskok/task.git",
    "git@github.com:Preskok/widget.git",
    "git@github.com:Preskok/element-builder.git",
    "git@github.com:Preskok/rentacar-account.git",
    "git@github.com:Preskok/rentacar-backend.git",
    "git@github.com:Preskok/rentacar-class.git",
    "git@github.com:Preskok/rentacar-invoice.git",
    "git@github.com:Preskok/offer.git",
    "git@github.com:Preskok/fleet-manager.git",
    "git@github.com:Preskok/frontend.git",
    "git@github.com:Preskok/generic-importer.git",
    "git@github.com:Preskok/importer.git",
    "git@github.com:Preskok/invoice.git",
    "git@github.com:Preskok/vehicle-cost.git",
    "git@github.com:Preskok/contract.git",
    "git@github.com:Preskok/invoice-pantheon.git",
    "git@github.com:Preskok/assistance.git",
    "git@github.com:Preskok/php-sepa-xml.git",
    "git@github.com:Preskok/partner.git",
    "git@github.com:Preskok/ltr.git",
    "git@github.com:Preskok/sepa.git",
    "git@github.com:Preskok/transport.git",
    "git@github.com:Preskok/bpm.git",
    "git@github.com:Preskok/likvidator-backend.git",
    "git@github.com:Preskok/preskok-bpm.git",
    "git@github.com:Preskok/easy-rent.git",
    "git@github.com:Preskok/easy-rent-core.git",
    "git@github.com:Preskok/easy-rent-backend.git",
    "git@github.com:Preskok/utilities-api.git",
    "git@github.com:Preskok/exporter.git",
    "git@github.com:Preskok/laminas-pdf.git",
    "git@github.com:Preskok/pdf-viewer.git",
    "git@github.com:Preskok/b2b-api.git",
    "git@github.com:Preskok/b2b-backend.git",
    "git@github.com:Preskok/b2b-frontend.git",
    "git@github.com:Preskok/b2b-core.git",
    "git@github.com:Preskok/zf3-php-di-bridge.git",
    "git@github.com:Preskok/utilities-api-consumer.git",
    "git@github.com:Preskok/console.git",
    "git@github.com:Preskok/b2b-graphql.git",
    "git@github.com:Preskok/validator.git",
    "git@github.com:Preskok/s-y-project-config.git",
    "git@github.com:Preskok/documentation.git",
    "git@github.com:Preskok/marketplace.git",
    "git@github.com:Preskok/b2b-carmarket.git",
    "git@github.com:Preskok/vivusrent-hr.git",
    "git@github.com:Preskok/abmobil-at.git",
    "git@github.com:Preskok/abmobil.git",
    "git@github.com:Preskok/likvidator.git",
    "git@github.com:Preskok/digital-inspection.git",
]


@dataclass(frozen=True)
class Ticket:
    project: str
    number: int
    change_type: str

    @property
    def key(self) -> str:
        return f"[{self.project}-{self.number}][{self.change_type}]"

    @property
    def sort_key(self) -> tuple[int, str, int]:
        return (TYPE_ORDER.get(self.change_type, 3), self.project, self.number)


@dataclass
class PullRequest:
    repo: str
    number: int
    title: str
    url: str
    author: str
    state: str
    branch: str
    approvals: int
    approving_reviewers: list[str]
    reviewers: list[str]
    tickets: list[Ticket] = field(default_factory=list)

    @property
    def has_min_approvals(self) -> bool:
        return self.approvals >= self.min_approvals

    min_approvals: int = 2


class GitHubClient:
    def __init__(self, use_gh: bool = True) -> None:
        self.use_gh = use_gh and shutil.which("gh") is not None
        self.token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")

        if not self.use_gh and not self.token:
            raise RuntimeError(
                "GitHub authentication not found. Run `gh auth login` or set GITHUB_TOKEN."
            )

    def get_paginated(self, path: str, params: dict[str, Any] | None = None) -> list[Any]:
        params = dict(params or {})
        params["per_page"] = 100

        items: list[Any] = []
        page = 1
        while True:
            params["page"] = page
            chunk = self.get(path, params)
            if not isinstance(chunk, list):
                raise RuntimeError(f"Expected a list response from {path}, got {type(chunk).__name__}")
            items.extend(chunk)
            if len(chunk) < params["per_page"]:
                break
            page += 1

        return items

    def get(self, path: str, params: dict[str, Any] | None = None) -> Any:
        if self.use_gh:
            return self._get_with_gh(path, params)
        return self._get_with_token(path, params)

    def _get_with_gh(self, path: str, params: dict[str, Any] | None = None) -> Any:
        cmd = ["gh", "api", "--method", "GET", path]
        for key, value in (params or {}).items():
            cmd.extend(["-f", f"{key}={value}"])

        completed = subprocess.run(cmd, check=False, text=True, capture_output=True)
        if completed.returncode != 0:
            raise RuntimeError(f"gh api failed for {path}: {completed.stderr.strip()}")

        return json.loads(completed.stdout)

    def _get_with_token(self, path: str, params: dict[str, Any] | None = None) -> Any:
        query = urllib.parse.urlencode(params or {})
        url = f"https://api.github.com{path}"
        if query:
            url = f"{url}?{query}"

        request = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            },
        )

        try:
            with urllib.request.urlopen(request) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"GitHub API failed for {path}: {exc.code} {body}") from exc


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="List GitHub PRs grouped by ticket and show whether each has enough approvals."
    )
    parser.add_argument("repos", nargs="*", help="Repositories as owner/repo, GitHub URL, or git remote URL.")
    parser.add_argument(
        "--repos-file",
        help="Text file with one repository per line, or JSON with a repositories[].url list.",
    )
    parser.add_argument("--state", default="open", choices=("open", "closed", "all"), help="PR state to fetch.")
    parser.add_argument("--min-approvals", default=2, type=int, help="Required approval count.")
    parser.add_argument("--only-ready", action="store_true", help="Only show PRs with enough approvals.")
    parser.add_argument(
        "--needs-my-review",
        action="store_true",
        help="Only show PRs below min approvals where the reviewer has not reviewed yet.",
    )
    parser.add_argument(
        "--reviewer",
        help="GitHub login to use with --needs-my-review. Defaults to the authenticated GitHub user.",
    )
    parser.add_argument("--fail-fast", action="store_true", help="Stop on the first repository fetch error.")
    parser.add_argument("--quiet", action="store_true", help="Hide progress output.")
    parser.add_argument("--format", choices=("markdown", "json", "html"), default="markdown", help="Output format.")
    parser.add_argument("--output", help="Write report to this file instead of stdout. Existing files are overwritten.")
    parser.add_argument("--no-gh", action="store_true", help="Do not use GitHub CLI; require GITHUB_TOKEN.")
    return parser.parse_args()


def normalize_repo(repo: str) -> str:
    value = repo.strip()
    if not value:
        raise ValueError("Empty repository value")

    if value.startswith("git@github.com:"):
        value = value.removeprefix("git@github.com:")
    elif value.startswith("https://github.com/"):
        value = value.removeprefix("https://github.com/")
    elif value.startswith("http://github.com/"):
        value = value.removeprefix("http://github.com/")

    value = value.removesuffix(".git").strip("/")
    parts = value.split("/")
    if len(parts) != 2 or not all(parts):
        raise ValueError(f"Repository must look like owner/repo: {repo}")
    return value


def is_github_repo_source(value: str) -> bool:
    return (
        value.count("/") == 1
        or value.startswith("git@github.com:")
        or value.startswith("https://github.com/")
        or value.startswith("http://github.com/")
    )


def load_repos_from_json_file(path: str) -> list[str]:
    with open(path, encoding="utf-8") as handle:
        payload = json.load(handle)

    if isinstance(payload, list):
        values = payload
    elif isinstance(payload, dict) and isinstance(payload.get("repositories"), list):
        values = [
            repository.get("url")
            for repository in payload["repositories"]
            if isinstance(repository, dict) and repository.get("type") == "git"
        ]
    else:
        raise ValueError(
            "--repos-file JSON must be a list of repository strings or contain repositories[].url."
        )

    return [value for value in values if isinstance(value, str) and is_github_repo_source(value)]


def load_repos_from_text_file(path: str) -> list[str]:
    repos = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.split("#", 1)[0].strip()
            if line and is_github_repo_source(line):
                repos.append(line)
    return repos


def load_repos_from_file(path: str) -> list[str]:
    with open(path, encoding="utf-8") as handle:
        first_non_space = handle.read(1)
        while first_non_space and first_non_space.isspace():
            first_non_space = handle.read(1)

    if first_non_space in ("{", "["):
        return load_repos_from_json_file(path)

    return load_repos_from_text_file(path)


def load_repos(args: argparse.Namespace) -> list[str]:
    repos = list(args.repos)
    if args.repos_file:
        repos.extend(load_repos_from_file(args.repos_file))
    if not repos:
        repos = list(DEFAULT_REPOS)

    normalized = []
    seen = set()
    for repo in repos:
        normalized_repo = normalize_repo(repo)
        if normalized_repo not in seen:
            normalized.append(normalized_repo)
            seen.add(normalized_repo)

    return normalized


def extract_tickets(*texts: str) -> list[Ticket]:
    tickets: dict[str, Ticket] = {}
    for text in texts:
        for match in TICKET_RE.finditer(text or ""):
            ticket = Ticket(
                project=match.group("project").upper(),
                number=int(match.group("number")),
                change_type=match.group("type").upper(),
            )
            tickets[ticket.key] = ticket
    return sorted(tickets.values(), key=lambda ticket: ticket.sort_key)


def latest_review_states(reviews: list[dict[str, Any]]) -> dict[str, str]:
    states: dict[str, str] = {}
    for review in reviews:
        user = review.get("user") or {}
        login = user.get("login")
        state = review.get("state")
        if login and state:
            states[login] = state
    return states


def fetch_pull_requests(
    client: GitHubClient,
    repo: str,
    state: str,
    min_approvals: int,
) -> list[PullRequest]:
    pulls = client.get_paginated(f"/repos/{repo}/pulls", {"state": state})
    results: list[PullRequest] = []

    for pull in pulls:
        number = int(pull["number"])
        reviews = client.get_paginated(f"/repos/{repo}/pulls/{number}/reviews")
        review_states = latest_review_states(reviews)
        approving_reviewers = sorted(
            reviewer for reviewer, review_state in review_states.items() if review_state == "APPROVED"
        )
        reviewers = sorted(review_states)

        commits = client.get_paginated(f"/repos/{repo}/pulls/{number}/commits")
        commit_messages = [
            ((commit.get("commit") or {}).get("message") or "")
            for commit in commits
        ]

        title = pull.get("title") or ""
        body = pull.get("body") or ""
        branch = (pull.get("head") or {}).get("ref") or ""
        tickets = extract_tickets(title, body, branch, *commit_messages)

        results.append(
            PullRequest(
                repo=repo,
                number=number,
                title=title,
                url=pull.get("html_url") or "",
                author=((pull.get("user") or {}).get("login") or ""),
                state=pull.get("state") or "",
                branch=branch,
                approvals=len(approving_reviewers),
                approving_reviewers=approving_reviewers,
                reviewers=reviewers,
                tickets=tickets,
                min_approvals=min_approvals,
            )
        )

    return results


def group_by_ticket(pulls: list[PullRequest]) -> dict[str, list[PullRequest]]:
    grouped: dict[str, list[PullRequest]] = defaultdict(list)
    for pull in pulls:
        if pull.tickets:
            for ticket in pull.tickets:
                grouped[ticket.key].append(pull)
        else:
            grouped["NO-TICKET"].append(pull)
    return dict(grouped)


def ticket_sort_key(ticket_key: str) -> tuple[int, str, int]:
    tickets = extract_tickets(ticket_key)
    if tickets:
        return tickets[0].sort_key
    return (TYPE_ORDER["?"], ticket_key, 0)


def render_markdown(
    grouped: dict[str, list[PullRequest]],
    min_approvals: int,
    errors: list[tuple[str, str]],
) -> str:
    lines = [f"# GitHub PR report", "", f"Minimum approvals: {min_approvals}", ""]
    if not grouped:
        lines.append("No pull requests found.")
        lines.append("")

    for ticket_key in sorted(grouped, key=ticket_sort_key):
        prs = sorted(grouped[ticket_key], key=lambda pr: (pr.repo, pr.number))
        lines.append(f"## {ticket_key}")
        for pr in prs:
            marker = "OK" if pr.approvals >= min_approvals else "WAIT"
            reviewers = ", ".join(pr.approving_reviewers) if pr.approving_reviewers else "none"
            reviewed_by = ", ".join(pr.reviewers) if pr.reviewers else "none"
            lines.append(
                f"- [{marker}] {pr.repo}#{pr.number}: {pr.title} "
                f"({pr.approvals}/{min_approvals} approvals: {reviewers}; reviewed by: {reviewed_by}) - {pr.url}"
            )
        lines.append("")

    if errors:
        lines.append("## Repository errors")
        for repo, error in errors:
            lines.append(f"- {repo}: {error}")
        lines.append("")

    return "\n".join(lines).rstrip()


def render_json(
    grouped: dict[str, list[PullRequest]],
    min_approvals: int,
    errors: list[tuple[str, str]],
) -> str:
    payload = {
        "minimum_approvals": min_approvals,
        "errors": [
            {"repo": repo, "error": error}
            for repo, error in errors
        ],
        "groups": [
            {
                "ticket": ticket_key,
                "pull_requests": [
                    {
                        "repo": pr.repo,
                        "number": pr.number,
                        "title": pr.title,
                        "url": pr.url,
                        "author": pr.author,
                        "state": pr.state,
                        "branch": pr.branch,
                        "approvals": pr.approvals,
                        "has_min_approvals": pr.approvals >= min_approvals,
                        "approving_reviewers": pr.approving_reviewers,
                        "reviewers": pr.reviewers,
                    }
                    for pr in sorted(grouped[ticket_key], key=lambda item: (item.repo, item.number))
                ],
            }
            for ticket_key in sorted(grouped, key=ticket_sort_key)
        ],
    }
    return json.dumps(payload, indent=2)


def github_repo_url(repo: str) -> str:
    return f"https://github.com/{repo}"


def render_html(
    grouped: dict[str, list[PullRequest]],
    min_approvals: int,
    errors: list[tuple[str, str]],
) -> str:
    all_pulls = [pull for pulls in grouped.values() for pull in pulls]
    unique_pulls = {(pull.repo, pull.number): pull for pull in all_pulls}.values()
    total_prs = len(unique_pulls)
    ready_prs = sum(1 for pull in unique_pulls if pull.approvals >= min_approvals)
    waiting_prs = total_prs - ready_prs
    groups_count = len(grouped)

    sections = []
    for ticket_key in sorted(grouped, key=ticket_sort_key):
        prs = sorted(grouped[ticket_key], key=lambda pr: (pr.repo, pr.number))
        rows = []
        for pr in prs:
            ready = pr.approvals >= min_approvals
            status_label = "Ready" if ready else "Waiting"
            status_class = "ready" if ready else "waiting"
            reviewers = ", ".join(pr.approving_reviewers) if pr.approving_reviewers else "none"
            reviewed_by = ", ".join(pr.reviewers) if pr.reviewers else "none"
            repo_link = html.escape(github_repo_url(pr.repo), quote=True)
            pr_link = html.escape(pr.url, quote=True)
            rows.append(
                "<tr>"
                f"<td><span class=\"status {status_class}\">{status_label}</span></td>"
                f"<td><a href=\"{repo_link}\" target=\"_blank\" rel=\"noreferrer\">{html.escape(pr.repo)}</a></td>"
                f"<td><a href=\"{pr_link}\" target=\"_blank\" rel=\"noreferrer\">#{pr.number}</a></td>"
                f"<td>{html.escape(pr.title)}</td>"
                f"<td>{pr.approvals}/{min_approvals}</td>"
                f"<td>{html.escape(reviewers)}</td>"
                f"<td>{html.escape(reviewed_by)}</td>"
                "</tr>"
            )

        sections.append(
            "<section class=\"ticket-group\">"
            f"<h2>{html.escape(ticket_key)} <span>{len(prs)} PRs</span></h2>"
            "<div class=\"table-wrap\">"
            "<table>"
            "<thead><tr><th>Status</th><th>Repo</th><th>PR</th><th>Title</th><th>Approvals</th><th>Approvers</th><th>Reviewed By</th></tr></thead>"
            f"<tbody>{''.join(rows)}</tbody>"
            "</table>"
            "</div>"
            "</section>"
        )

    if not sections:
        sections.append("<section class=\"ticket-group empty\"><h2>No pull requests found.</h2></section>")

    error_section = ""
    if errors:
        error_items = "".join(
            f"<li><strong>{html.escape(repo)}</strong>: {html.escape(error)}</li>"
            for repo, error in errors
        )
        error_section = (
            "<section class=\"ticket-group errors\">"
            "<h2>Repository Errors</h2>"
            f"<ul>{error_items}</ul>"
            "</section>"
        )

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>GitHub PR Report</title>
  <style>
    :root {{
      --bg: #f5f7fa;
      --panel: #ffffff;
      --text: #17202a;
      --muted: #64748b;
      --line: #d9e2ec;
      --ready-bg: #dcfce7;
      --ready-text: #166534;
      --waiting-bg: #fef3c7;
      --waiting-text: #92400e;
      --error-bg: #fee2e2;
      --error-text: #991b1b;
      --link: #075985;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: var(--bg);
      color: var(--text);
    }}
    header {{
      padding: 28px 32px 18px;
      background: #ffffff;
      border-bottom: 1px solid var(--line);
      position: sticky;
      top: 0;
      z-index: 1;
    }}
    h1 {{
      margin: 0 0 16px;
      font-size: 28px;
      line-height: 1.2;
      letter-spacing: 0;
    }}
    .summary {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
      gap: 10px;
      max-width: 980px;
    }}
    .summary div {{
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 10px 12px;
      background: #fbfdff;
    }}
    .summary strong {{
      display: block;
      font-size: 22px;
      line-height: 1.1;
    }}
    .summary span {{
      color: var(--muted);
      font-size: 13px;
    }}
    main {{
      padding: 24px 32px 40px;
      max-width: 1400px;
    }}
    .ticket-group {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      margin-bottom: 18px;
      overflow: hidden;
    }}
    .ticket-group h2 {{
      margin: 0;
      padding: 14px 16px;
      font-size: 18px;
      letter-spacing: 0;
      border-bottom: 1px solid var(--line);
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: center;
    }}
    .ticket-group h2 span {{
      color: var(--muted);
      font-size: 13px;
      font-weight: 500;
    }}
    .table-wrap {{ overflow-x: auto; }}
    table {{
      width: 100%;
      border-collapse: collapse;
      min-width: 920px;
    }}
    th, td {{
      padding: 11px 12px;
      border-bottom: 1px solid var(--line);
      text-align: left;
      vertical-align: top;
      font-size: 14px;
    }}
    th {{
      color: var(--muted);
      font-size: 12px;
      text-transform: uppercase;
      background: #f8fafc;
    }}
    tr:last-child td {{ border-bottom: 0; }}
    a {{
      color: var(--link);
      text-decoration: none;
      font-weight: 600;
    }}
    a:hover {{ text-decoration: underline; }}
    .status {{
      display: inline-block;
      min-width: 72px;
      text-align: center;
      border-radius: 999px;
      padding: 4px 8px;
      font-weight: 700;
      font-size: 12px;
    }}
    .status.ready {{
      background: var(--ready-bg);
      color: var(--ready-text);
    }}
    .status.waiting {{
      background: var(--waiting-bg);
      color: var(--waiting-text);
    }}
    .errors ul {{
      margin: 0;
      padding: 14px 32px 18px;
      color: var(--error-text);
      background: var(--error-bg);
    }}
    .empty h2 {{ border-bottom: 0; }}
    @media (max-width: 700px) {{
      header, main {{ padding-left: 16px; padding-right: 16px; }}
      header {{ position: static; }}
      h1 {{ font-size: 24px; }}
    }}
  </style>
</head>
<body>
  <header>
    <h1>GitHub PR Report</h1>
    <div class="summary">
      <div><strong>{total_prs}</strong><span>Total PRs</span></div>
      <div><strong>{ready_prs}</strong><span>Ready PRs</span></div>
      <div><strong>{waiting_prs}</strong><span>Waiting PRs</span></div>
      <div><strong>{groups_count}</strong><span>Ticket Groups</span></div>
      <div><strong>{len(errors)}</strong><span>Repo Errors</span></div>
      <div><strong>{min_approvals}</strong><span>Required Approvals</span></div>
    </div>
  </header>
  <main>
    {''.join(sections)}
    {error_section}
  </main>
</body>
</html>"""


def write_report(report: str, output_path: str | None) -> None:
    if output_path:
        with open(output_path, "w", encoding="utf-8") as handle:
            handle.write(report)
            handle.write("\n")
        return

    print(report)


def get_authenticated_login(client: GitHubClient) -> str:
    user = client.get("/user")
    login = user.get("login") if isinstance(user, dict) else None
    if not login:
        raise RuntimeError("Could not determine authenticated GitHub login. Pass --reviewer explicitly.")
    return login


def has_reviewer_reviewed(pull: PullRequest, reviewer: str) -> bool:
    reviewer_lower = reviewer.lower()
    return any(reviewed_by.lower() == reviewer_lower for reviewed_by in pull.reviewers)


def progress(message: str, quiet: bool = False) -> None:
    if not quiet:
        print(message, file=sys.stderr, flush=True)


def main() -> int:
    args = parse_args()

    try:
        repos = load_repos(args)
        progress(f"Loaded {len(repos)} repositories.", args.quiet)
        progress(
            "Using GitHub CLI authentication." if not args.no_gh and shutil.which("gh") else "Using token authentication.",
            args.quiet,
        )
        client = GitHubClient(use_gh=not args.no_gh)
        reviewer = args.reviewer
        if args.needs_my_review and not reviewer:
            reviewer = get_authenticated_login(client)
            progress(f"Filtering for PRs not yet reviewed by {reviewer}.", args.quiet)
        elif args.needs_my_review:
            progress(f"Filtering for PRs not yet reviewed by {reviewer}.", args.quiet)

        pulls: list[PullRequest] = []
        errors: list[tuple[str, str]] = []
        total_repos = len(repos)
        for index, repo in enumerate(repos, start=1):
            progress(f"[{index}/{total_repos}] scanning {repo}...", args.quiet)
            try:
                repo_pulls = fetch_pull_requests(client, repo, args.state, args.min_approvals)
                pulls.extend(repo_pulls)
                ready_count = sum(1 for pull in repo_pulls if pull.approvals >= args.min_approvals)
                progress(
                    f"[{index}/{total_repos}] done {repo}: {len(repo_pulls)} PRs, {ready_count} ready.",
                    args.quiet,
                )
            except Exception as exc:
                if args.fail_fast:
                    raise
                errors.append((repo, str(exc)))
                progress(f"[{index}/{total_repos}] error {repo}: {exc}", args.quiet)

        if args.only_ready:
            pulls = [pull for pull in pulls if pull.approvals >= args.min_approvals]
        if args.needs_my_review:
            pulls = [
                pull
                for pull in pulls
                if pull.approvals < args.min_approvals and reviewer and not has_reviewer_reviewed(pull, reviewer)
            ]

        progress(
            f"Finished: {len(pulls)} PRs in report, {len(errors)} repository errors.",
            args.quiet,
        )
        grouped = group_by_ticket(pulls)
        if args.format == "json":
            report = render_json(grouped, args.min_approvals, errors)
        elif args.format == "html":
            report = render_html(grouped, args.min_approvals, errors)
        else:
            report = render_markdown(grouped, args.min_approvals, errors)

        write_report(report, args.output)
        if args.output:
            progress(f"Wrote report to {args.output}.", args.quiet)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
