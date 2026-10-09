#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo 'Mujian / 暮笺 — upload source to a NEW EMPTY GitHub repository'
echo 'Do not use the old miu-memo repository.'
read -r -p 'Paste the HTTPS URL (https://github.com/OWNER/mujian.git): ' repo_url
repo_url="${repo_url%$'\r'}"
if [[ ! "$repo_url" =~ ^https://github\.com/[A-Za-z0-9-]+/[A-Za-z0-9_.-]+(\.git)?/?$ ]]; then
  echo 'Expected a GitHub HTTPS repository URL, without spaces.' >&2
  exit 1
fi
if [[ "$repo_url" == */miu-memo || "$repo_url" == */miu-memo.git || "$repo_url" == */miu-memo.git/ ]]; then
  echo 'Please create a separate repository for Mujian; keep miu-memo unchanged.' >&2
  exit 1
fi
if [[ ! -d .git ]]; then git init -b main; fi
if ! git config user.name >/dev/null; then
  read -r -p 'Git commit name (your GitHub username is OK): ' author_name
  [[ -n "$author_name" ]] || exit 1
  git config --local user.name "$author_name"
fi
if ! git config user.email >/dev/null; then
  read -r -p 'Git commit email (GitHub noreply email is OK): ' author_email
  [[ -n "$author_email" ]] || exit 1
  git config --local user.email "$author_email"
fi
if git remote get-url origin >/dev/null 2>&1; then
  current_url="$(git remote get-url origin)"
  if [[ "${current_url%.git}" != "${repo_url%.git}" ]]; then
    echo 'This folder already points to another remote. No changes were pushed.' >&2
    exit 1
  fi
else
  git remote add origin "$repo_url"
fi
git add App Tests scripts docs project.yml README.md THIRD-PARTY.md .github .gitignore .gitattributes
if ! git diff --cached --quiet; then
  git commit -m 'Build Mujian native diary app'
fi
git branch -M main
echo 'Git may open your browser for GitHub sign-in. An existing login may be reused.'
git push -u origin main
echo 'Upload complete. Open the repository → Actions → Build iOS IPA → Run workflow.'
