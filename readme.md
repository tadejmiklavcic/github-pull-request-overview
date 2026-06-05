# PR Report Script

`viewPr.sh` scans the configured GitHub repositories, checks pull request approvals, groups PRs by ticket, and can generate a clickable HTML report.

Tickets are detected in PR titles, PR bodies, branch names, and commit messages. Supported ticket format:

```text
[CM-1234][F]
```

Supported projects: `DI`, `CM`, `VIV`, `ABMAT`, `AB`, `BRIEFD`, `LK`.

Supported types:

- `H` hotfix
- `B` bugfix
- `F` feature

Hotfixes and bugfixes are listed before features.

## Authentication

Use one of these:

```bash
gh auth login
```

Or:

```bash
export GITHUB_TOKEN=your_token_here
```

The token needs read access to the repositories.

## Basic Usage

Run from the repository root:

```bash
cd /Users/tadej/web_dev/di
./viewPr.sh --format html --output pr-report.html
```

Open `pr-report.html` in your browser.

If `pr-report.html` already exists, it is overwritten on the next run. Generated report files are ignored by git.

## Common Commands

Create a clickable HTML report:

```bash
./viewPr.sh --format html --output pr-report.html
```

Show only PRs with at least 2 approvals:

```bash
./viewPr.sh --only-ready --format html --output pr-report.html
```

Show PRs authored by you that do not have 2 approvals yet:

```bash
./viewPr.sh --my-prs-pending-approval --format html --output my-pending-prs.html
```

Use a specific GitHub login instead of the authenticated user:

```bash
./viewPr.sh --my-prs-pending-approval --author your-github-login --format html --output my-pending-prs.html
```

Show PRs that do not have 2 approvals and where you have not approved or requested changes yet. Plain comments do not hide PRs from this list, and comments after approval do not remove that approval:

```bash
./viewPr.sh --needs-my-review --format html --output my-review-prs.html
```

Use a specific GitHub login instead of the authenticated user:

```bash
./viewPr.sh --needs-my-review --reviewer your-github-login --format html --output my-review-prs.html
```

Create a markdown report:

```bash
./viewPr.sh > pr-report.md
```

Create a JSON report:

```bash
./viewPr.sh --format json --output pr-report.json
```

Hide progress messages:

```bash
./viewPr.sh --quiet --format html --output pr-report.html
```

Scan only specific repositories:

```bash
./viewPr.sh Preskok/core Preskok/backend --format html --output pr-report.html
```

Use a custom repo file:

```bash
./viewPr.sh --repos-file repos.txt --format html --output pr-report.html
```

`repos.txt` can contain one repo per line:

```text
Preskok/core
git@github.com:Preskok/backend.git
https://github.com/Preskok/account
```

## Output

The HTML report includes:

- ticket groups
- clickable repository links
- clickable pull request links
- approval count
- approving reviewer names
- change-request reviewer names
- unresolved feedback reviewer names
- `Ready` or `Waiting` status
- `Changes Requested` status when a review requested changes
- `Waiting For Feedback` status when your unresolved review-thread comments still need a response
- repository errors, if any

Progress is printed to stderr, so redirecting the report still works:

```bash
./viewPr.sh --format html > pr-report.html
```
