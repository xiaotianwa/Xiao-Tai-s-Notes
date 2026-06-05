# 婷婷小笨笔记 App 模拟器全模块测试步骤与实测记录

生成日期：2026-06-03  
测试对象：`xiaotai_life` Flutter Android App  
测试方式：Android 模拟器 + ADB 手工走查 + Flutter 静态/自动化测试  
API 基址：`https://api.xthblog.site/api/v1`  
截图目录：`E:\xiaotairiji\xiaotai_life\build\full-emulator-test-2026-06-03`

## 1. 测试目标

1. 覆盖底部 5 个一级模块：首页、日记、百宝箱、统计、我的。
2. 覆盖百宝箱全部入口：今日提醒、记账、小笨漫画、纪念日、写日记、记心情/备忘、本周目标、记账本、情侣 100 件事、想去地点、音乐播放器、AI 助手、全局搜索。
3. 每个模块至少验证：可打开、可返回、核心控件有响应、筛选可切换、表单不遮挡、无明显黑屏/乱码/溢出。
4. 本轮不主动写入生产数据；涉及新增页时只验证表单打开与字段布局，不提交保存。
5. 外部系统弹窗、模拟器输入法/手写笔弹窗单独记录，不计为 App 业务功能通过。

## 2. 环境准备与基础命令

在 `E:\xiaotairiji\xiaotai_life` 执行：

```powershell
$env:DART_SUPPRESS_ANALYTICS='true'
flutter analyze
flutter test
flutter build apk --debug --dart-define=XIAOTAI_API_BASE_URL=https://api.xthblog.site/api/v1
```

安装与启动：

```powershell
$adb="$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $adb devices
& $adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
& $adb -s emulator-5554 shell am force-stop com.xiaotai.life
& $adb -s emulator-5554 shell monkey -p com.xiaotai.life -c android.intent.category.LAUNCHER 1
```

截图：

```powershell
New-Item -ItemType Directory -Force -Path build\full-emulator-test-2026-06-03 | Out-Null
& $adb -s emulator-5554 shell screencap -p /sdcard/step.png
& $adb -s emulator-5554 pull /sdcard/step.png build\full-emulator-test-2026-06-03\step.png
```

严重运行错误过滤：

```powershell
& $adb -s emulator-5554 logcat -d |
  Select-String -Pattern "FATAL EXCEPTION|AndroidRuntime|FlutterError|RenderFlex|overflowed|Unhandled Exception|com.xiaotai.life"
```

## 3. 通用通过标准

- 页面 5 秒内显示有效内容、空态或加载态。
- 标题、卡片、底部导航、浮动按钮不互相遮挡。
- 看起来可点击的控件必须有真实响应。
- 筛选、Tab、搜索、排序点击后选中态或内容数量有变化。
- 表单输入区、保存按钮、取消按钮位于安全区内，不被键盘或底部导航遮挡。
- 删除、恢复、备份等危险操作必须有二次确认。
- 页面滚动顺畅，无黑色斜线残影、乱码背景、RenderFlex overflow、白屏或崩溃。

## 4. 权限与外部弹窗策略

- 定位权限：本轮选择“不允许”，验证 App 是否能降级显示天气/位置相关内容。
- 通知权限：若出现，仅记录弹窗与降级，不触发真实定时通知。
- 录音权限：AI 语音输入不作为本轮必测写入项。
- 相册/相机权限：图片选择入口只验证到系统选择器或权限弹窗，不上传真实生产图片。
- 模拟器 Google Lens、手写笔教程弹窗属于系统干扰，不计入 App 功能结果。

## 5. 详细测试步骤

### 5.1 首页

1. 启动 App，等待首页加载完成。
2. 若出现定位权限弹窗，选择“不允许”。
3. 检查今日提醒、纪念日、最近日记、今日天气、本周目标、快捷入口、心情日历。
4. 点击今日提醒“全部”、纪念日卡片、最近日记“全部”、快捷入口。
5. 上下滚动，确认底部导航不遮挡内容。

### 5.2 日记列表与日记编辑

1. 点击底部“日记”。
2. 切换“日记 / 清单 / 心情 / 自定义”。
3. 打开百宝箱 -> 写日记。
4. 检查标题、正文、添加图片、添加位置、添加标签、今日心情、保存按钮。
5. 不提交真实数据，仅验证表单可见、按钮可点、页面可返回。

