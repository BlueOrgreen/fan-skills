# Fan Skills Makefile
# 用于编排 skills 相关操作

SHELL := /bin/bash
SKILLS_DIR := $(shell pwd)/skills
TARGET_ROOT ?= $(HOME)/.claude/skills

# 默认目标
.DEFAULT_GOAL := help

# 显示帮助信息
.PHONY: help
help:
	@printf "\033[34mFan Skills Makefile\033[0m\n"
	@printf "\n"
	@printf "\033[33m用法:\033[0m\n"
	@printf "  make <target> [args]\n"
	@printf "\n"
	@printf "\033[33m可用命令:\033[0m\n"
	@printf "  install-all           安装所有 skills\n"
	@printf "  install skill=<name>  安装指定 skill\n"
	@printf "  uninstall skill=<name> 卸载指定 skill\n"
	@printf "  list                  列出所有可用的 skills\n"
	@printf "  clean                 清理所有已安装的 skills\n"
	@printf "  status                查看已安装的 skills 状态\n"
	@printf "  watch                 监听 skills 变化并自动同步\n"
	@printf "  help                  显示帮助信息\n"
	@printf "\n"
	@printf "\033[33m示例:\033[0m\n"
	@printf "  make install-all\n"
	@printf "  make install skill=fetch-request-fan-practices\n"
	@printf "  make uninstall skill=fetch-request-fan-practices\n"
	@printf "  make TARGET_ROOT=/custom/path install-all\n"

# 安装所有 skills
.PHONY: install-all
install-all:
	@printf "\033[34m正在安装所有 skills...\033[0m\n"
	@bash scripts/install-all.sh
	@printf "\033[32m完成!\033[0m\n"

# 安装指定 skill
.PHONY: install
install:
ifndef skill
	@printf "\033[33m用法:make install skill=<skill-name>\033[0m\n"
	@printf "\033[34m可用的 skills:\033[0m\n"
	@ls -1 $(SKILLS_DIR)
	@exit 1
endif
	@printf "\033[34m正在安装 skill: $(skill)\033[0m\n"
	@bash scripts/install-skill.sh $(skill)
	@printf "\033[32m完成!\033[0m\n"

# 卸载指定 skill
.PHONY: uninstall
uninstall:
ifndef skill
	@printf "\033[33m用法:make uninstall skill=<skill-name>\033[0m\n"
	@exit 1
endif
	@printf "\033[34m正在卸载 skill: $(skill)\033[0m\n"
	@bash scripts/uninstall-skill.sh $(skill)
	@printf "\033[32m完成!\033[0m\n"

# 列出所有可用的 skills
.PHONY: list
list:
	@printf "\033[34m可用的 skills:\033[0m\n"
	@for dir in $(SKILLS_DIR)/*; do \
		if [[ -d "$$dir" && -f "$$dir/SKILL.md" ]]; then \
			name=$$(basename "$$dir"); \
			desc=$$(grep -m1 "^description:" "$$dir/SKILL.md" 2>/dev/null | cut -d':' -f2- | xargs); \
			if [[ -n "$$desc" ]]; then \
				printf "  \033[32m$$name\033[0m - $$desc\n"; \
			else \
				printf "  \033[32m$$name\033[0m\n"; \
			fi; \
		fi; \
	done

# 清理所有已安装的 skills
.PHONY: clean
clean:
	@printf "\033[33m正在清理所有已安装的 skills...\033[0m\n"
	@rm -rf $(TARGET_ROOT)/*
	@printf "\033[32m清理完成!\033[0m\n"

# 查看已安装的 skills 状态
.PHONY: status
status:
	@printf "\033[34m已安装的 skills:\033[0m\n"
	@if [[ -d "$(TARGET_ROOT)" ]]; then \
		count=0; \
		for dir in $(TARGET_ROOT)/*; do \
			if [[ -d "$$dir" ]]; then \
				printf "  \033[32m$$(basename "$$dir")\033[0m\n"; \
				count=$$((count + 1)); \
			fi; \
		done; \
		if [[ $$count -eq 0 ]]; then printf "  (无)\n"; fi; \
	else \
		printf "  (目录不存在：$(TARGET_ROOT))\n"; \
	fi
	@printf "\n"
	@printf "\033[34m本地 skills:\033[0m\n"
	@count=$$(ls -1 $(SKILLS_DIR) 2>/dev/null | wc -l); \
	printf "  共 $$count 个\n"

# 监听 skills 变化并自动同步 (需要 fswatch)
.PHONY: watch
watch:
	@printf "\033[34m开始监听 skills 目录变化...\033[0m\n"
	@command -v fswatch >/dev/null 2>&1 || { \
		printf "\033[33m需要安装 fswatch: brew install fswatch (macOS) 或 apt-get install fswatch (Linux)\033[0m\n"; \
		exit 1; \
	}
	@fswatch -r $(SKILLS_DIR) | while read event; do \
		printf "\033[34m检测到变化，重新安装所有 skills...\033[0m\n"; \
		bash scripts/install-all.sh; \
	done

# 验证所有 skills 格式
.PHONY: lint
lint:
	@printf "\033[34m验证 skills 格式...\033[0m\n"
	@error=0; \
	for dir in $(SKILLS_DIR)/*; do \
		if [[ -d "$$dir" ]]; then \
			if [[ ! -f "$$dir/SKILL.md" ]]; then \
				printf "\033[33m警告：$$dir 缺少 SKILL.md\033[0m\n"; \
				error=1; \
			fi; \
		fi; \
	done; \
	if [[ $$error -eq 0 ]]; then \
		printf "\033[32m所有 skills 格式正确!\033[0m\n"; \
	fi

# 创建新的 skill 模板
.PHONY: new
new:
ifndef name
	@printf "\033[33m用法:make new name=<skill-name>\033[0m\n"
	@exit 1
endif
	@mkdir -p $(SKILLS_DIR)/$(name)
	@printf '%s\n' '---' > $(SKILLS_DIR)/$(name)/SKILL.md
	@printf '%s\n' 'name: $(name)' >> $(SKILLS_DIR)/$(name)/SKILL.md
	@printf '%s\n' 'description: <skill 描述>' >> $(SKILLS_DIR)/$(name)/SKILL.md
	@printf '%s\n' '---' >> $(SKILLS_DIR)/$(name)/SKILL.md
	@printf '\n' >> $(SKILLS_DIR)/$(name)/SKILL.md
	@printf '%s\n' '# $(name) 使用规范' >> $(SKILLS_DIR)/$(name)/SKILL.md
	@printf '\n' >> $(SKILLS_DIR)/$(name)/SKILL.md
	@printf '%s\n' '## 适用范围' >> $(SKILLS_DIR)/$(name)/SKILL.md
	@printf '\n' >> $(SKILLS_DIR)/$(name)/SKILL.md
	@printf '%s\n' '## 核心原则' >> $(SKILLS_DIR)/$(name)/SKILL.md
	@printf '\n' >> $(SKILLS_DIR)/$(name)/SKILL.md
	@printf '%s\n' '## 最佳实践' >> $(SKILLS_DIR)/$(name)/SKILL.md
	@printf "\033[32m已创建 skill 模板：$(SKILLS_DIR)/$(name)/SKILL.md\033[0m\n"
	@printf "\033[34m编辑文件并开始开发!\033[0m\n"
