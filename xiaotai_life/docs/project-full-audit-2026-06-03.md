# 小柔日记项目全面功能审查报告

审查日期：2026-06-03  
审查范围：Flutter APP、NestJS 后端、React 管理端、接口预留文档、基础验证命令。

## 本轮已补齐内容

### Flutter APP

- 记账页已补齐新增记账、编辑删除、删除确认、支付方式、月份选择、时间选择、分类筛选与本地持久化。
- 音乐播放器已修复底部遮挡；音乐页独立隐藏主底部导航；歌词会按播放进度切换，后端 `durationSeconds` 可被解析。
- 默认主题已接入全局背景图：`assets/themes/default/background.png`。
- 首页小目标打卡已接入本地 `AppWeeklyGoal`：无真实目标时首次打卡会创建默认目标，已有目标时累加进度并进入同步队列。
- 小笨漫画搜索已从预留入口改为本地关键字过滤，支持标题和发布日期。
- 纪念日搜索与分类卡片已接入本地筛选，备注字段已持久化，分享入口改为复制分享文案。
- 备忘录搜索、心情卡筛选、日期选择、自定义标签和提醒时间已接入；心情、标签、草稿和提醒时间当前通过内容标记保存并在展示时隐藏。
- 登录页已按产品要求收敛为账号密码登录，移除验证码登录、找回密码和注册入口。
- 日记编辑已接入本地位置和多标签保存；提醒页已接入本地搜索；音乐播放列表已接入搜索和刷新。
- 已同步更新相关接口预留文档：`homepage-ui-contract.md`、`weekly-goals-ui-contract.md`、`daily-comic-ui-contract.md`、`anniversary-ui-contract.md`、`memo-ui-contract.md`。

## 验证结果

| 模块 | 命令 / 方式 | 结果 | 备注 |
| --- | --- | --- | --- |
| Flutter 静态分析 | `E:\dev\flutter\bin\flutter.bat analyze` | 通过 | No issues found |
| Flutter 测试 | `E:\dev\flutter\bin\flutter.bat test` | 通过 | 14 tests passed |
| 后端 lint | `npm.cmd run lint` | 失败 | 37 个 ESLint 错误，集中在 unsafe any、require-await、no-base-to-string、require import |
| 后端构建 | `npm.cmd run build` | 通过 | Nest build 通过 |
| 后端测试 | `npm.cmd test` | 通过 | 7 suites / 24 tests passed |
| 管理端构建 | `npm.cmd run build` | 通过 | Vite build 通过 |
| 真机音乐页 | 既有截图 `build/device_debug/xiaotai_music_fix.png` | 通过 | 底部播放器未再被主导航遮挡；本轮未重新跑全量真机回归 |

## 前端审查

### 路由覆盖

APP 当前路由覆盖：首页、登录、搜索、日记列表、新建/编辑日记、日记详情、备忘、百宝箱、统计、设置、提醒、纪念日、地点、情侣 100 件事、本周目标、记账、小笨漫画、音乐播放器。

### 已实现较完整的模块

- 首页：天气、快捷入口、提醒/纪念日/日记展示、全局背景、主题吉祥物、小目标本地打卡。
- 日记本：列表、编辑、详情、删除确认、图片选择入口。
- 纪念日：列表、添加/编辑、详情、删除、管理、搜索、分类筛选。
- 本周目标：列表、添加/编辑、详情进度、管理删除、首页打卡联动。
- 记账：列表、新增、编辑、删除、分类、备注、日期、支付方式、月度统计。
- 漫画：后端拉取、列表、往期、阅读分页、末页、搜索。
- 音乐：后端拉取、播放/暂停、进度、歌词、底部控制区修复。
- 备忘：列表、增删改、置顶、搜索、心情筛选、标签、日期。

### 前端预留处理状态

