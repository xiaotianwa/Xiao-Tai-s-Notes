# 婷婷的小笨笔记实际未实现功能清单（代码审阅版）

审阅日期：2026-06-03  
审阅方式：以当前仓库代码为准，交叉检查 Flutter App、NestJS 后端、React 管理端、Prisma schema、既有审查文档和验证命令结果。  
审阅目标：只记录“代码里还没有闭环”的功能、质量门和产品能力；已经实现的功能不重复展开。

## 一、结论摘要

当前项目已经具备私有双人生活记录 App 的主干：账号密码登录、本地 JSON 存储、同步队列、日记、备忘、提醒、纪念日、地点、情侣 100 件事、本周目标、记账、小笨漫画、音乐、天气、公告、版本更新、媒体上传、AI 助手、管理端后台和后端 API。

但从实际代码看，仍有一批“UI 已展示但业务未闭环”的功能。最明显的问题集中在 5 类：

1. **结构化数据未闭环**：备忘录结构化字段已完成最小闭环；日记、情侣事项、本周目标等部分字段仍通过正文标记或页面状态临时保存，没有正式模型字段、同步协议和管理端表单。
2. **前端预留动作仍存在**：音乐收藏/下载/更多，情侣事项分享/分类/标签/照片墙，本周目标趋势/排序/图标等仍是提示或轻量本地行为。
3. **同步与备份能力仍需继续补齐**：同步冲突和本地数据损坏保护已具备最小闭环；`couple_task` 已补齐远端同步，AI 消息等本地数据仍未进入远端同步；远程备份未开放。
4. **质量门已完成本轮清零**：Flutter analyze/test、后端 lint/build/test、管理端 build 已通过；后续需要把这些验证固化到 CI 和发布流程。
5. **生产运维能力仍需收口**：数据库默认 SQLite，另有 PostgreSQL schema，但迁移策略、数据备份恢复、线上环境一致性仍需要明确流程。

## 二、验证结果

| 范围 | 命令 | 结果 |
| --- | --- | --- |
| Flutter 静态分析 | `flutter analyze` | 通过，No issues found |
| Flutter 单元/组件测试 | `flutter test` | 通过，21 tests |
| 后端构建 | `npm.cmd run build` | 通过 |
| 后端测试 | `npm.cmd test -- --runInBand` | 通过，7 suites / 24 tests |
| 后端 lint | `npm.cmd run lint` | 通过，0 个 ESLint 错误 |
| 管理端构建 | `npm.cmd run build` | 通过，主 chunk 约 670.84 kB |

本轮已新增 `test/sync_conflict_test.dart`、`test/data_recovery_test.dart` 和 `test/memo_model_test.dart`，覆盖同步冲突快照解析、同步状态序列化、“保留本机版本”刷新队列并清除冲突、损坏本地数据文件自动保留副本并从备份恢复，以及备忘录结构化字段序列化和旧正文标记迁移。

## 三、P0：发布前必须处理

### 1. 后端 lint 未通过（已完成）

代码事实：

- `xiaotai_server/backend/src/announcements/announcements.service.ts` 存在大量 `any`、unsafe assignment、unsafe member access。
- `xiaotai_server/backend/src/ai/ai.service.ts` 对复杂 content 做字符串化时触发 `no-base-to-string`。
- `xiaotai_server/backend/src/media/media.service.ts` 使用 `require` 引入模块。
- `xiaotai_server/backend/src/music/music.service.ts` 有 unused import 和 require-await。

本轮处理结果：

- `announcements.service.ts` 改为 Prisma 显式类型，移除查询和更新数据上的 `any`。
- `ai.service.ts` 安全处理文本、图片和对象型 content，避免对象被隐式字符串化为 `[object Object]`。
- `media.service.ts` 改为 ESM `sharp` import。
- `music.service.ts` 删除无效 import，并去掉不必要的 `async`。
- `ai`、`daily-comics`、`monitor` 相关测试改为显式读取 mock 调用参数，避免 unsafe matcher。

验证：

- `npm.cmd run lint`：通过。
- `npm.cmd run build`：通过。
- `npm.cmd test -- --runInBand`：通过，7 suites / 24 tests。

原影响：

- 严格 CI 会被阻断。
- 公告、AI、媒体、音乐都是当前核心能力，类型不收紧会放大后续字段变更风险。

剩余建议：

- 将后端 lint/build/test 加入 CI 必跑，避免再次把质量门留到发布前集中处理。

### 2. 同步冲突只有服务端判定，没有产品级解决（最小闭环已完成）

