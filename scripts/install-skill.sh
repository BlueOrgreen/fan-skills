#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
TARGET_ROOT="${SKILLS_TARGET_ROOT:-${HOME}/.claude/skills}"

if [[ $# -lt 1 ]]; then
  echo "用法: $0 <skill-name|skill-path>"
  echo "可选环境变量: SKILLS_TARGET_ROOT=<安装目录>"
  echo "可用 skills:"
  ls -1 "$SKILLS_DIR"
  exit 1
fi

INPUT="$1"
if [[ -d "$INPUT" ]]; then
  SRC_DIR="$(cd "$INPUT" && pwd)"
else
  SRC_DIR="$SKILLS_DIR/$INPUT"
fi

if [[ ! -d "$SRC_DIR" || ! -f "$SRC_DIR/SKILL.md" ]]; then
  echo "未找到有效 skill: $INPUT"
  echo "要求目录包含 SKILL.md"
  exit 1
fi

SKILL_NAME="$(basename "$SRC_DIR")"
DEST_DIR="$TARGET_ROOT/$SKILL_NAME"

mkdir -p "$TARGET_ROOT"
rm -rf "$DEST_DIR"
cp -R "$SRC_DIR" "$DEST_DIR"

echo "已安装: $SKILL_NAME"
echo "目标目录: $DEST_DIR"