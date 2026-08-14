# 上传后更新 releases.json 清单

> `apps/store` = 落地页 UI。安装包与校验和文件放在 **OpenList**，不放在本仓库静态站。

## 已知

| 项 | 值 |
|----|-----|
| OpenList 基址 | `http://154.37.213.245:5244` |
| 浏览入口 | `http://154.37.213.245:5244/store` |
| 落地页清单 | `apps/store/public/releases.json` |

## 上传完成后再做（本清单不代替上传）

1. 在 OpenList 上确认每个产物的实际路径（例如 `/store/VPN/nbvpn/...`）。
2. 复制**可下载直链**（常见为 `{base}/d/<路径>`，以站点实际为准）。
3. 对每个文件计算 SHA256，写入对应条目的 `sha256`。
4. 编辑 `apps/store/public/releases.json`：
   - 填 `url` / `version` / `filename` / `sha256`
   - 服务端填 `installCommand`（指向 OpenList 上的 `install.sh` 直链）
   - 将 `status` 从 `pending_upload` 改为 `ready`
   - 更新顶层 `meta.status` 与 `updatedAt`
5. `cd apps/store && npm run build`，部署落地页 `dist/`（落地页本身仍可单独托管；**包不经落地页服务器托管**）。

## 可选：本地生成 SHA256

```bash
# 对已下载/本地构建产物
shasum -a 256 path/to/artifact
```

## 不要做

- 不要填写假 `example.com` / 重复字符假 SHA。
- 不要声称 OpenList 上已有文件，除非你刚确认可下载。
