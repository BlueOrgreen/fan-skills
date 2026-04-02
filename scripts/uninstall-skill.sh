#!/usr/bin/env bash
set -euo pipefail

TARGET_ROOT="${SKILLS_TARGET_ROOT:-${HOME}/.claude/skills}"

if [[ $# -lt 1 ]]; then
  echo "用法: $0 <skill-name>"
  echo "可选环境变量: SKILLS_TARGET_ROOT=<安装目录>"
  exit 1
fi

SKILL_NAME="$1"
DEST_DIR="$TARGET_ROOT/$SKILL_NAME"

if [[ ! -d "$DEST_DIR" ]]; then
  echo "未安装或目录不存在: $DEST_DIR"
  exit 0
fi

rm -rf "$DEST_DIR"
echo "已卸载: $SKILL_NAME"
echo "目标目录: $TARGET_ROOT"