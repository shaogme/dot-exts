# npins 产物使用指南

本文件详细介绍了如何在 Nix 项目中使用 `npins` 生成的产物（通常位于 `npins/` 目录下）。

## 1. 导入 npins

在 Nix 表达式中，你可以通过 `import` 包含 `default.nix` 的 `npins` 目录来加载所有的依赖项。

```nix
let
  sources = import ./npins;
in
{
  # 现在可以通过 sources.<name> 访问依赖
}
```

## 2. 访问依赖项 (Pin)

`npins` 生成的每个依赖项（Pin）都可以直接作为**路径字符串**使用。这是因为它实现了 `outPath` 属性。

### 示例：导入 NixOS 模块
如果你的依赖项（如 `disko`）是一个包含 NixOS 模块的仓库，你可以这样导入它：

```nix
{
  imports = [
    "${sources.disko}/module.nix"
  ];
}
```

### 示例：作为包 (Package) 使用
你也可以直接引用其路径，例如在 `environment.systemPackages` 中：

```nix
environment.systemPackages = [
  sources.some-custom-tool
];
```

## 3. 高级用法：函数式调用

`npins` 的每个依赖项实际上是一个**函子 (Functor)**。你可以通过传递 `pkgs` 参数来显式指定使用的 fetcher 实现。

```nix
let
  sources = import ./npins { inherit pkgs; };
in
# 此时所有的 fetcher 都会使用传入的 pkgs 中的版本
```

或者针对单个依赖：

```nix
let
  sources = import ./npins;
  mySource = sources.disko { inherit pkgs; };
in
# ...
```

> [!NOTE]
> 对于大多数情况，直接使用 `sources.name` 即可，`npins` 会自动处理下载和路径计算。

## 4. 开发调试：覆盖依赖 (Override)

在开发过程中，你可能希望使用本地的源码路径来替代 `npins` 自动下载的版本。`npins` 支持通过环境变量进行覆盖。

**环境变量格式**：`NPINS_OVERRIDE_<NAME>`

### 示例
如果你想将 `disko` 覆盖为本地路径 `/home/user/src/disko`：

```bash
export NPINS_OVERRIDE_disko=/home/user/src/disko
nixos-rebuild switch ...
```

`npins` 在运行时会检测到该变量，并打印类似如下的提示：
`trace: Overriding path of "disko" with "/home/user/src/disko" due to set "NPINS_OVERRIDE_disko"`

## 5. 项目中的实际案例

在 `hardware/disk-config/btrfs/default.nix` 中：

```nix
{ pkgs, ... }:
let
  # 加载 npins 依赖
  sources = import ../npins;
in
{
  nixosModule = { lib, config, pkgs, ... }: {
    # 使用 disko 依赖中的模块
    imports = [ "${sources.disko}/module.nix" ];

    # ... 其他配置
    config = lib.mkIf config.exts.hardware.disk.enable {
      # 使用 disko 提供的配置项
      disko.devices.disk.main = {
        # ...
      };
    };
  };
}
```

## 6. 维护建议

- **提交 `sources.json`**：务必将 `npins/sources.json` 提交到 Git 仓库，它记录了确切的版本和哈希。
- **定期更新**：使用 `npins update` 保持依赖项处于最新状态。
- **不要手动修改 `default.nix`**：该文件由 `npins` 自动生成，手动修改会在下次执行 `npins init` 或升级时被覆盖。
