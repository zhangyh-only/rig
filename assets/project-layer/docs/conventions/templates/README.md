# 规范模板库（按需提升到项目规范）

> 本目录是模板库，不是当前项目的活跃规范。
> 全局 hook 默认只注入 `docs/conventions/*.md` 顶层文件；这里的模板要先按项目实际整理进顶层规范文件，才会在编码时生效。

## 使用顺序
1. 先选项目类型：`project-types/` 里挑一个最接近的模板。
2. 再选语言或资料类型：`languages/` 里挑当前项目真实存在的技术栈。
3. 把适用条目合并进顶层 `code.md`、`structure.md`，或新建顶层领域规范文件。
4. 能机器判断的 A 桶规则，同步接到 `scripts/lint-one.sh`、语言检查器或 CI。
5. 项目专属规则必须来自代码、已有规范或用户确认；不要凭模板伪造模块边界、业务术语或验收命令。

## 项目类型
| 类型 | 适合项目 | 规范重点 |
|---|---|---|
| `coding-full` | 正常研发项目、线上业务系统、框架升级 | 代码规范、结构边界、本地验证、lint/CI、变更流程 |
| `coding-light` | 脚本、小工具、demo、预研代码 | 最小结构、可重复运行、输入输出清晰、低流程负担 |
| `non-coding` | 文档、知识库、报告、面试材料、运营资料 | 来源、事实校验、目录命名、输出格式、不可编造 |
| `mixed` | 代码 + 文档/知识库/配置素材共存 | 代码与资料分区、生成物边界、双向验证 |

## 语言和资料类型
| 模板 | 适合项目 | 检查器入口 |
|---|---|---|
| `java` | Java / Spring / Maven / Gradle | Checkstyle、Spotless、ArchUnit、Maven/Gradle test |
| `typescript` | TypeScript / JavaScript / 前端应用 / Node 服务 | ESLint、Prettier、typecheck、test |
| `python` | Python 服务、脚本、数据处理、自动化工具 | ruff、mypy/pyright、pytest |
| `go` | Go 服务、CLI、基础设施工具 | gofmt、go test、golangci-lint |
| `markdown-docs` | Markdown 文档、知识库、方案材料 | markdownlint、链接检查、来源核对 |

## 跨 AI 工具原则
`rig` 的规范内容以项目仓库为单源：`AGENTS.md`、`docs/conventions/`、`scripts/lint-one.sh`、`scripts/verify-local.sh`。
Codex、Claude Code、Cursor 等工具只做适配层；新增模板时不要写成某一个 AI 工具专用。