代码事实：

- Flutter `AppSyncService.pushPending` 收到 conflicts 后只把冲突项留在本地队列。
- 后端 `SyncService` 的冲突规则是服务端更新时间更新则返回 `server_newer`。
- 没有冲突详情页、覆盖确认、字段级合并、忽略冲突或“以本机为准”的操作。

本轮处理结果：

- 新增 `AppSyncConflict`，保存数据类型、clientId、原因、本机更新时间、云端更新时间、云端删除状态、本机快照和云端快照。
- `AppSyncService.pushPending` 不再只返回冲突数量，而是把后端 `conflicts.serverItem` 转成 Flutter 可展示的冲突详情。
- `AppSyncStatus` 持久化 `lastConflicts`，设置页可以在同步后展示具体冲突。
- `AppLocalStore.applyServerConflict` 支持“使用云端”：应用云端快照或删除状态，并移除本地冲突队列项。
- `AppLocalStore.keepLocalConflict` 支持“保留本机”：刷新本地队列项更新时间，等待下一次同步重新上传。
- 设置页新增同步冲突卡片和处理弹窗，提供“稍后处理 / 使用云端 / 保留本机”三种动作。
- 新增 `sync_conflict_test.dart` 回归测试，覆盖冲突解析、状态序列化和保留本机行为。

验证：

- `flutter analyze`：通过。
- `flutter test`：通过，17 tests。

剩余影响：

- 当前是记录级解决，不是字段级差异合并。
- 设置页只展示最近一次同步冲突；后续如需要冲突历史，需要单独设计。

剩余建议：

- 如高频出现同一记录冲突，再补字段级 diff 和合并。
- 将手动触发同步入口与冲突卡片联动，处理完冲突后允许用户立即重试同步。

### 3. 本地数据损坏时会静默回空对象（已完成）

代码事实：

- `AppLocalStore._readDataFile` 捕获 `FormatException` 后返回 `{}`。

本轮处理结果：

- `AppLocalStore._readDataFile` 解析失败时不再直接返回空对象。
- 损坏的 `xiaotai_life_data.json` 会复制为 `xiaotai_life_data.corrupt.<timestamp>.json`。
- 自动扫描 `xiaotai_life_backups` 目录，读取最新可解析 JSON 备份并恢复。
- 新增 `AppDataRecoveryNotice`，记录检测时间、损坏副本路径、是否恢复成功、恢复用的备份路径和错误信息。
- 设置页新增数据恢复提示卡，说明是否已从备份恢复，并展示损坏副本和恢复备份文件名。
- 新增 `data_recovery_test.dart` 回归测试，覆盖损坏文件保留和备份恢复。

验证：

- `flutter analyze`：通过。
- `flutter test`：通过，18 tests。

原影响：

- 如果 JSON 文件损坏，用户可能以为数据丢失，而不是看到恢复提示。
- 虽然本地备份存在，但损坏恢复没有主动引导。

剩余建议：

- 后续可继续增加“手动选择备份恢复”和“数据健康检查”入口。
- 远程备份仍未开放，需要作为独立功能规划。

### 4. 敏感信息处理流程不完整

代码事实：

- Codex 历史会话中出现过 SSH 私钥、服务器密码、COS Secret、AI Key 等敏感信息。
- 当前文档已脱敏，但历史日志仍存在敏感材料。

影响：

- 本地日志、会话归档、复制粘贴的部署脚本都可能泄露凭据。

建议：

- 立即轮换历史会话中出现过的服务器 SSH Key、COS Secret、AI Key、管理端入口密码。
- 后续只通过本机 `.env`、宝塔环境变量或临时密钥文件传递，不在聊天和文档中回显。
- 每次部署/排障文档只记录变量名和存放位置，不记录值。

## 四、P1：用户可感知的未闭环功能

### 1. 备忘录：标签、心情、提醒、图片仍不是正式字段（已完成最小闭环）

代码事实：

- `AppMemo` 只有 `id`、`title`、`content`、`createdAt`、`updatedAt`、`pinned`。
- 备忘页保存时把 `[mood:...]`、`[tags:...]`、`[remindAt:...]`、`[image]` 写进 `content`。
- `_plainMemoContent` 再通过正则把这些标记隐藏。
- 提醒按钮走 `_showReservedReminder`，图片只是 `_imageAttached` 状态和正文标记。

本轮处理结果：

