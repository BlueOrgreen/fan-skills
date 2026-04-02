#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
TARGET_ROOT="${SKILLS_TARGET_ROOT:-${HOME}/.claude/skills}"

mkdir -p "$TARGET_ROOT"

count=0
for dir in "$SKILLS_DIR"/*; do
  [[ -d "$dir" ]] || continue
  [[ -f "$dir/SKILL.md" ]] || continue

  skill_name="$(basename "$dir")"
  dest_dir="$TARGET_ROOT/$skill_name"
  rm -rf "$dest_dir"
  cp -R "$dir" "$dest_dir"
  echo "已安装: $skill_name"
  count=$((count + 1))
done

echo "完成，共安装 $count 个 skills。"
echo "安装目录: $TARGET_ROOT"