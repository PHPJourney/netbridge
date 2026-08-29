# NetBridge Obfs Transport — 自研传输层协议设计

> 状态：v0.1 设计稿（2026-08-30）  
> 目标：WireGuard 数据面不变，自研传输层，伪装成浏览器 HTTPS 访问，抗 DPI。

## 1. 威胁模型

对抗 GFW 深度包检测的四层手段：

| 层 | 手段 | 本协议对策 |
|----|------|-----------|
| 指纹层 | 识别协议握手固定特征 | TLS 1.3 握手 + 真实证书 + 浏览器级 ClientHello |
| 行为层 | 流量统计特征（时长/方向比/包间隔） | 应用数据包填充整形 + 心跳伪装 |
| 主动探测 | 假握手试探服务端 | 认证先行；未认证连接返回伪装网页 |
| 端点层 | 封 IP/域名 | 协议层无解；运维层面换 IP（不在本协议范围） |

## 2. 架构

```
NetBridge 客户端
  ├─ WireGuard 数据面（Endpoint = 127.0.0.1:51822）
  ├─ 任意 TCP 服务本地端口映射（-L tcp://33890:127.0.0.1:3389 …）
  │     └─ obfs-transport client（UDP/TCP 复用 N 条并行 TLS 流）
  │          ├─ 隧道 1（WG 数据报 round-robin + 部分 TCP 流）
  │          ├─ 隧道 2（同上）
  │          ├─ …（默认 4 条，--channels 可调）
  │          └─ TCP 443，TLS 1.3（SNI = 自备域名，真证书）
  │               └─ obfs-transport server（VPS，每条隧道独立处理）
  │                    ├─ 还原 WG 包 → 127.0.0.1:51820（WireGuard）
  │                    └─ TCP connect → 按目标建连（RDP 3389 / SSH 22 / 任意服务）
```

- 数据面：WireGuard 原样（密钥、握手、隧道语义零改动）
- 传输层：自研，Go 实现，客户端/服务端同一代码库
- 移动端：gomobile 打包（Android AAR / iOS xcframework），复用 wireguard-go 的集成路径
- **纯远程桌面/端口转发场景可以完全不要 WireGuard**：客户端只跑 `-L` 映射

### 2.1 多通道（并行隧道）

- 客户端维护 **N 条独立 TLS 隧道**（默认 4），每条独立认证、独立重连
- WG 数据报按 round-robin 分发（UDP 语义乱序容忍，无需保序）
- 每条 TCP 转发流绑定一条隧道（流内保序）
- 单隧道死亡：自动剔除、流量切换存活隧道、后台重建补齐 N 条
- 收益：带宽聚合（N 条独立拥塞控制）、抗单连接 RST/限速、**连接形态与浏览器并行连接行为一致**（更自然的伪装）
### 2.2 多入口（单 IP 多端口）

- 服务端在**同一 IP 上监听多个入口端口**（如 `:443 :8443 :2053`，`--ports` 配置）
- 客户端入口池 = `domain × 端口`；每条隧道（重新）建立时**随机选择入口**，
  最近失败（30s 冷却）的入口被降权，全部失败才强制重试
- 单端口被封/失效：流量自动切到存活入口，被封端口冷却后自动回归
- 收益：抗端口级封锁；与多通道正交组合（N 通道 × M 入口的流量矩阵）
- 服务端零感知：每个端口就是一条普通监听，现有 handleConn/bridge 原样处理

## 3. 握手设计（指纹层）

### 3.1 TLS 1.3 + 真证书

- 服务端证书：**Let's Encrypt 签发的自有域名证书**（`acme.sh`/`certbot` 自动续期）
- 握手全程合法：GFW 被动与主动 MITM 看到的都是一个正常 HTTPS 站点
- **不用自签证书**：证书在握手中明文传输，自签 + 伪装 SNI 会被主动探测识破
- **不做 Reality 偷证书**：v1 不做；自备域名成本低，隐蔽性等价于"访问一个真实小站"

### 3.2 ClientHello 指纹

- 客户端用 Go `crypto/tls` 构建 ClientHello，配置目标为**主流浏览器指纹**：
  - cipher suites 顺序、extensions 顺序按 Chrome 126+ 模板
  - `ALPN: h2, http/1.1`（同 Chrome）
  - GREASE 扩展随机填充
- v1 接受"Go TLS 默认指纹"（识别收益低），指纹模板作为可配置项演进

### 3.3 伪装路径（HTTP 层）

- TLS 握手完成后，客户端先发一条伪装 HTTP 请求（如 `GET /favicon.ico`），
  服务端按会话状态决定：已认证 → 切隧道模式；未认证 → 返回真实 404 页面。
