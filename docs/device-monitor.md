# 设备活动监控 + 实时强弹弹窗 · 落地方案

> 范围：A 手机（被监控方）后台采集使用情况并上报服务器；B（监控方）在管理端发布"强提醒"，A 手机不管在用什么 App 都会被一个系统级悬浮弹窗强制打断。
>
> 适用场景：情侣 / 家庭自用，**必须取得对方知情同意**，不可用于非法监听。

---

## 1. 目标与边界

### 1.1 必须做到
- A 手机退到后台、锁屏、清理后台后，仍能持续上报"当前前台 App、各 App 当日使用时长、屏幕亮灭"。
- B 在管理端发布强提醒后，A 手机在数十秒内强弹一个不可忽视的系统弹窗（盖在任意 App 之上），用户可"知道了"关闭。
- 全程在原生层完成，**不依赖 Flutter engine 存活**。
- 数据上报失败不影响 App 正常使用；前台 Service 自杀后系统能拉起或开机自动恢复。

### 1.2 第一期不做
- iOS 端（系统不允许长期后台监控其它 App，无对等能力，**iOS 不支持本功能**）。
- 长连接 / 真正的"实时推送"（用短轮询模拟，默认 20s 间隔）。
- 截屏 / 录屏 / 输入采集（隐私边界外，不做）。
- 跨 App 内容读取（仅读包名 + 使用时长元数据）。

### 1.3 合规底线
- 安装/启用页必须显示"该功能将持续采集设备使用信息并上报到服务器"的告知文案，由用户主动开启。
- 服务端仅保留聚合统计，不保留窗口标题、URL、剪贴板等隐私字段。
- 用户随时可在 App 内一键关闭，关闭后前台 Service 立即停止。

---

## 2. 整体架构

```
┌──────────────────────────── A 手机 ────────────────────────────┐
│                                                                │
│  Flutter UI（仅引导/开关）                                     │
│       │                                                        │
│       ├─ DeviceMonitorService（lib/core/monitor）              │
│       │   读 store.session/deviceId，调 MethodChannel          │
│       │                                                        │
│       ▼ MethodChannel "xiaotai_life/monitor"                  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ MonitorService (前台 Service, specialUse)               │  │
│  │  ├ HandlerThread 周期 tick(pollIntervalSec)             │  │
│  │  ├ 屏幕广播 ACTION_SCREEN_ON/OFF/USER_PRESENT           │  │
│  │  ├ UsageStatsHelper：当前前台 App + 当日时长             │  │
│  │  ├ MonitorHttpClient：HttpURLConnection + Bearer        │  │
│  │  └ OverlayManager：TYPE_APPLICATION_OVERLAY 强弹        │  │
│  └─────────────────────────────────────────────────────────┘  │
│         ▲                                  ▼                  │
└─────────┼──────────────────────────────────┼──────────────────┘
          │ POST /monitor/usage/report       │ GET /monitor/push/pending
          │ POST /monitor/push/ack           │
          ▼                                  ▼
┌──────────────────────── NestJS 后端 ────────────────────────┐
│  monitor 模块（仿 announcements 结构）                      │
│   ├ DeviceUsageReport 表（使用快照）                       │
│   └ ForcePush 表（强提醒，含 deliveredAt 状态）            │
└─────────────────────────────────────────────────────────────┘
          ▲                                  ▲
          │ GET /monitor/usage               │ POST /monitor/push
          │ GET /monitor/devices             │ GET  /monitor/push
          │                                  │
┌──────────────────────── React 管理端 ───────────────────────┐
│  设备使用页 + 强提醒发布/列表页                            │
└─────────────────────────────────────────────────────────────┘
```

**关键决策**：所有"采集 / 轮询 / 上报 / 强弹"全部在原生 Kotlin 前台 Service 中完成，Flutter 仅负责权限引导、开关、把当前登录 token + deviceId + baseUrl 下发给原生（写入 SharedPreferences）。这是因为 Dart engine 在 App 退后台后会被系统挂起，不能可靠后台工作。

---

## 3. 已完成（手机端，`flutter analyze` 通过）

### 3.1 原生层（Kotlin，新包 `com.xiaotai.life.monitor`）

