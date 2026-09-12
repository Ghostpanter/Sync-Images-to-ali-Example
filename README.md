# Sync-Images-to-ali-Example

## 流程（已去掉编译 / 镜像 / Server / 注册）

旧链路：

```
编译二进制 → 打 Docker 镜像 → 起 server → 本地注册 → client -i image.txt
```

新链路：

```
本地 ./scripts/client.sh -i image.txt
        ↓  更新仓库 image.txt（push 自动跑 Action）
GitHub Actions 分片 + 增量同步到 ACR
```

不需要自建 server，触发方就是 GitHub API。

### 一次性准备

1. 安装 [GitHub CLI](https://cli.github.com/)
2. 建一个有 `repo` + `workflow` 权限的 PAT，或 `gh auth login`
3. 仓库 Secrets 里已有 `DOCKER_USERNAME` / `DOCKER_PASSWORD`

### 日常使用

```bash
chmod +x scripts/client.sh scripts/sync-one.sh scripts/sync-all.sh
export GH_TOKEN=ghp_xxx

# 上传本地列表并触发同步（等价旧命令 client -i image.txt）
./scripts/client.sh -i image.txt

# 不改列表，只再跑一遍仓库里的 image.txt
./scripts/client.sh --no-upload
```

`image.txt` 仍在仓库根目录。

### 等价命令（已装 gh 时）

gh workflow run learn-github-actions.yml --repo Ghostpanter/Sync-Images-to-ali-Example
```