- 目的：让服务端行为对"只做握手不认证"的探测者完全像一个正常网站。

## 4. 会话认证（防主动探测）

TLS 握手完成后、隧道开启前，客户端发认证帧：

```
auth_frame = version(1B) | type(1B)=0x01 | nonce(8B) | ts(8B) | tag(32B)
tag = HMAC-SHA256(key = PSK, msg = nonce || ts || "nbvpn-obfs-v1")
```

- `PSK`：安装时生成（256-bit 随机），存于服务端 state 与客户端 profile
- 验证：`|now - ts| ≤ 120s` 且 tag 正确；失败 → 记日志、返回伪装 404、断开
- 防重放：nonce 由服务端在 TLS 层下发（认证挑战），不依赖时钟同步精度
- 认证成功后，双方进入隧道模式，此后所有应用数据为 WG 封装帧

## 5. 封装帧格式（数据面）

认证通过后，TLS 应用数据流内为连续帧：

```
frame = magic(1B)=0xE7 | type(1B) | len(2B, big-endian) | padlen(2B) | payload | padding(padlen)
```

| type | 含义 |
|------|------|
| 0x00 | 认证挑战（server→client，8B nonce） |
| 0x01 | 认证应答（client→server，nonce+ts+HMAC tag） |
| 0x10 | WireGuard UDP 数据报 |
| 0x11 | 心跳（无 payload） |
| 0x12 | 会话续期请求（v1 保留） |
| 0x20 | TCP connect 请求（client→server：connID + 目标 host:port） |
| 0x21 | TCP data（双向：connID + 流数据） |
| 0x22 | TCP close（双向：connID） |

- `len` = payload 字节数；`padlen` = 尾部随机填充长度，接收端按 padlen 剥离，
  **WireGuard 只会看到原始数据报**
- TCP 帧在同一 TLS 流上多路复用：connID(2B) 区分连接；客户端本地监听
  （`-L tcp://33890:127.0.0.1:3389` 式端口映射），服务端按目标地址建连
- 帧尾填充做流量整形（见 §6），不做帧间 padding（保持解析无状态）
- **WG 包不重传**：TCP 层保证交付；丢包时上层 WG 自行重握手
- 心跳：每 15–45s 随机间隔发送，模拟网页长连接的间歇性交互

## 6. 流量整形（行为层）

- 出站 WG 包（握手 ~148B，数据 ~1420B）封装后按目标分布添加尾部填充：
  - 40% 概率填充至 300–600B（模拟 API 请求）
  - 40% 概率填充至 900–1300B（模拟响应负载）
  - 20% 概率不填充（WG 数据包本身接近 MTU 分布）
- 填充在帧层剥离（padlen 字段），对 WG 透明
- 方向比整形：认证后双方心跳保持双向小包流，避免"单向大流量"特征
- TCP_NODELAY 关闭 Nagle，包边界即时发送（WG 对手时延敏感）

## 7. 会话管理

- 客户端断线：指数退避重连（1s → 2s → 4s → … 封顶 60s），TLS 会话恢复优先
- 服务端闲置回收：无数据 5 分钟且无心跳 → 断开（防探测者挂长连接观察）
- 多客户端：每连接独立会话状态；同 PSK 共享（自用单 PSK 即可）

## 8. 实现计划

| 阶段 | 内容 | 产物 |
|------|------|------|
| P1 | Go 库：client/server 模式、握手、认证、封装帧、整形 | `server/nbvpn/internal/obfstransport/` |
| P2 | 服务端集成：`nbvpn obfs2 install`（证书签发 + systemd + state） | CLI 子命令 |
| P3 | 客户端 CLI（桌面）：本地 UDP→TLS 转发进程 | 独立二进制 / `nbvpn` 客户端模式 |
| P4 | 移动端：gomobile AAR/xcframework，NetBridge 内嵌 | clients/netbridge 集成 |
| P5 | 实测：大陆直连境外节点，观察生存期与吞吐 | 验证报告 |

## 9. 已知取舍（诚实边界）

- **TCP-in-TCP 退化**：WG over TCP 有 head-of-line blocking 叠加，弱网下性能劣于裸 UDP；
  QUIC 传输（HTTP/3 形态）是后续演进方向
- **域名可见**：SNI 明文暴露自有域名；域名被定向封锁则换域名（成本低）
- **指纹维护**：浏览器 ClientHello 模板需跟随主流浏览器更新，属长期维护项
- 密码学：仅使用 TLS 1.3 / HMAC-SHA256 现成实现，不自研原语