| 文件 | 职责 |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | 新增权限 + `MonitorService`（`specialUse`）+ `MonitorBootReceiver` |
| `monitor/MonitorService.kt` | 前台 Service、屏幕广播、周期 tick |
| `monitor/UsageStatsHelper.kt` | `UsageStatsManager` 查前台 App + 今日各 App 时长 |
| `monitor/OverlayManager.kt` | 系统悬浮窗强弹（主线程 Handler、`TYPE_APPLICATION_OVERLAY`） |
| `monitor/MonitorHttpClient.kt` | `HttpURLConnection` + `org.json`，无新依赖；report / pollPending / ack |
| `monitor/MonitorPrefs.kt` | `SharedPreferences` 存 baseUrl/token/deviceId/pollInterval/已 ack id 集合 |
| `monitor/MonitorBootReceiver.kt` | `BOOT_COMPLETED` 时若已启用则恢复 Service |
| `MainActivity.kt` | 注册 `xiaotai_life/monitor` MethodChannel |

### 3.2 Flutter 层

| 文件 | 职责 |
|---|---|
| `lib/core/monitor/device_monitor_channel.dart` | 通道方法封装，平台不支持时返回安全默认值 |
| `lib/core/monitor/device_monitor_service.dart` | 聚合权限状态、读取 `store.getAuthSession()` + `getSyncDeviceId()` 启动监控 |
| `lib/features/settings/presentation/device_monitor_page.dart` | 权限引导 + 监控开关 + 厂商保活提示 |
| `lib/app/app_router.dart` / `lib/core/constants/app_routes.dart` | 新增 `/settings/device-monitor` 路由 |
| `lib/features/settings/presentation/settings_page.dart` | 设置页加"后台监控与强弹"入口 |

### 3.3 MethodChannel 协议（`xiaotai_life/monitor`）

| method | 参数 | 返回 | 说明 |
|---|---|---|---|
| `hasUsageAccess` | — | bool | 使用情况访问是否已授权 |
| `openUsageAccessSettings` | — | void | 跳转系统设置页 |
| `canDrawOverlays` | — | bool | 悬浮窗是否已授权 |
| `openOverlaySettings` | — | void | 跳转系统设置页 |
| `isIgnoringBatteryOptimizations` | — | bool | 是否已在电池白名单 |
| `requestIgnoreBatteryOptimizations` | — | void | 请求加入白名单 |
| `start` | baseUrl, token, deviceId, deviceName, pollIntervalSec | bool | 写 prefs + 启动前台 Service |
| `stop` | — | bool | 停止 Service |
| `updateToken` | token | bool | 刷新 token（避免后台过期） |
| `isEnabled` | — | bool | 上次用户的开关选择 |

---

## 4. 待完成

### 4.1 后端 NestJS（`xiaotai_server/backend/src/monitor/`）

**Prisma 模型**（追加到 `prisma/schema.prisma`）：

```prisma
model DeviceUsageReport {
  id                String   @id @default(cuid())
  userId            String
  deviceId          String
  deviceName        String?
  screenOn          Boolean  @default(false)
  foregroundPackage String?
  foregroundAppName String?
  foregroundSinceMs BigInt?
  todayUsage        Json?    // [{packageName, appName, totalMillis}]
  capturedAt        DateTime
  createdAt         DateTime @default(now())

  @@index([userId, deviceId, capturedAt(sort: Desc)])
  @@index([userId, capturedAt(sort: Desc)])
}

model ForcePush {
  id          String    @id @default(cuid())
  userId      String    // 目标用户（被弹方）
  deviceId    String?   // null = 该用户所有设备
  title       String
  content     String    @db.Text
  level       String    @default("info") // info | warn | critical
  enabled     Boolean   @default(true)
  deliveredAt DateTime?
  createdBy   String
  createdAt   DateTime  @default(now())
  expiresAt   DateTime?

  @@index([userId, deviceId, enabled, deliveredAt])
  @@index([createdAt(sort: Desc)])
}
```

**模块结构**（仿 `src/announcements/`）：

```
src/monitor/
  monitor.module.ts          // imports: [PrismaModule]
  monitor.controller.ts      // 含手机端 + 管理端两类端点
  monitor.service.ts
  dto/
    report-usage.dto.ts
    ack-push.dto.ts
    create-push.dto.ts
    query-usage.dto.ts
    query-push.dto.ts
```

在 `src/app.module.ts` 注册 `MonitorModule`。

**API 契约**（统一走 `ApiResponseInterceptor` 的 `{code, data, message}` 包装）：

#### 手机端

`POST /api/v1/monitor/usage/report` · JWT

