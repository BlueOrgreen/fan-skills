# Fan Skills

Claude Code 技能管理系统，用于管理项目中的最佳实践规范。

## 项目描述

Fan Skills 是一个用于管理 Claude Code 技能（skills）的工具集。它提供：

- **Makefile** - 统一的技能管理命令
- **Shell 脚本** - 自动化的安装/卸载流程
- **SKILL.md 格式** - 标准化的技能文档规范
- **开箱即用的技能** - 包含两个基础技能

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