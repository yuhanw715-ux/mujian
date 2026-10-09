#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1 || [[ -n "$(git rev-parse --show-prefix)" ]]; then
  echo '请把新版源码中的文件复制到之前上传成功的 Mujian 文件夹，再运行此脚本。' >&2
  echo '原文件夹应保留原来的 Git 仓库信息；不要在新解压的独立文件夹里运行更新脚本。' >&2
  exit 1
fi
remote_url="$(git remote get-url origin)"
if [[ "$remote_url" == */miu-memo || "$remote_url" == */miu-memo.git ]]; then
  echo '这里是旧的待办项目。请回到暮笺的 Mujian 文件夹操作。' >&2
  exit 1
fi
branch="$(git branch --show-current)"
if [[ "$branch" != main ]]; then
  echo '当前不在 main 分支，已停止上传。请把这条提示发给 Miu。' >&2
  exit 1
fi
git add App Tests scripts docs project.yml README.md THIRD-PARTY.md .github .gitignore .gitattributes
if ! git diff --cached --quiet; then
  git commit -m 'Mujian 1.2: sealed Miu previews, diary collections and writing labels'
fi
git push origin main
echo '更新已上传。打开原来的暮笺仓库 → Actions → Build iOS IPA → Run workflow。'
