# Contract: nbvpn 连接信息与 CLI 面

> 需求短名：`nbvpn`  
> 冻结: **是**（2026-08-14，spec 初冻；变更须追加「变更记录」并更新 STATUS）  
> 对齐：`01-spec.md`、`docs/dev-workflow/context/`  
> 验收引用：S01 SP-*；实现验收 S02 SV-* / S03 CL-*

## 变更记录

| 日期 | 变更 | 作者 |
|------|------|------|
| 2026-08-14 | 初冻 Profile v1、URI、二维码、文件、CLI 命令面 | spec |
| 2026-08-14 | §4 补充：终端 QR 渲染要求（方模块/可扫）+ 可选旁路导出 `peers/<id>.png`（内容仍为完整 URI；不改变 URI/JSON 契约） | impl+qa |
| 2026-08-25 | §1 可选字段 `server.endpointV6` / `server.ipv6Enabled`；CLI `config set endpoint-v6` / `config set ipv6`；连接时单 Endpoint（启用则优先 V6） | impl |

---

## 1. NbVpnProfile v1（规范载荷）

唯一逻辑模型。配置文件、URI、二维码必须由此生成/解析。

### 1.1 JSON Schema（逻辑字段）

```json
{
  "v": 1,
  "name": "string",
  "client": {
    "privateKey": "base64-wireguard-private-key",
    "address": ["10.8.0.2/32"],
    "dns": ["1.1.1.1", "1.0.0.1"],
    "mtu": 1280
  },
  "server": {
    "publicKey": "base64-wireguard-public-key",
    "endpoint": "203.0.113.10:51820",
    "endpointV6": "[2001:db8::1]:51820",
    "ipv6Enabled": true,
    "allowedIPs": ["0.0.0.0/0", "::/0"],
    "persistentKeepalive": 25,
    "presharedKey": null
  }
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `v` | number | 是 | 主版本；当前仅 `1` |
| `name` | string | 是 | 建议显示名；客户端可改本地名 |
| `client.privateKey` | string | 是 | 客户端私钥（傻瓜式签发）；WireGuard 标准 base64 |
| `client.address` | string[] | 是 | 客户端隧道地址，CIDR |
| `client.dns` | string[] | 是 | 至少 1 个 |
| `client.mtu` | number | 否 | 缺省由客户端/平台默认；建议 1280 |
| `server.publicKey` | string | 是 | 节点公钥 |
| `server.endpoint` | string | 是 | 主 `host:port`（host 可为域名或 IP；通常 IPv4） |
| `server.endpointV6` | string | 否 | 可选 IPv6（或备用）endpoint；须为 `host:port`，IPv6 字面量用 `[addr]:port` |
| `server.ipv6Enabled` | boolean | 否 | 缺省/省略 = false；为 true 且 `endpointV6` 非空时，客户端连接使用 `endpointV6` 作为唯一 WireGuard Endpoint |
| `server.allowedIPs` | string[] | 是 | 路由 |
| `server.persistentKeepalive` | number | 否 | 默认 25 |
| `server.presharedKey` | string\|null | 否 | 可选 PSK |

**禁止**在 Profile 中放入服务端私钥。

**向后兼容：** 旧客户端/旧 profile 无 `endpointV6`/`ipv6Enabled` 时行为不变。WireGuard 每个 peer **仅一个** Endpoint；双栈不是同时连两个地址，而是由启用状态选择其一。

第二公网 IPv4：仍通过 `nbvpn config set endpoint` 切换主 endpoint（无独立 `endpoint-v4-2` 字段）。

### 1.2 校验规则

- JSON 解析失败 → 拒绝导入  
- `v !== 1` → 若 `v > 1` 提示升级客户端；若 `v < 1` 或缺失 → 拒绝  
- 缺必填字段 / 密钥长度非法 / `endpoint` 无端口 → 拒绝并给出字段级错误  
- 若存在 `endpointV6`：须为合法 `host:port`（IPv6 须 `[addr]:port`）  
- `allowedIPs`、`address`、`dns` 不得为空数组  

### 1.3 等价性

同一 peer 的三形态解码后，规范化 JSON（稳定键序、无多余空白差异以外）逻辑字段必须一致。允许：客户端保存时增加本地元数据（`localName`、`id`、`addedAt`），**不得**改写上表连通字段除非用户显式重新导入。

---

## 2. 配置文件

| 项 | 约定 |
|----|------|
| 主格式 | `*.nbvpn.json`，内容 = NbVpnProfile v1 对象 |
| 编码 | UTF-8，无 BOM |
| 附属格式 | 可由 Profile 生成标准 WireGuard `*.conf`（`[Interface]` + `[Peer]`）；客户端 **must** 支持 `.nbvpn.json`；`.conf` 导入为 should（若实现，须映射回同等连通参数） |

---

## 3. URI

### 3.1 形式

```text
nbvpn:1?<base64url(JSON)>
```

- scheme：`nbvpn`  
- path/version 标记：`1` 与 JSON 内 `v:1` 一致  
- `?` 后为 **base64url**（无填充）编码的 UTF-8 JSON 字节  
- 整串须可复制；尽量避免换行；终端展示过长时可提示改用 `--file` 或二维码  

### 3.2 示例（示意，非真实密钥）

```text
nbvpn:1?eyJ2IjoxLCJuYW1lIjoiTXktTm9kZSIsImNsaWVudCI6e30sInNlcnZlciI6e319
```

### 3.3 错误码（客户端导入）

| 码 | 含义 |
|----|------|
| E_URI_SCHEME | 非 `nbvpn:` |
| E_URI_VERSION | 版本不支持 |
| E_URI_DECODE | base64/JSON 失败 |
| E_PROFILE_INVALID | 字段校验失败 |
| E_PROFILE_UNSUPPORTED | `v` 过高需升级 |

---

## 4. 二维码

| 项 | 约定 |
|----|------|
| 内容 | **完整 URI 字符串**（与 §3 同一字节序列） |
| 纠错 | 建议 Q 级（实现可调，以可扫为准）；终端渲染可为较低纠错以缩小矩阵，PNG 建议 Q |
| 终端渲染 | Unicode 半块字符（`█▀▄`），强制深色模块+浅色底（避免深色主题反色）；保持 quiet zone；模块近似方形（半块打包适配 ~2:1 字符单元） |
| 终端局限 | 长 URI 矩阵较宽，窄 SSH 会话可能折行导致不可扫；必须提示改用 `--file` / `--uri` / PNG |
| 可选 PNG | `nbvpn show` 在写入 `.nbvpn.json` 时可旁路写出同载荷 PNG：`peers/<id>.png`（权限建议 0600）；**不**替代三形态中的任一形态，仅为可靠扫码通道 |

---

## 5. CLI 命令面（服务端）

与 `01-spec.md` FR-S 命令表一致，作为契约能力列表：

`install` · `show` · `config` · `status` · `start` · `stop` · `restart` · `peer add` · `peer list` · `peer revoke` · `peer delete` · `uninstall` · `help`

**`peer revoke` vs `peer delete`:** revoke disables credentials and keeps a revoked row in `peer list` (audit); delete removes the peer record and all files. Neither recycles the peer's VPN IP into `NextClientIP`.

另：**设置 endpoint** 能力必须具备（`nbvpn config set endpoint <host[:port]>`）。  
可选双栈：`nbvpn config set endpoint-v6 <[ipv6]|host[:port]>`、`nbvpn config set ipv6 on|off`；`nbvpn config` 须显示主 endpoint、endpointV6 与 ipv6 启用状态。

### 5.1 `show` 输出约定

默认 `--all` 顺序：

1. 简短说明（含「勿泄露」警告一行）  
2. URI（单行）  
3. 配置文件路径（写入临时或 `/var/lib/nbvpn/peers/<id>.nbvpn.json` 一类路径，具体路径实现回写 stack）  
4. （可选）QR PNG 路径（`peers/<id>.png`，与 URI 同载荷）  
5. 终端二维码（其后可跟窄终端/不可扫时的 fallback 提示）  

退出码：`0` 成功；非 0 失败且 stderr 可读。

### 5.2 权限与密钥边界

| 数据 | `config`/`status` | `show`/peer 文件 | 日志默认 |
|------|-------------------|------------------|----------|
| 服务端私钥 | 禁止 | 禁止 | 禁止 |
| 客户端私钥 | 禁止 | 允许（仅对应该 peer 的 show/导出） | 禁止 |

---

## 6. 客户端持久化（逻辑）

```text
ServerEntry {
  id: uuid,
  localName: string,
  profile: NbVpnProfile,
  createdAt, updatedAt
}
```

- 存储：平台安全存储或加密文件  
- 同时仅一个 `connected`  

---

## 7. 权限 / 账号

- 无中心账号 API  
- 无节点发现 API  
- store 仅为静态/对象存储分发，不在本契约定义业务登录  

---

## 8. 验收引用

| 契约项 | 规格/竖切 |
|--------|-----------|
| Profile/URI/QR/文件 | SP-01；SV-03/04；CL-02/03/04/10 |
| CLI 面 | SP-02；SV-05/06 |
| 无账号无默认节点 | SP-03；CL-01/08；ST-04/05 |

---

## 修订说明

实现若需改字段名或 URI 形，**先**改本文件变更记录与 `STATUS.md`，再改代码；禁止口头改契约。