### 5.3 百宝箱

1. 点击底部“百宝箱”。
2. 检查顶部常用功能入口：今日提醒、记账、小笨漫画、纪念日。
3. 检查日常记录入口：写日记、记心情、提醒、本周目标。
4. 向下滚动，检查生活工具和放松探索入口：记账本、情侣 100 件事、想去地点、音乐播放器、AI 助手、全局搜索。
5. 每个入口至少打开一次，并返回百宝箱。

### 5.4 今日提醒

1. 百宝箱 -> 今日提醒。
2. 检查提醒列表、状态标签、完成/删除按钮。
3. 切换筛选项。
4. 尝试打开新增入口；若页面没有明显新增入口，记录为交互待补。

### 5.5 备忘 / 心情

1. 百宝箱 -> 记心情。
2. 切换“全部 / 备忘 / 心情 / 置顶”。
3. 检查数量是否变化。
4. 点击新增按钮，检查备忘/心情切换、标题、内容、心情、标签、提醒、日期字段。
5. 不保存测试数据，返回列表。

### 5.6 记账 / 记账本

1. 百宝箱 -> 记账。
2. 检查月份切换、日历、加号、收入/支出/结余概览、明细列表。
3. 点击新增，检查收入/支出切换、金额、分类、备注、日期、支付方式、确认/取消按钮。
4. 返回百宝箱后，打开记账本入口，确认同一账本页可达。

### 5.7 小笨漫画

1. 百宝箱 -> 小笨漫画。
2. 切换“最新 / 往期”。
3. 检查漫画卡片、日期、搜索按钮。
4. 点击漫画卡片进入阅读页；若网络或数据限制未进入，记录为部分通过。

### 5.8 纪念日

1. 百宝箱 -> 纪念日。
2. 切换“全部 / 即将到来 / 已过去”。
3. 检查搜索、添加、筛选按钮。
4. 点击“添加新的纪念日”或顶部加号，检查新增页入口。

### 5.9 情侣 100 件事

1. 百宝箱 -> 情侣 100 件事。
2. 切换“全部 / 未完成 / 已完成”。
3. 检查完成数、添加按钮、编辑按钮、删除按钮、勾选状态。
4. 不新增真实任务，仅记录页面交互可达。

### 5.10 本周目标

1. 首页本周目标卡片或百宝箱 -> 本周目标。
2. 检查目标卡片、进度条、加减按钮、统计、编辑、删除按钮。
3. 点击添加按钮，确认新增表单或入口响应。

### 5.11 想去地点

1. 百宝箱 -> 想去地点。
2. 切换“旅行 / 约会”。
3. 检查空态、添加按钮。
4. 点击添加按钮，确认新增地点表单入口。

### 5.12 音乐播放器

1. 百宝箱 -> 音乐播放器。
2. 检查封面、歌曲名、歌手、歌词、进度条。
3. 点击播放/暂停、上一首、下一首、循环等控件。
4. 若音频实际播放不可验证，记录为 UI 与控件通过、播放链路待专项验证。

### 5.13 全局搜索

1. 百宝箱 -> 全局搜索。
2. 检查搜索输入框、空态和“写一条新记录”按钮。
3. 输入关键词，观察结果分组。
4. 注意模拟器输入法、手写笔系统弹窗是否干扰。

### 5.14 AI 助手

1. 百宝箱 -> AI 助手。
2. 检查底部 Sheet、输入框、麦克风、发送按钮。
3. 输入一条文本但不确认写入真实数据。
4. 验证关闭 Sheet 后可返回百宝箱。

### 5.15 统计

1. 点击底部“统计”。
2. 检查概览、心情分布、日记趋势、记账统计等卡片。
3. 在空数据和有样例数据情况下都不能白屏或溢出。

### 5.16 我的 / 设置

1. 点击底部“我的”。
2. 检查个人信息、同步、通知设置、主题设置、本地备份、恢复备份、隐私政策、关于。
3. 只打开安全设置页；恢复备份不执行真实恢复。
4. 若误触系统外部应用，记录为无效截图并重新回到 App。

## 6. 本轮实测环境

