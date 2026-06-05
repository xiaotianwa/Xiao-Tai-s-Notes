# 婷婷的小笨笔记 APP

婷婷的小笨笔记是一款只服务于两个人的私有生活记录 App：你和女朋友。它不是公开社交产品，也不追求获客、广告、商业化和陌生人协作，核心目标是把两个人的日常、纪念、提醒、照片和想法稳稳保存下来，并在需要时同步到私有服务端。

## 当前定位

- 使用对象：仅你和女朋友两个 App 用户。
- 使用场景：记录日常、保存备忘、纪念日倒数、待办提醒、想去的地方、情侣清单、每周目标、照片备份、私有同步。
- 产品原则：少打扰、好恢复、能离线、数据可控、界面温柔但不复杂。
- 明确不做：公开社区、陌生人关注、广告、付费体系、复杂运营增长、多租户商业 SaaS。

## 项目结构

```text
E:\xiaotairiji
├─ xiaotai_life/          Flutter App
├─ xiaotai_server/
│  ├─ backend/            NestJS + Prisma + SQLite API
│  └─ admin/              React + Vite + Ant Design 管理端
├─ APP主题原型图1/         App 视觉原型素材
├─ 参考吉祥物图片内容/      吉祥物与视觉参考
└─ 归档_V1后续数据库方案/   早期数据库方案归档
```

## 技术栈

- App：Flutter / Dart，Riverpod，GoRouter，本地 JSON 存储，本地通知，媒体备份，私有同步。
- 后端：NestJS，Prisma，SQLite，JWT，Refresh Token，统一响应结构，Swagger 标注。
- 管理端：React，Vite，TypeScript，Ant Design。
- 数据：本地优先，登录后通过 `/api/v1/sync` 增量同步到服务端。

## 核心功能

- 登录与账号：账号密码登录、刷新令牌、退出登录、当前用户信息。
- 今日页：聚合今日提醒、近期记录、纪念日等入口。
- 记录：写日记/清单，支持心情、收藏、图片路径与云端媒体 ID。
- 备忘录：标题、正文、置顶、增删改。
- 提醒：时间、提前提醒、优先级、完成状态、本地通知。
- 纪念日：倒数/正数、分类、配色、图片。
- 生活页：想去地点、情侣 100 件事、每周目标。
- 记账：本地记录收入/支出、月度结余汇总，并通过私有同步队列备份。
- 主题外观：设置页支持经典小泰、蜡笔小新、周杰伦、蛋仔派对主题切换，主题会影响 App 背景、卡片、导航和主题插图。
- AI 助手：保留最近对话，本地记录，服务端 AI 接口。
- 天气：服务端天气接口与 App 天气服务。
- 媒体备份：图片上传、缩略图/原图读取、去重标记。
- 公告：管理端发布，App 拉取有效公告并记录已读。
- 版本更新：管理端上传 APK，App 查询最新版本。
- 管理端：仪表盘、用户、同步数据、媒体、版本、公告、审计日志。

## 本地开发

后端：

```powershell
cd E:\xiaotairiji\xiaotai_server\backend
npm install
npm run prisma:generate
npm run prisma:migrate
npm run seed:admin
npm run start:dev
```

管理端：

```powershell
cd E:\xiaotairiji\xiaotai_server\admin
npm install
npm run dev
```

App：

```powershell
cd E:\xiaotairiji\xiaotai_life
flutter pub get
flutter run --dart-define=XIAOTAI_API_BASE_URL=http://10.0.2.2:3100/api/v1
```

## 私有部署注意

- 服务端只需要支撑两个真实用户，优先保证备份、同步、恢复和隐私。
- 数据库、上传目录、APK 文件目录必须定期备份。
- 管理端账号只给你使用，普通 App 账号只给你和女朋友使用。
- 后续任何功能都应先问一句：它会不会让两个人的记录更安心、更好用？
