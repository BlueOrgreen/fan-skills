# 🤖 Agent Skills Collection

<div align="center">

![GitHub issues](https://img.shields.io/github/issues/BlueOrgreen/fan-skills)
![GitHub stars](https://img.shields.io/github/stars/BlueOrgreen/fan-skills)
![GitHub forks](https://img.shields.io/github/forks/BlueOrgreen/fan-skills)
![License](https://img.shields.io/github/license/BlueOrgreen/fan-skills)
![Made with](https://img.shields.io/badge/Made_with-Makefile-blue)

</div>

这是一个通用的 **agent skills** 仓库，用于集中管理和分发可复用的技能包（skills）。

---

## 📖 简介

本项目提供一套标准化的 skills 目录结构与安装方式，便于将技能从仓库分发到不同 AI Agent 环境。

✨ **特性：**
- 📦 统一维护技能内容与版本
- 🔄 支持团队共享与复用
- 🌍 支持跨环境安装
- 🚀 支持通过 GitHub 仓库地址直接安装

---

## 🚀 用法

### 方式一：使用 Makefile（推荐）

项目提供 Makefile 编排常用操作：

| 命令 | 说明 | 图标 |
|:-----|:-----|:-----:|
| `make help` | 查看可用命令 | 📋 |
| `make list` | 列出所有可用的 skills | 📚 |
| `make install-all` | 安装所有 skills | 📥 |
| `make install skill=<name>` | 安装单个 skill | ➕ |
| `make uninstall skill=<name>` | 卸载指定 skill | ➖ |
| `make status` | 查看安装状态 | 📊 |
| `make lint` | 验证 skills 格式 | ✅ |
| `make new name=<name>` | 创建新的 skill 模板 | 🆕 |
| `make clean` | 清理所有已安装的 skills | 🧹 |

```bash
# 自定义安装目录
make TARGET_ROOT=/custom/path install-all
```

---


## 目录结构

```
fan-skills/
├── .gitignore           # Git 忽略配置
├── Makefile             # 技能管理 Makefile
├── README.md            # 项目说明文档
├── scripts/             # 安装脚本目录
│   ├── install-all.sh   # 安装所有技能
│   ├── install-skill.sh # 安装指定技能
│   └── uninstall-skill.sh # 卸载指定技能
└── skills/              # 技能目录
    ├── fetch-request-fan-practices/
    │   └── SKILL.md     # Fetch 请求规范
    └── zustand-store-fan-practices/
        └── SKILL.md     # Zustand Store 规范
```

## 用法

### 安装所有技能

```bash
make install-all
```

### 安装指定技能

```bash
make install skill=fetch-request-fan-practices
make install skill=zustand-store-fan-practices
```

### 卸载指定技能

```bash
make uninstall skill=fetch-request-fan-practices
```

### 列出所有可用技能

```bash
make list
```

### 查看已安装技能状态

```bash
make status
```

### 验证技能格式

```bash
make lint
```

### 监听变化并自动同步

```bash
make watch
```

### 创建新技能模板

```bash
make new name=my-new-skill
```

### 显示帮助

```bash
make help
```

## 自定义安装目录

可以通过环境变量指定安装目录：

```bash
SKILLS_TARGET_ROOT=/custom/path make install-all
```

默认安装到 `~/.claude/skills`

## 内置技能

### fetch-request-fan-practices

Fetch 请求规范技能，包含：
- 统一请求封装
- 请求/响应拦截器
- 错误处理与重试机制
- TypeScript 类型安全
- 取消请求管理

### zustand-store-fan-practices

Zustand Store 使用规范技能，包含：
- useShallow 正确用法
- getState 使用边界
- 传统单 Store 模式
- Slice 模式（推荐）
- subscribeWithSelector 订阅

## 添加新技能

1. 在 `skills/` 目录下创建新文件夹
2. 添加 `SKILL.md` 文件，格式如下：

```markdown
---
name: your-skill-name
description: 技能描述
---

# 技能内容
```

3. 运行 `make install-all` 或 `make install skill=your-skill-name`

---

## 📝 许可证

<div align="center">

[MIT License](LICENSE) © 2026 TaueFenCheng

</div>