| 项目 | 值 |
|---|---|
| 测试日期 | 2026-06-03 |
| 设备 | Android Emulator `emulator-5554` |
| Android 版本 | Android 16 / API 36 |
| 分辨率 | 1080 x 2400 |
| Density | 420 |
| APK | `E:\xiaotairiji\xiaotai_life\build\app\outputs\flutter-apk\app-debug.apk` |
| API 基址 | `https://api.xthblog.site/api/v1` |
| 截图目录 | `E:\xiaotairiji\xiaotai_life\build\full-emulator-test-2026-06-03` |

## 7. 命令验证结果

| 检查项 | 结果 | 备注 |
|---|---|---|
| `flutter analyze` | 通过 | No issues found |
| `flutter test` | 通过 | 29 tests passed |
| debug APK 构建 | 通过 | Kotlin Gradle Plugin 兼容性警告，不阻断构建 |
| APK 安装启动 | 通过 | `com.xiaotai.life` 成功安装并启动 |
| 冷启动表现 | 部分通过 | 首次加载约 10-15 秒，期间停留启动页 |
| Logcat 严重错误 | 未发现 App 崩溃证据 | 未见 `FATAL EXCEPTION`、`FlutterError`、`RenderFlex overflow`；存在 force-stop、权限、系统输入法/Google 相关日志 |

## 8. 模块实测矩阵

| 模块 | 打开 | 核心交互 | 新增/编辑/删除 | UI 结果 | 证据截图 | 结论 | 备注 |
|---|---|---|---|---|---|---|---|
| 首页 | 通过 | 通过 | 不适用 | 通过 | `00-launch.png`, `88-app-launch-for-diary-clean.png` | 通过 | 定位拒绝后天气可降级显示城市/天气 |
| 日记列表 | 通过 | 部分通过 | 未提交写入 | 通过 | `01-nav-diary.png`, `85-diary-editor-valid.png` | 部分通过 | 列表和编辑页可达；未执行真实保存/删除 |
| 百宝箱 | 通过 | 通过 | 不适用 | 未通过 | `10-treasure-top.png`, `11-treasure-lower.png`, `90-app-treasure-clean-final.png` | 未通过 | 左侧黑色斜线背景残影明显 |
| 今日提醒 | 通过 | 部分通过 | 未验证 | 部分通过 | `21-reminder-list.png` | 部分通过 | 列表可达；新增入口未形成有效证据 |
| 备忘/心情 | 通过 | 通过 | 表单可达 | 通过 | `64-memo-list-valid.png`, `65-memo-mood-filter-valid.png`, `66-memo-pinned-filter-valid.png`, `77-memo-add-form.png` | 通过 | 筛选数量能变化，新增表单字段可见 |
| 记账 | 通过 | 通过 | 表单可达 | 通过 | `40-money-list-reset.png`, `46-moneybook-lower-reset.png`, `78-money-add-form.png` | 通过 | 不提交真实账单 |
| 小笨漫画 | 通过 | 部分通过 | 不适用 | 通过 | `41-comic-list-reset.png`, `50-comic-lower-reset.png` | 部分通过 | 列表可达；阅读页未完整验证 |
| 纪念日 | 通过 | 通过 | 入口可见 | 通过 | `42-anniversary-list-reset.png`, `48-anniversary-lower-reset.png` | 通过 | 列表、筛选、添加入口可见 |
| 情侣 100 件事 | 通过 | 通过 | 未提交写入 | 通过 | `47-couple-tasks-reset.png` | 通过 | 完成/未完成筛选、编辑/删除按钮可见 |
| 本周目标 | 通过 | 部分通过 | 添加按钮未打开表单 | 通过 | `67-weekly-goals-valid.png`, `68-weekly-goal-add-valid.png` | 部分通过 | 目标卡片和加减按钮可见；添加按钮点击未形成表单变化 |
| 想去地点 | 通过 | 部分通过 | 未验证 | 未通过 | `49-places-reset.png` | 未通过 | 页面出现明显黑色斜线背景残影 |
| 音乐播放器 | 通过 | 部分通过 | 不适用 | 通过 | `51-music-reset.png` | 部分通过 | UI 和控件可见；真实音频播放未专项验证 |
| 全局搜索 | 通过 | 部分通过 | 不适用 | 通过 | `53-global-search-reset.png`, `55-permission-dismiss-check.png` | 部分通过 | 输入框可见；模拟器手写笔弹窗干扰输入 |
| AI 助手 | 通过 | 部分通过 | 未执行写入 | 通过 | `52-ai-assistant-reset.png` | 部分通过 | Sheet、输入框、麦克风、发送按钮可见 |
| 统计 | 通过 | 通过 | 不适用 | 通过 | `03-nav-stats.png` | 通过 | 空数据状态正常 |
| 我的/设置 | 通过 | 部分通过 | 恢复不执行 | 通过 | `04-nav-settings.png`, `86-settings-main-valid-2.png` | 部分通过 | 主设置页可达；部分子页坐标测试误触系统 Google Lens，需下轮使用语义定位重测 |

