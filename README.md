# Sync-Images-to-ali-Example

`image.txt` 放仓库根目录。

## 你要的 latest + 旧版本共存

假设现在 ACR 上：

- `kkun/nginx:latest` = 1.21 那一版

源站 `nginx:latest` 变成 1.22 后再同步，ACR 上会是：

| tag | 内容 |
|---|---|
| `kkun/nginx:latest` | 新的 1.22 |
| `kkun/nginx:1.22` | 同一份 1.22（能从源 tag / Label 读到版本时） |
| `kkun/nginx:1.21` | 覆盖前把旧 latest 再打一份版本 tag |

读版本的顺序：

1. 源镜像 tag（`nginx:1.22` 这种，不是 `latest`）
2. 镜像 Label：`org.opencontainers.image.version` / `version`
3. 旧镜像读不到版本号时，退回 `prev-latest-<digest前12位>`，旧内容仍在，只是 tag 名不是 1.21

官方 `nginx` 一般 Label 里有版本，只写 `nginx` 或 `nginx:latest` 通常就能打出 `1.21` / `1.22`。

更稳的写法是 **latest 和版本行都写上**：

```
nginx:1.21
nginx:1.22
nginx:latest
```

这样即使 Label 没有版本号，1.21 也不会丢。

## 增量 / 拆批

digest 相同跳过；`image.txt` 按 8 条分 shard 并行。copy 不会删除仓库里其它已有 tag。
