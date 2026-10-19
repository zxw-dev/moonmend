# MoonMend（月补）：MoonBit 包 API 迁移与安全升级工具

## 1. 项目名称

MoonMend（月补）

## 2. 项目简介

MoonMend 是一个面向 MoonBit 生态的开发者工具。它比较同一软件包两个版本生成的 `.mbti` 公共接口，识别函数、结构体、枚举、trait、类型别名、常量和 impl 的新增、删除与修改，并给出 breaking/non-breaking 兼容性等级。MoonMend 可以生成 JSON、Markdown 和迁移计划，对高置信度函数或结构体重命名生成真实源码 diff；应用后可自动执行 `moon check` / `moon test`，验证失败时恢复原文件。

## 3. 项目方向与通用性

项目方向为“开发者工具”，聚焦 MoonBit 包升级、接口兼容和开发体验。

MoonMend 不绑定某个具体包，而是基于 MoonBit 的标准接口文件和程序解析能力工作，因此可服务于 MoonBit 官方包、社区库和应用项目。其接口模型、变更分类和迁移规则均可扩展，目标是为整个 MoonBit 生态提供通用的版本升级基础设施。

## 4. 预期使用场景

1. **软件包维护者发布新版本**：维护者比较旧版和新版 `.mbti`，自动生成破坏性变更清单，并将其整理为发布说明或迁移指南，降低下游用户的升级成本。
2. **应用项目升级依赖**：应用更新 `moon.mod.json` 中的依赖版本后，MoonMend 生成迁移计划和补丁，自动修复高置信度 API 改名或模块移动，并明确列出需要人工处理的签名变化。
3. **CI 中检查依赖升级风险**：持续集成任务在依赖版本变化时运行 MoonMend，发现破坏性接口变化后输出 JSON/Markdown 报告，并可按配置返回失败状态，阻止不兼容变更未经评估进入主分支。

## 5. 拟实现的核心功能

1. 读取并规范化两个版本的 `.mbti` 公共接口快照。
2. 分类输出函数、结构体、枚举、trait、类型别名、常量和 impl 的变化。
3. 基于确定性规则给出迁移动作和 breaking/non-breaking 等级。
4. 对高置信度重命名生成真实统一 diff，支持预览、应用和失败回滚。
5. 调用 `moon check` / `moon test` 验证迁移结果，并生成 JSON 与 Markdown 报告。
6. 提供 `diff`、`plan`、`migrate` 子命令和 `--fail-on-breaking` CI 门禁。

## 6. 项目性质与参考来源

本项目为原创项目，不是现有项目的移植。

## 7. 移植项目说明

不适用。项目使用 [moonbitlang/x](https://github.com/moonbitlang/x) 和 [moonbitlang/async](https://github.com/moonbitlang/async)，二者均为 Apache-2.0；具体用途已在 README 中说明。

## 8. GitHub 仓库

https://github.com/zxw-dev/moonmend