- `AppMemo` 新增 `mood`、`tags`、`remindAt`、`imagePaths`、`imageMediaIds`、`draft` 字段。
- `AppMemo.fromJson` 兼容旧正文标记：读取 `[mood:...]`、`[tags:...]`、`[remindAt:...]`、`[draft]` 时迁移为结构化字段，并清理正文。
- 备忘页保存时不再把结构化信息写进 `content`，编辑时直接读写正式字段。
- 图片能力复用现有 `media_picker` 与 `MediaBackupService`：支持最多 3 张真实本地图片、预览、删除、上传并保存 mediaId。
- 备忘提醒进入 `LocalNotificationService`，草稿不调度，删除备忘会取消提醒，通知点击会打开备忘页。
- 启动服务和设置页通知开关重建时会同步备忘提醒。
- 全局搜索会命中备忘心情和标签。
- 管理端备忘录页展示草稿、心情、标签、提醒、图片数量和媒体 ID。
- 新增 `memo_model_test.dart`，覆盖结构化字段序列化、旧标记迁移和显式字段优先级。

验证：

- `flutter analyze`：通过。
- `flutter test`：通过，21 tests。
- `npm.cmd run build`（管理端）：通过。

剩余边界：

- 管理端目前是展示和检索同步数据，尚未提供直接编辑备忘录结构化字段的表单。
- 备忘提醒是单次本地通知，未做复杂重复规则。

### 2. 日记编辑：位置、多标签和草稿仍是临时方案

代码事实：

- `AppEntry` 已有 `imagePaths`、`imageMediaIds`，图片能力比备忘更完整。
- 但位置和多标签通过正文中的 `[location:...]`、`[tags:...]` 标记保存。
- 顶部“存草稿”调用同一个 `_saveEntry`，没有真实 `draft` 状态。

未实现内容：

- `location`、`tags`、`draftStatus` 正式字段。
- 草稿箱、草稿恢复、草稿同步。
- 位置权限和定位结果的真实接入。
- 管理端按标签、位置、草稿状态筛选。

建议：

- 扩展 `AppEntry` 模型并提供旧标记迁移。
- 草稿和正式记录分离，避免“存草稿”实际创建正式记录。
- 标签和位置进入全局搜索索引。

### 3. 设置页：多个开关是页面状态，不是持久能力

代码事实：

- `AppSettings` 只有 profile、通知开关、首次启动标记、主题 ID、更新时间。
- 设置页内部有 `_lockPreviewEnabled`、`_announcementEnabled`、`_soundEnabled`、`_dailyMoodTime`。
- `_pickDailyMoodTime` 只更新页面状态和 toast，不持久化，不创建本地通知。
- 深色主题提示“暂未开放”。
- 隐私详情明确显示“远程备份暂未开放”。
- 用户协议/隐私协议显示“正式协议内容暂未配置”。

未实现内容：

- 锁屏预览、公告通知、通知声音的真实系统设置。
- 每日心情提醒的持久化和通知调度。
- 深色主题。
- 远程备份。
- 正式用户协议和隐私政策内容。

建议：

- 扩展 `AppSettings` 并同步。
- 设置变更后立即调用本地通知服务重建提醒。
- 把法律协议做成可由管理端维护或本地版本化的文档资源。

### 4. 情侣 100 件事：多处仍是预留动作

代码事实：

- `AppCoupleTask` 只有 `id`、`index`、`title`、`completed`、`completedAt`、`imagePath`。
- 页面仍存在 `_showReservedShare`、`_showReservedCategoryPicker`、`_showReservedDatePicker`、`_showReservedTagPicker`、`_showReservedPhotoWallUpload`、`_showReservedSearchTag`。

未实现内容：

- 分类、计划完成日期、标签、描述、重要程度。
- 照片墙多图、媒体 ID、上传、删除。
- 分享卡片或系统分享。
- 自定义排序和管理端维护。

建议：

- 扩展模型为任务详情实体，而不是只靠固定 index 列表。
- 照片墙复用媒体上传服务，限制数量和压缩策略。
- 分享先做系统分享文本/图片，后续再做生成卡片。

### 5. 本周目标：趋势、排序和图标选择未闭环

代码事实：

- `AppWeeklyGoal` 有标题、目标值、当前值、单位、图标名、颜色、最后打卡日期。
- 页面仍存在 `_showReservedIconPicker`、`_showReservedDailyTrend`、`_showReservedReorder`。

未实现内容：

- 每日进度历史。
- 趋势图真实数据。
- 图标选择器。
- 自定义排序。
- 目标归档、重复目标模板。

建议：