```jsonc
// req
{
  "deviceId": "abc-123",
  "deviceName": "婷婷的小米14",
  "capturedAt": "2026-05-28T18:21:05Z",
  "screenOn": true,
  "foregroundPackage": "com.tencent.mm",
  "foregroundAppName": "微信",
  "foregroundSinceMillis": 1716913200000,
  "todayUsage": [
    {"packageName": "com.tencent.mm", "appName": "微信", "totalMillis": 5400000},
    {"packageName": "com.ss.android.ugc.aweme", "appName": "抖音", "totalMillis": 2700000}
  ]
}
// resp
{ "code": 0, "data": { "id": "..." } }
```

`GET /api/v1/monitor/push/pending?deviceId=abc-123` · JWT

```jsonc
{
  "code": 0,
  "data": [
    {"id": "ck1", "title": "该回信息啦", "content": "回我一下嘛~", "level": "warn"}
  ]
}
```

服务端筛选条件：`userId = 当前用户` AND `(deviceId = ? OR deviceId IS NULL)` AND `enabled = true` AND `deliveredAt IS NULL` AND `(expiresAt IS NULL OR expiresAt > now())`。

`POST /api/v1/monitor/push/ack` · JWT

```jsonc
// req
{"deviceId": "abc-123", "id": "ck1"}
// resp
{"code": 0, "data": {"ackedAt": "2026-05-28T18:21:30Z"}}
```

更新 `ForcePush.deliveredAt = now()`（已设置则忽略，幂等）。

#### 管理端（`@Roles('admin')`）

| 方法 | 路径 | 说明 |
|---|---|---|
| `POST` | `/api/v1/monitor/push` | 发布强提醒（body: userId, deviceId?, title, content, level, expiresAt?） |
| `GET` | `/api/v1/monitor/push` | 列表，支持按 userId / level / enabled / 时间范围筛选与分页 |
| `PATCH` | `/api/v1/monitor/push/:id` | 修改/启停 |
| `DELETE` | `/api/v1/monitor/push/:id` | 撤销 |
| `GET` | `/api/v1/monitor/usage` | 使用上报列表，支持 userId / deviceId / since 筛选 + 分页 |
| `GET` | `/api/v1/monitor/usage/latest?userId=&deviceId=` | 最近一次快照（首页用） |
| `GET` | `/api/v1/monitor/devices` | 按 (userId, deviceId) 聚合，返回 lastSeenAt / deviceName |

### 4.2 管理端 React 页面

**强提醒页**（建议路径：`/admin/monitor/push`）
- 顶部"新建强提醒"按钮 → Drawer 表单：用户下拉、设备下拉（可空=全部）、标题、内容、级别（Radio）、过期时间。
- 列表：标题 / 级别 Tag / 目标 / 创建时间 / 送达状态（未送达-黄、已送达-绿） / 操作（禁用、删除）。

**使用数据页**（建议路径：`/admin/monitor/usage`）
- 左侧设备列表（用户 + 设备名 + 最近上报时间，离线 > 5min 灰色）。
- 右侧选中设备：当前前台 App 大卡片、屏幕状态、今日各 App 时长水平条形图 Top10、最近 100 条上报时间线。

---

## 5. 鉴权与 Token 策略

### 5.1 第一期方案（已实现，复用 JWT）
- Flutter `enable()` 时把 `store.getAuthSession().accessToken` 写入 `MonitorPrefs.authToken`。
- 原生 `MonitorHttpClient` 每次请求带 `Authorization: Bearer <token>`。
- App 回前台时调 `DeviceMonitorService.syncToken()` 刷新原生侧 token。

### 5.2 已知局限
- A 手机长期不打开 App，access token 过期后，所有上报/轮询 401。
- 后台 Service 无法触发 refresh 流程（refresh 也需要服务端验证，且 refresh token 也有有效期）。
- 缓解但不根治：建议把 access token 有效期延长到 7d，配合 App 偶尔回前台刷新。

### 5.3 根治方案（建议第二期升级）
方案 A · **设备长期密钥**（推荐）：
- 用户首次启用监控时，App 调 `POST /auth/device-key` 生成长期密钥（绑定 userId + deviceId，可吊销）。
- 原生 Service 用 `X-Device-Key` 头调用 monitor 接口，后端在 monitor 端点专用 Guard 中校验。
- 用户在 App 内"关闭监控"或"踢出设备"时 revoke。

方案 B · **WebSocket + 启动握手**：建立长连后用 access token 一次性认证，连接维持期间不再校验，断线时 App 重新握手。

