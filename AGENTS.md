# AGENTS.md

本文档旨在指导 AI 助手（Agents）在本仓库中高效工作。

## 依赖管理指南

在本仓库中引入外部 Nix 依赖（非 Flake 项目）时，请务必**优先使用 `npins`**，而不是手动编写 `fetchFromGitHub` 或 `fetchTarball`。

### 核心规则
- **优先使用 npins**：除非有极特殊理由，否则所有外部 Git 仓库、Nix Channels、PyPi 包或 Tarball 依赖都应通过 `npins` 管理。
- **强制阅读文档**：在任何涉及 `npins` 的操作（添加、更新、维护、代码引入）之前，必须阅读并遵循以下文档：
    - [npins CLI 详细文档](file:///root/workspace/docs/npins/cli.md)：了解如何使用命令行工具管理依赖。
    - [npins 产物使用指南](file:///root/workspace/docs/npins/usage.md)：了解如何在 Nix 代码中正确引用和覆盖依赖。

## 开发工作流

### 添加新依赖
1. 确认依赖类型（GitHub, Git, PyPi 等）。
2. 使用 `npins add <type> ...` 命令添加。
3. 检查 `npins/sources.json` 是否已正确更新。
4. 在 Nix 代码中通过 `import <npins-path>` 引入。

### 更新依赖
1. 定期运行 `npins update` 保持依赖项最新。
2. 运行 `npins verify` 确保哈希值正确。

### 调试与覆盖
- 如果需要修改依赖项代码进行调试，请利用 `NPINS_OVERRIDE_<NAME>` 环境变量切换到本地路径，切勿直接修改 `sources.json` 中的哈希值指向不稳定的版本。

## 代码提交流程
- **提交 `sources.json`**：确保 `npins/sources.json` 的更改随代码一同提交。
- **不要提交 `default.nix` 修改**：该文件由工具自动生成，不应手动修改。