- 增加 `dailyProgressHistory` 或单独 `weekly_goal_checkins` 数据结构。
- 首页打卡、本周目标详情和统计页共用同一套打卡历史。

### 6. 音乐播放器：基础播放可用，但收藏/下载等仍是预留

代码事实：

- 音乐页可从后端拉取曲库、播放/暂停、进度和歌词。
- `_liked` 是页面本地状态。
- 收藏、下载、更多、投币等二级按钮调用 `onReservedAction` 或本地状态。
- 当 `audioUrl` 为空或 `placeholder://` 时使用 placeholder 进度模拟。

未实现内容：

- 收藏持久化和同步。
- 下载缓存、离线播放和缓存清理。
- 播放列表管理、循环模式持久化、播放历史。
- 占位音乐的产品提示和后台质量检查。

建议：

- 后端增加用户维度的 `music_favorites` 或通过 `SyncItem` 同步收藏。
- 下载缓存需要存储大小、过期策略和失败重试。
- 管理端上传音乐时强校验音频 URL，不让 placeholder 进入正式曲库。

### 7. 小笨漫画：后端分页存在，App 端仍固定加载

代码事实：

- 后端 `findPublished` 支持 page/pageSize/totalPages。
- App 初始化和刷新固定 `fetchPublished(pageSize: 30)`。
- 分享只是复制标题和日期。
- 剧集标题存在固定 fallback。

未实现内容：

- App 端加载更多/分页。
- 阅读进度、收藏、已读状态同步。
- 系统分享图片或链接。
- 后台剧集编号和 App 展示规则统一。

建议：

- App 列表增加分页状态和加载更多。
- 已读、收藏、最近阅读进入本地模型和同步。

### 8. 纪念日：分享和排序仍是轻量提示

代码事实：

- `AppAnniversary` 已有 `imagePath`、`note`、`showCountUp`，备注不再是缺口。
- 页面仍存在 `_showReservedShare` 和 `_showReservedReorder`。

未实现内容：

- 系统分享/生成纪念卡片。
- 手动排序。
- 重复规则、提醒规则、重要纪念日置顶。
- 管理端按分类/日期维护。

建议：

- 先做系统分享文本和图片卡片二选一。
- 排序可先加 `sortIndex`，默认日期排序。

### 9. 地点：图片可用，但计划状态和地图能力缺失

代码事实：

- `AppPlace` 有标题、描述、分类、颜色、图片路径、媒体 ID。

未实现内容：

- 地图坐标/地图链接。
- 已去/想去/计划中状态。
- 到访日期、评分、预算、路线备注。
- 管理端和搜索页的结构化筛选。

建议：

- 扩展 `status`、`visitedAt`、`mapUrl`、`lat`、`lng`。
- 地图链接先用 URL 打开，后续再接地图 SDK。

### 10. 本地通知：只覆盖基础提醒规则

代码事实：

- `LocalNotificationService` 支持 `daily`、`weekly`、`monthly` 的 `matchDateTimeComponents`。
- 提醒模型没有备注字段。
- 设置页每日心情提醒没有进入通知调度。

未实现内容：

- 自定义重复规则，如工作日、间隔天数、指定日期。
- 提醒备注、通知动作按钮、稍后提醒。
- 通知点击后的完整路由上下文。
- 已完成提醒从状态栏彻底清理的回归测试。

建议：

- 把 repeatRule 从字符串升级为结构化对象。
- 通知 payload 携带类型和 id，点击后精确打开详情。

## 五、P2：系统能力和管理能力待加强

### 1. 同步类型不完整

代码事实：

- `AppLocalStore.applyRemoteItem` 支持 `entry`、`memo`、`reminder`、`anniversary`、`place`、`weekly_goal`、`money_record`、`settings`。
- `couple_task` 已完成最小同步闭环：新增/编辑/完成状态会进入同步队列，删除会进入带 `deletedAt` 的同步队列，远端拉取和冲突使用云端时可以回写/删除本地情侣任务。
- AI 消息尚未覆盖同步。

影响：

- 情侣任务完成情况已经可以通过同步在新设备恢复。
- AI 对话仍不能在新设备完整恢复。

建议：

- `couple_task` 同步：已完成。
- AI 消息可只同步摘要或最近 N 条，避免泄露和膨胀。

处理记录（2026-06-03）：

- 已完成：`couple_task` 同步队列、远端回放和删除回放。
- 已完成：情侣事项页新增、编辑、完成/取消完成、删除改为走同步感知的仓库方法。
- 已完成：新增 Flutter 回归测试覆盖 `couple_task` 入队、删除入队、远端应用和远端删除。
- 验证：`flutter analyze` 通过；`flutter test` 通过，29 tests。