---

## 6. 通信策略：轮询 vs 长连接

### 6.1 第一期（轮询）
- 默认 `pollIntervalSec = 20`，可配置 10~300。
- 每 tick 顺序：采集 → POST report → GET pending → 命中则 overlay show + ack + 记入本地已 ack 集合（防重弹）。
- 屏幕开/关广播会立即触发一次 tick（即时上报状态变化）。

### 6.2 第二期升级路径
- 优先 **WebSocket**：服务端 Push `force-push` 事件给在线 deviceId；Service 心跳维持；断线自动 fallback 到轮询。
- 备选 **FCM/HMS Push**：国内可用性差，仅作为额外触达。

---

## 7. 权限与厂商保活清单

### 7.1 必需权限
| 权限 | 用途 | 授予方式 |
|---|---|---|
| `PACKAGE_USAGE_STATS` | 读前台 App + 时长 | 系统设置 → 使用情况访问 |
| `SYSTEM_ALERT_WINDOW` | 悬浮窗强弹 | 系统设置 → 显示在其他应用上层 |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE` | 长期前台 Service | manifest，自动 |
| `POST_NOTIFICATIONS` | 前台 Service 通知 | Android 13+ 弹窗，已有 |
| `RECEIVE_BOOT_COMPLETED` | 开机自启 | manifest，自动 |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | 电池白名单 | 系统弹窗 |

### 7.2 厂商保活（已写入 UI 引导）
- **小米**：自启动管理 → 允许；省电策略 → 无限制；最近任务锁定。
- **华为/荣耀**：启动管理 → 手动管理（三项全开）；电池设置 → App 启动管理。
- **OPPO/realme**：电池 → 自启动允许 + 允许后台高耗电；权限 → 关联启动允许。
- **vivo**：后台高耗电允许 + 自启动允许；i 管家 → 后台运行管理。
- **共通**：最近任务页长按锁定本 App。

---

## 8. 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| 后台 token 过期 | 上报/轮询全部 401 | 第一期延长有效期；第二期切设备长期密钥 |
| 厂商激进杀后台 | 监控中断 | 引导用户加白名单 + 锁定最近任务；前台 Service `START_STICKY` 系统重启时拉回 |
| 用户主动关闭 Service | 监控中断 | 接受，UI 显式提示"已关闭" |
| 悬浮窗权限被回收 | 强弹失败 | 每次 tick 前检查 `canDrawOverlays`，否则改本地通知降级 |
| 网络抖动 | 强提醒延迟 | 接受；UI 在管理端显示 deliveredAt 让发布者感知 |
| 隐私争议 | 法律/伦理风险 | 明确告知 + 一键关闭 + 文档中标注合规边界 |

---

## 9. 推进里程碑

1. **M1（已完成）** 手机端原生 + Flutter 引导 UI；`flutter analyze` 通过。
2. **M2（下一步）** 后端 monitor 模块 + Prisma 迁移；本地用 curl 联调 report/pending/ack。
3. **M3** 管理端两个页面；真机端到端联调（授权 → 启动 → 上报 → 发布 → 强弹 → ack）。
4. **M4** 厂商保活脚本化引导 + 文档完善 + 灰度。
5. **M5（可选）** 鉴权切设备长期密钥；通信升级 WebSocket。

---

## 10. 验收清单

- [ ] A 手机授予 3 项权限后能开启监控，状态栏出现常驻通知。
- [ ] 退到后台 / 锁屏 / 一键清理后，管理端能持续看到使用数据更新（间隔 ≤ 30s）。
- [ ] 管理端发布强提醒后，A 手机 30s 内强弹弹窗，关闭后该提醒不再重复弹（deliveredAt 写入）。
- [ ] A 手机重启后，监控服务自动恢复。
- [ ] A 手机在 App 内关闭开关，原生 Service 立即停止，状态栏通知消失。
- [ ] 网络断开期间不崩溃；恢复后能继续上报。

---

## 11. 引用代码位置

- 原生：`xiaotai_life/android/app/src/main/kotlin/com/xiaotai/life/monitor/`
- Flutter：`xiaotai_life/lib/core/monitor/`、`xiaotai_life/lib/features/settings/presentation/device_monitor_page.dart`
- 后端（待建）：`xiaotai_server/backend/src/monitor/`
- 管理端（待建）：`xiaotai_server/admin/.../monitor/`
