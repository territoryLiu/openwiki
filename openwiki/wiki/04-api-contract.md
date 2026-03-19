<!-- PAGE_ID: api_contract -->

<details>
<summary>参考源码</summary>

- `openwiki/scripts/validate-lite.ps1`
- `openwiki/templates/SUMMARY.template.md`
- `openwiki/toc.yaml`

</details>

# 04 API 与接口契约

<!-- BEGIN:AUTOGEN api_contract_overview -->
## 接口基础规范

### 当前实现形态

- 当前版本为 **CLI 脚本接口**，不是 HTTP 服务。
- 入口命令：`openwiki/scripts/validate-lite.ps1`
- Base URL / Header / Token：`N/A`（本地命令执行）

参考：`openwiki/scripts/validate-lite.ps1:1-6`

### 统一结果结构（协作约定）

虽然当前产物是 Markdown 报告，但跨团队协作时建议统一外层协议：

```json
{
  "code": 0,
  "message": "PASS",
  "data": {
    "pages_checked": 6,
    "error_count": 0,
    "warning_count": 0,
    "summary_path": "openwiki/SUMMARY.md"
  }
}
```

参考：`openwiki/templates/SUMMARY.template.md`、`openwiki/scripts/validate-lite.ps1:271-281`
<!-- END:AUTOGEN api_contract_overview -->

---

<!-- BEGIN:AUTOGEN api_contract_implementation -->
## 接口详情字典（CLI 入参与出参）

### 入参（validate-lite.ps1）

| 参数 | 类型 | 必传 | 边界条件/说明 |
|---|---|---|---|
| `DocDir` | string | 否 | 默认 `docs/openwiki`，需指向包含 `toc.yaml` 与 `wiki/` 的目录 |
| `ReadmePath` | string | 否 | 默认 `README.md`，用于相对链接校验 |
| `TocPath` | string | 否 | 为空时自动回落为 `DocDir/toc.yaml` |
| `SummaryPath` | string | 否 | 为空时自动回落为 `DocDir/SUMMARY.md` |
| `FailOnError` | switch | 否 | 开启后出现错误将返回非零退出码 |

参考：`openwiki/scripts/validate-lite.ps1:1-16`、`openwiki/scripts/validate-lite.ps1:287-289`

### 出参（核心业务字段）

| 字段 | 含义 |
|---|---|
| `overall_status` | `PASS` 或 `FAIL` |
| `pages_checked` | 扫描到的 wiki 页面数量 |
| `page_id_missing` | 缺失 `PAGE_ID` 的页面数 |
| `autogen_pairs` | `BEGIN:AUTOGEN` 计数 |
| `autogen_files_with_error` | AUTOGEN 标记异常文件数 |
| `error_count` | 错误总数 |
| `warning_count` | 警告总数 |

参考：`openwiki/templates/SUMMARY.template.md`、`openwiki/scripts/validate-lite.ps1:236-281`
<!-- END:AUTOGEN api_contract_implementation -->

---

<!-- BEGIN:AUTOGEN api_contract_interfaces -->
## Mock 数据示例

### 成功示例

```json
{
  "code": 0,
  "message": "PASS",
  "data": {
    "doc_dir": "openwiki",
    "toc_path": "openwiki/toc.yaml",
    "readme_path": "README.md",
    "pages_checked": 6,
    "page_id_missing": 0,
    "autogen_pairs": 18,
    "autogen_files_with_error": 0,
    "error_count": 0,
    "warning_count": 0
  }
}
```

### 失败示例

```json
{
  "code": 1001,
  "message": "FAIL",
  "data": {
    "error_count": 2,
    "issues": [
      "[page_id] 03-dataflow-standards.md 缺少首段 PAGE_ID 标记。",
      "[toc_file] toc 页面路径不存在：wiki/99-missing.md"
    ]
  }
}
```

参考：`openwiki/scripts/validate-lite.ps1:170-175`、`openwiki/scripts/validate-lite.ps1:210-213`
<!-- END:AUTOGEN api_contract_interfaces -->

---

## 手动补充

- 若未来封装 HTTP 网关，可在此补充 OpenAPI 文档、鉴权方案与错误码字典。
