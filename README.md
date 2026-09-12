# Sync-Images-to-ali-Example

把 Docker Hub / GHCR / Quay 镜像同步到阿里云个人版 ACR。

## image.txt 放哪里

仓库根目录 `image.txt`，不要放到 `.github/`。

```
linuxserver/chromium
nginx:latest
ghcr.io/anduin2017/how-to-cook how-to-cook
python:3.9-slim
```

默认目标：`registry.cn-hangzhou.aliyuncs.com/kkun/<最后一段>`。
第二列可改 ACR 仓库名（可带 tag）。

## 已实现能力

### 1. 增量

先 `skopeo inspect` 对比源和目标 **linux/amd64 digest**。相同则跳过，不重复推。

### 2. 矩阵拆批

`plan` job 按每 8 条切 shard，多个 runner 并行。单个镜像失败不会取消其它 shard（`fail-fast: false`）。

### 3. 保留旧 tag

`skopeo copy` **不会删除** 仓库里其它 tag。另外当工作 tag（如 `latest`）内容变了，覆盖前会再打两个保留 tag：

- `仓库:<旧digest前12位>`  例如 `nginx:a1b2c3d4e5f6`
- `仓库:prev-<原tag>-UTC时间`  例如 `nginx:prev-latest-20260912-140105`

因此：

- `python:3.9-slim` 一直在，不会因为同步了别的 python tag 被删
- `nginx:latest` 更新后，上一版 latest 仍能用上面两个保留 tag 拉到

个人版 ACR 不会自动清历史 tag；真正删除只能去控制台手动删。

## 触发

只在 `image.txt` / 脚本 / workflow 变更，或 Actions 里手动 Run。
