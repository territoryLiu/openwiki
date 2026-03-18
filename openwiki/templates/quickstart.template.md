# Quickstart

## 1. 前置条件

- Docker / Docker Compose
- 可用的 AI API Key

## 2. 克隆仓库

```bash
git clone <your-repo-url>
cd <repo-dir>
```

## 3. 修改关键配置

重点检查 `compose.yaml`：

- `CHAT_API_KEY`
- `ENDPOINT`
- `WIKI_CATALOG_API_KEY`
- `WIKI_CONTENT_API_KEY`
- `DB_TYPE`
- `CONNECTION_STRING`

## 4. 启动服务

```bash
docker-compose up -d
```

## 5. 验证服务

- 后端健康检查：`http://localhost:8080/health`
- 前端页面：`http://localhost:3000`

## 6. 常见问题

- 端口冲突：修改 `compose.yaml` 端口映射。
- API 报错：检查 Key、Endpoint、模型名是否可用。
- 数据库连接失败：检查 `DB_TYPE` 与 `CONNECTION_STRING` 是否匹配。
