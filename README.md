# Sync-Images-to-ali-Example

`image.txt` 放仓库根目录。

## 执行方式（已优化）

1. `plan` 只输出分片编号 `[0,1,2]`，不把镜像列表塞进 matrix，避免 join/JSON 截断。
2. 每个 shard 自己读 `image.txt`，按 `index % SHARD_COUNT` 取自己的行。
3. shard 内 `xargs -P 3` 并行 copy；shard 之间最多 4 个 runner。
4. digest 相同直接 SKIP。
5. 覆盖 `latest` 前，在 ACR 内 retag 旧镜像（不重新从 Docker Hub 拉一遍）。
6. 同一次 push 重复触发会取消旧 run（`concurrency`）。
7. 手动 Run 时可改 `shard_count`、`jobs_per_shard`。

约 30 个镜像：3 个 shard × 每片 3 路并行。第二次跑未更新的会在 inspect 后跳过。

## 版本保留

`kkun/nginx:latest` 从 1.21 升到 1.22 时：

- `latest` = 1.22
- 能读到版本则另打 `1.22`，旧的打成 `1.21` 或 `prev-latest-<digest>`

要 100% 留下某个版本，在 `image.txt` 单独写一行，例如 `nginx:1.21`。
