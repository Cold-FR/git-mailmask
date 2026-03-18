# git-mailmask

> Rewrite your Git commit history to replace exposed email addresses with your GitHub noreply address — across one or multiple repositories, interactively.

---

## Overview

**git-mailmask** is an interactive CLI tool available for **Linux/macOS** (Bash) and **Windows** (PowerShell). It uses [`git-filter-repo`](https://github.com/newren/git-filter-repo) under the hood to rewrite commit history and replace one or more old email addresses with a new identity — typically a GitHub privacy-safe noreply address (`<id>+<username>@users.noreply.github.com`).

This is useful when you have accidentally committed with a personal or work email and want to retroactively anonymize your public commit history.

---

## Features

- 🔁 Rewrites full Git history across **all branches**
- 📋 Supports **multiple old emails** in a single run
- 🐙 Optional **GitHub CLI integration** to auto-fill your identity and browse your repositories
- ✅ **Interactive menus** — arrow keys, space to select, enter to confirm
- 📄 Paginated multi-select for large repository lists
- 🖥️ Cross-platform: Bash (Linux/macOS) and PowerShell (Windows)

---

## Requirements

### All platforms
- [`git`](https://git-scm.com/)
- [`git-filter-repo`](https://github.com/newren/git-filter-repo)

```bash
pip install git-filter-repo
```

> **Windows users:** Python and pip may not be installed by default. See the [official Python installation guide](https://docs.python.org/3/using/windows.html) to get started.

### Optional (recommended)
- [GitHub CLI (`gh`)](https://cli.github.com/) — enables auto-detection of your GitHub username/email and lets you browse and select repositories directly from your account.

```bash
# macOS
brew install gh

# Windows (winget)
winget install --id GitHub.cli

# Linux
sudo apt install gh  # Debian/Ubuntu
```

---

## Quick Install

### Linux / macOS
```bash
curl -sSL https://raw.githubusercontent.com/Cold-FR/git-mailmask/main/git_mailmask.sh -o git_mailmask.sh && chmod +x git_mailmask.sh
```

### Windows (PowerShell)
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Cold-FR/git-mailmask/main/git_mailmask.ps1" -OutFile "git_mailmask.ps1"
```

---

## Installation

Clone or download the scripts, then make the Bash script executable:

```bash
git clone https://github.com/your-username/git-mailmask.git
cd git-mailmask
chmod +x git_mailmask.sh
```

---

## Usage

### Linux / macOS

```bash
./git_mailmask.sh
```

### Windows

```powershell
.\git_mailmask.ps1
```

> **Note for Windows users:** If the script is blocked after download, unblock it first:
> ```powershell
> Unblock-File .\git_mailmask.ps1
> ```

---

## Step-by-Step Walkthrough

### 1. New Identity

You will be prompted for the replacement name and email to apply to all rewritten commits.

If the GitHub CLI is installed and authenticated, your GitHub username and noreply email are fetched automatically and offered as defaults:

```
NEW IDENTITY :
- GitHub Username [Enter for: your-username] :
- GitHub Email [Enter for: 12345678+your-username@users.noreply.github.com] :
```

Press **Enter** to accept the defaults, or type a custom value.

### 2. Old Emails to Replace

Enter all email addresses that should be replaced, one per line. Press **Enter** on an empty line to finish.

```
OLD EMAILS TO REPLACE :
   (Leave empty and press Enter to finish)
   > old.work@company.com
   > personal@gmail.com
   >
```

### 3. Repository Source

Choose how to provide the target repositories:

```
  (X) Enter a repository URL manually
  ( ) Connect to GitHub and select from my repositories
```

- **Manual URL** — paste a single HTTPS or SSH repository URL.
- **GitHub repositories** — requires the GitHub CLI. Fetches all your repos and displays a paginated multi-select menu. Use arrow keys to navigate, **Space** to toggle selection, and **Enter** to confirm.

### 4. Cleanup

The tool will:
1. Clone the repository(ies) into a temporary folder
2. Track all remote branches locally
3. Apply the mailmap rewrite via `git filter-repo`
4. Force-push all branches back to the remote
5. Delete the temporary working directory

```
=================================================
OPERATION COMPLETED SUCCESSFULLY !
=================================================
```

---

## How It Works

The script generates a [Git mailmap](https://git-scm.com/docs/gitmailmap) file mapping each old email to the new identity:

```
Your Name <new@email.com> <old@email.com>
```

This file is passed to `git filter-repo --mailmap`, which rewrites every matching commit in the full history — including all branches.

---

## ⚠️ Important Warnings

- **This rewrites Git history.** All commit SHAs will change. This is a **destructive, irreversible operation** on the remote.
- **Collaborators will need to re-clone or rebase** their local copies after a force-push.
- You must have **push access** (with force-push allowed) to the target repository.
- For organization repositories, confirm that force-push is not blocked by branch protection rules.

---

## Resetting a Local Repository After Cleanup

Once git-mailmask has force-pushed rewritten history, any existing local clone will be out of sync. To realign it without re-cloning from scratch:

```bash
git fetch origin
git reset --hard origin/main  # replace 'main' with your branch name
```

If you have multiple branches to reset:

```bash
git fetch --all
git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)
```

> **Warning:** `git reset --hard` discards all local uncommitted changes. If you have work in progress, you can stash it first:
> ```bash
> git stash
> # then after the reset:
> git stash pop
> ```

---

## Example

```bash
./git_mailmask.sh

# New identity:
#   Username: johndoe
#   Email:    12345+johndoe@users.noreply.github.com

# Old emails to replace:
#   john.doe@oldcompany.com
#   johndoe@personal.io

# Repository: https://github.com/johndoe/my-project
```

All commits previously authored or committed with the old emails will be rewritten to `johndoe <12345+johndoe@users.noreply.github.com>`.

---

## License

MIT © [Cold-FR](https://github.com/Cold-FR)