## 9. 缺陷与风险记录

| 编号 | 模块 | 严重级别 | 现象 | 复现步骤 | 证据 | 建议 |
|---|---|---|---|---|---|---|
| APP-EM-001 | 百宝箱 / 想去地点 / 部分工具页 | P1 | 页面左侧出现黑色斜线/乱码状背景残影，视觉污染明显 | 打开 App -> 百宝箱，或百宝箱 -> 想去地点 | `90-app-treasure-clean-final.png`, `49-places-reset.png` | 优先检查背景图、装饰图层、CustomPainter、缓存图片解码与主题背景叠层 |
| APP-EM-002 | 首页权限流 | P2 | 首次启动出现定位权限弹窗，拒绝前会阻断底部导航与首页操作 | 冷启动 App，等待首页加载 | `79-stable-home-after-long-wait.png` | 权限申请前增加 App 内说明，或延后到用户点击天气/位置功能时再请求 |
| APP-EM-003 | 冷启动 | P2 | 冷启动到首页约 10-15 秒，自动化等待 5 秒仍停留启动页 | force-stop 后 monkey 启动 | `73-clean-relaunch.png`, `88-app-launch-for-diary-clean.png` | 分析启动阶段 API、资源加载、初始化任务，先显示可交互首页骨架 |
| APP-EM-004 | 今日提醒 | P2 | 提醒列表可打开，但本轮未找到稳定新增入口证据 | 百宝箱 -> 今日提醒，尝试点击新增坐标 | `21-reminder-list.png`, `22-reminder-form.png` | 明确新增按钮位置；若已有入口，提升可发现性 |
| APP-EM-005 | 本周目标 | P2 | 点击添加按钮后截图未出现明显新增表单变化 | 百宝箱 -> 本周目标 -> 添加 | `67-weekly-goals-valid.png`, `68-weekly-goal-add-valid.png` | 检查添加按钮绑定与反馈；至少弹出表单、Toast 或错误提示 |
| APP-EM-006 | 设置子页测试 | P3 | 坐标测试误触外部 Google Lens/系统弹窗，设置子页未完全覆盖 | 我的 -> 设置区域坐标点击 | `70-settings-notification.png`, `71-settings-theme.png` | 下轮使用无障碍文本定位或 Flutter integration_test，避免坐标误触 |
| APP-EM-007 | 全局搜索输入 | P3 | 模拟器手写笔教程弹窗干扰搜索输入 | 百宝箱 -> 全局搜索 -> 聚焦输入框 | `55-permission-dismiss-check.png`, `56-system-panel-dismiss.png` | 测试前关闭模拟器手写笔教程；该项不是 App 缺陷 |

## 10. 回归测试要求

修复任一缺陷后，至少执行：

1. `flutter analyze`
2. `flutter test`
3. `flutter build apk --debug --dart-define=XIAOTAI_API_BASE_URL=https://api.xthblog.site/api/v1`
4. 安装到 `emulator-5554`
5. 复测对应模块并保存新截图
6. 若涉及视觉层，重点复查百宝箱、想去地点、备忘、日记编辑这些使用背景装饰的页面
7. 若涉及权限流，覆盖“允许”“仅本次允许”“不允许”三种分支

## 11. 本轮结论

本轮已在 Android 模拟器上完成主要模块走查。基础构建、静态检查、自动化测试均通过，App 可安装启动，未发现崩溃级日志。核心功能入口大部分可达，但不能判定为全量通过，原因是仍存在以下阻断：

- P1：百宝箱及想去地点等页面出现黑色斜线背景残影，属于明显 UI 缺陷。
- P2：首页启动即请求定位权限，阻断首屏操作；冷启动耗时偏长。
- P2：今日提醒新增、本周目标添加未形成有效表单打开证据。
- P3：设置子页和全局搜索受模拟器系统弹窗干扰，需下一轮用更稳定的定位方式复测。