| 模块 | 处理结果 | 备注 |
| --- | --- | --- |
| 登录 | 仅保留账号密码登录 | 验证码登录、找回密码、注册入口已删除 |
| 日记编辑 | 位置、多标签已接入本地保存 | 通过内容标记保存，图片错误提示保留真实错误文案 |
| 纪念日 | 备注已入模型，分享改为复制文案，排序改为日期自动排序提示 | 不再显示接口预留文案 |
| 情侣 100 件事 | 分享复制文案，分类/日期/标签可本地选择，照片入口引导到详情添加照片 | 公开范围后续如需要再扩展模型 |
| 本周目标 | 图标选择、进度提示、排序说明已接入本地行为 | 删除仍只允许真实目标，样例不可删 |
| 备忘 | 搜索、心情筛选、标签、日期、提醒时间已接入 | 图片仍使用当前占位/本地选择能力 |
| 音乐 | 播放列表搜索已接入，新增按钮改为刷新曲库，更多菜单显示当前歌曲 | 下载按钮不再提示接口预留 |
| 设置 | 个人资料、本地备份/恢复可用；主题收敛为默认与 Eggy；协议文案改为当前版本说明 | 不再显示接口预留文案 |
| 提醒 | 搜索筛选已接入本地列表 | 按标题和优先级关键字过滤 |

## 后端审查

### API 覆盖

后端已覆盖以下控制器/资源：

- `auth`：登录、刷新、登出、当前用户。
- `users`：当前用户、管理员校验。
- `sync`：同步项列表、批量提交。
- `media` / `admin/media`：媒体上传、读取、缩略图、删除、下载票据。
- `announcements`：公告列表、活跃公告、图片、增删改。
- `daily-comics`：最新漫画、已发布列表、图片、后台增删改。
- `music/tracks` / `admin/music/tracks`：音乐列表、音频/封面、后台增删改。
- `app-versions` / `admin/app-versions`：版本检测、APK 下载、后台管理。
- `monitor`：设备、用量、强推任务。
- `weather`：天气、指数。
- `ai`：聊天接口。
- `admin`：仪表盘、用户、数据项、审计日志。

### 数据模型

Prisma 模型包括：`User`、`RefreshToken`、`Space`、`SpaceMember`、`Device`、`SyncItem`、`AuditLog`、`AppVersion`、`MediaAsset`、`Announcement`、`DailyComic`、`DailyComicImage`、`MusicTrack`、`DeviceUsageReport`、`ForcePush`。

### 主要风险

1. 后端 lint 未通过，当前 37 个错误会阻断严格 CI。重点文件：`announcements.service.ts`、`ai.service.ts/spec.ts`、`daily-comics.service.spec.ts`、`monitor.service.spec.ts`、`media.service.ts`、`music.service.ts`。
2. 公告服务中 `any` 和 unsafe member access 较多，后续维护和字段变更风险高。
3. `ai.service.ts` 对 content 的字符串化存在 `no-base-to-string` 风险，复杂对象可能被转换为 `[object Object]`。
4. 单元测试数量可用但偏少，缺少控制器层、鉴权越权、文件上传边界、同步冲突、移动端端到端流测试。
5. APP 新增的部分本地字段采用内容标记临时保存，适合当前 UI 补齐，但长期建议正式扩展模型和同步协议。

## 管理端审查

管理端页面覆盖：Dashboard、Users、Data、Entries、Memos、Places、Announcements、DailyComics、Music、Media、AppVersions、MonitorUsage、ForcePush、AuditLogs、AiVerify、Login。生产构建通过。

建议后续补齐：

- 管理端缺少自动化测试和关键表单校验测试。
- 大包体 `index-D73xc1ln.js` 约 670 kB，后续可继续拆分公共依赖。
- 与 APP 新增字段对应的后台管理表单需要等后端模型扩展后同步。

## 推荐优先级

1. 修复后端 ESLint 37 个错误，恢复 CI 质量门。
2. 将备忘、日记、情侣事项、本周目标的内容标记字段升级为正式模型字段，并通过 `SyncItem` 协议同步。
3. 补充系统能力：本地通知、系统分享、图片上传/下载、音乐下载。
4. 为后端控制器和 APP 关键用户流补充集成/E2E 测试。
5. 对全局背景进行逐页透明度复查，确保各页面没有被局部不透明背景完全遮住主题背景。

## 结论

APP 端本轮指出的问题已处理：记账新增/删除、音乐底部遮挡与歌词进度、默认主题背景、首页目标打卡、漫画搜索、纪念日筛选/备注/分享、备忘搜索/筛选/日期/标签/提醒、日记位置/多标签、提醒搜索，以及登录页仅保留账号密码登录。Flutter 分析和测试均通过。后端构建与测试通过，但 lint 未通过，是当前发布前最明确的质量风险。