### 2. 媒体备份是“保存时尽力上传”，不是完整备份系统

代码事实：

- `MediaBackupService` 顺序上传图片，失败返回 null 或 failedPaths。
- 没有持久上传队列、断点续传、进度流、失败重试列表。

未实现内容：

- 大量图片/视频的后台队列。
- 断点续传和失败重试。
- App 端可见的备份状态。
- COS 迁移后的完整一致性检查。

建议：

- 如果产品继续保留媒体备份，应做独立队列和状态页。
- 如果“不展示备份开关”仍是原则，至少管理端要能看到每个用户的备份完成度和失败数。

### 3. 管理端缺少自动化测试

代码事实：

- 管理端构建通过，但没有发现对应页面测试。
- 用户多次反馈表格横向滚动、按钮越界、内容显示不全。

未实现内容：

- 表格布局回归测试。
- 表单校验测试。
- 文件上传进度和失败态测试。
- 管理端移动端适配测试。

建议：

- 给关键页面补 Playwright 或 Testing Library 测试。
- 表格列设置优先级，低优先级字段进入详情弹窗，避免横向滚动。

### 4. 数据库迁移策略未完全产品化

代码事实：

- 主 Prisma schema 使用 SQLite。
- 仓库中存在 `schema.postgresql.prisma`。
- 用户历史上多次担心服务器重置、数据库覆盖、COS 数据还在但本地数据丢失。

未实现内容：

- SQLite 到 PostgreSQL 的正式迁移脚本和回滚流程。
- 部署前自动备份数据库。
- 线上恢复演练文档。

建议：

- 在继续部署前固定数据库策略。
- 每次远程改动前执行数据库备份，并记录备份路径。
- 不使用 `db push` 覆盖线上数据，优先迁移脚本。

### 5. AI 助手还不是“可执行动作助手”

代码事实：

- AI prompt 已包含用户上下文、最近记录、天气、最近对话。
- 后端 AI 接口调用大模型。
- 用户期望“今天花费 30 块吃午饭”后能生成记账待确认。

未实现内容：

- AI 意图识别。
- 待确认动作卡片。
- 用户确认后写入记账、提醒、日记等模型。
- 语音播报和自定义声音。

建议：

- 先做可控的 action schema：`create_money_record`、`create_reminder`、`create_entry_draft`。
- 所有 AI 写入必须二次确认，不能直接落库。

## 六、明确不应继续追的历史需求

以下需求在历史对话中出现过，但从当前产品定位和后续指令看，不应作为默认待办继续推进：

- 短信验证码登录、注册、找回密码：当前要求只保留账号密码登录。
- 公开社区、陌生人社交、多用户商业 SaaS：与 README 的双人私有 App 定位冲突。
- 远程摄像头调用、实时画面监控：用户后续明确要求删除，只保留授权内容展示和强弹窗相关能力。
- 静默同步全部相册：后续有删除相关内容的要求；如恢复也必须重新确认隐私边界和授权方式。
- 饮食热量模块：用户明确要求删除相关内容和代码。

## 七、推荐实施顺序

1. **固化质量门**：后端 lint/build/test、Flutter analyze/test、管理端 build 已通过，下一步要放入 CI 和发布检查。
2. **继续补结构化模型**：备忘录已完成；下一步处理日记、情侣事项、本周目标的临时字段，做旧数据迁移。
3. **继续补同步协议**：`couple_task` 已覆盖；下一步评估 AI 消息同步范围，并按需要补字段级冲突合并。
4. **补设置和通知**：每日心情提醒、通知声音、公告开关、系统通知动作。
5. **补媒体和音乐闭环**：音乐收藏/下载、媒体备份队列、漫画分页/阅读进度。
6. **补管理端测试和表格治理**：避免横向滚动、按钮越界、上传无进度等历史反复问题。
7. **最后做数据库和部署收口**：明确 SQLite/PostgreSQL 策略、备份恢复和 COS 一致性检查。

## 八、后续审查规则

后续每次说“实现完成”前，必须至少回答 4 个问题：

1. UI 控件是否真的连接到模型、API、通知、文件系统或同步队列？
2. 新字段是否进入本地序列化、远端同步、管理端展示和旧数据迁移？
3. 是否有验证命令结果，失败项是否明确记录？
4. 如果只是预留，是否写入对应 `*-ui-contract.md` 或本清单，并在 UI 上避免假装可用？
