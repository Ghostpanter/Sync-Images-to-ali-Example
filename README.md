# Sync-Images-to-ali-Example

把 Docker Hub / GHCR / Quay 镜像同步到阿里云个人版 ACR。

## image.txt 放哪里

放在**仓库根目录**：

```
Sync-Images-to-ali-Example/
  image.txt
  README.md
  .github/workflows/learn-github-actions.yml
```

路径就是 `image.txt`，不要放到 `.github/` 里。

格式：一行一个源镜像。`#` 开头是注释。可选第二列指定 ACR 仓库名。

```
linuxserver/chromium
nginx:latest
ghcr.io/anduin2017/how-to-cook how-to-cook
```

默认目标：
`registry.cn-hangzhou.aliyuncs.com/kkun/<源镜像最后一段>`

## 触发

改 `image.txt` 后 push 到 `main`，或在 Actions 里手动 Run workflow。

只同步 `linux/amd64`，避免个人版 ACR 拒绝 OCI attestation
(`application/vnd.oci.empty.v1+json`)。
