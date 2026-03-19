<!-- PAGE_ID: qa_troubleshooting -->

<details>
<summary>参考源码</summary>

- `openwiki/scripts/validate-lite.ps1`
- `openwiki/templates/SUMMARY.template.md`
- `openwiki/quickstart.md`

</details>

# 06 测试与故障排查

<!-- BEGIN:AUTOGEN qa_troubleshooting_overview -->
## 测试指南

### 最小可执行测试

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File openwiki/scripts/validate-lite.ps1 -DocDir openwiki -ReadmePath README.md -FailOnError
```

- 通过标准：终端显示 `validate-lite: PASS` 且退出码为 `0`。
- 失败标准：任一结构错误触发非零退出码。

参考：`openwiki/scripts/validate-lite.ps1:283-289`

### 覆盖率要求（文档质量口径）

- 页面覆盖率：`toc.yaml` 中页面必须 100% 落地为实际文件。
- 标记覆盖率：Wiki 页面 `PAGE_ID` 与 `AUTOGEN` 合规率应为 100%。
- 链接覆盖率：README 相对链接应 100% 可访问。

参考：`openwiki/scripts/validate-lite.ps1:170-213`
<!-- END:AUTOGEN qa_troubleshooting_overview -->

---

<!-- BEGIN:AUTOGEN qa_troubleshooting_implementation -->
## 常见问题排查（FAQ）

1. 报错：`未找到 wiki 目录`
原因：`-DocDir` 指向错误目录。
解决：确保存在 `openwiki/wiki` 并传入正确 `DocDir`。
参考：`openwiki/scripts/validate-lite.ps1:148-150`

2. 报错：`未找到 toc 文件`
原因：`toc.yaml` 缺失或路径错误。
解决：补齐 `openwiki/toc.yaml` 或通过 `-TocPath` 指定。
参考：`openwiki/scripts/validate-lite.ps1:152-154`

3. 报错：`缺少首段 PAGE_ID 标记`
原因：页面首个有效行不是 `<!-- PAGE_ID: ... -->`。
解决：将 PAGE_ID 放到文件第一段。
参考：`openwiki/scripts/validate-lite.ps1:170-175`

4. 报错：`END:AUTOGEN 无对应 BEGIN`
原因：AUTOGEN 标记不成对。
解决：检查 BEGIN/END ID 完全一致。
参考：`openwiki/scripts/validate-lite.ps1:107-127`

5. 报错：`BEGIN/END 数量不一致`
原因：存在漏写 END 或 BEGIN。
解决：逐个区块配对并重新校验。
参考：`openwiki/scripts/validate-lite.ps1:132-135`

6. 报错：`README 链接目标不存在`
原因：README 相对路径失效。
解决：修正链接或补齐目标文件。
参考：`openwiki/scripts/validate-lite.ps1:188-200`

7. 报错：`toc 页面路径不存在`
原因：`toc.yaml` 中 `file` 条目未对应实际文件。
解决：同步 TOC 与 `wiki/` 文件名。
参考：`openwiki/scripts/validate-lite.ps1:205-213`

8. 报错：PowerShell 执行策略阻止脚本运行
原因：本地执行策略限制。
解决：使用 `-ExecutionPolicy Bypass` 运行命令。
参考：`openwiki/quickstart.md`
<!-- END:AUTOGEN qa_troubleshooting_implementation -->

---

<!-- BEGIN:AUTOGEN qa_troubleshooting_interfaces -->
## 故障定位建议

- 首先看 `openwiki/SUMMARY.md` 的错误分类（`structure`、`page_id`、`autogen`、`readme_link`、`toc_file`）。
- 再按分类回溯到对应文件并最小化改动修复。
- 修复后重复执行 `validate-lite`，直至 `PASS`。

参考：`openwiki/templates/SUMMARY.template.md`、`openwiki/scripts/validate-lite.ps1:18-31`
<!-- END:AUTOGEN qa_troubleshooting_interfaces -->

---

## 手动补充

- 可持续积累团队内真实故障案例（含触发条件、日志片段、修复 PR）。
