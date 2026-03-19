<!-- PAGE_ID: config_devops -->

<details>
<summary>参考源码</summary>

- `openwiki/scripts/validate-lite.ps1`
- `openwiki/SKILL.md`
- `openwiki/toc.yaml`

</details>

# 05 配置与 DevOps

<!-- BEGIN:AUTOGEN config_devops_overview -->
## 参数配置大纲（Configuration）

### 核心配置项说明

| Key | 默认值 | 作用 | 来源 |
|---|---|---|---|
| `DocDir` | `docs/openwiki` | 文档根目录（包含 `toc.yaml` 与 `wiki/`） | `validate-lite.ps1` 参数 |
| `ReadmePath` | `README.md` | README 链接校验入口 | `validate-lite.ps1` 参数 |
| `TocPath` | `DocDir/toc.yaml` | TOC 路径（可手动覆盖） | `validate-lite.ps1` 回落逻辑 |
| `SummaryPath` | `DocDir/SUMMARY.md` | 校验摘要输出路径 | `validate-lite.ps1` 回落逻辑 |
| `FailOnError` | `false` | 错误时是否返回非零退出码 | `validate-lite.ps1` 参数 |

参考：`openwiki/scripts/validate-lite.ps1:1-16`
<!-- END:AUTOGEN config_devops_overview -->

---

<!-- BEGIN:AUTOGEN config_devops_implementation -->
## 环境差异（Dev/Test/Prod）

| 环境 | DocDir 建议 | FailOnError | 目的 |
|---|---|---|---|
| Dev | `openwiki`（本地） | `false` | 快速迭代、先看告警再修 |
| Test | `openwiki`（CI 临时工作区） | `true` | 阻断结构性问题进入主分支 |
| Prod | 发布分支文档目录 | `true` | 发布前最终一致性保障 |

说明：本项目为文档工具，不包含数据库地址或模型端点切换；若接入业务系统，可在此扩展环境变量映射规则。

参考：`openwiki/scripts/validate-lite.ps1:287-289`
<!-- END:AUTOGEN config_devops_implementation -->

---

<!-- BEGIN:AUTOGEN config_devops_interfaces -->
## 打包与部署流程（DevOps）

### 本项目推荐流水线

1. `rg --files` 扫描变更范围。
2. 更新 `README/quickstart/wiki` 文档。
3. 执行 `validate-lite.ps1`。
4. 将 `openwiki/SUMMARY.md` 作为 CI 工件归档。

参考：`openwiki/SKILL.md`（固定流程 3+1）

### CI/CD 建议（GitHub Actions 示例思路）

```yaml
name: openwiki-validate
on: [push, pull_request]
jobs:
  validate:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate docs
        shell: pwsh
        run: |
          powershell -NoProfile -ExecutionPolicy Bypass -File openwiki/scripts/validate-lite.ps1 -DocDir openwiki -ReadmePath README.md -FailOnError
```

参考：`openwiki/scripts/validate-lite.ps1`
<!-- END:AUTOGEN config_devops_interfaces -->

---

## 手动补充

- 若后续引入容器化，可在此新增镜像打包、镜像扫描、部署回滚步骤。
