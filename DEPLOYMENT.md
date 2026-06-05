# 服务器域名部署

## 后端

复制 `xiaotai_server/backend/.env.production.example` 为生产环境 `.env`。当前推荐域名规划：

- API：`api.xthblog.site`
- 管理端：`admin.xthblog.site`
- 可选主页/管理端入口：`xthblog.site`

```env
NODE_ENV=production
PUBLIC_BASE_URL=https://api.xthblog.site
CORS_ORIGINS=https://admin.xthblog.site,https://xthblog.site
```

`CORS_ORIGINS` 使用英文逗号分隔。管理端和 API 同域部署时通常不需要跨域；如果管理端是独立域名，必须把管理端域名写入 `CORS_ORIGINS`。

## 管理端

同域部署时，生产构建默认请求 `/api/v1`，不需要配置 `VITE_API_BASE_URL`。

跨域部署时，在 `xiaotai_server/admin/.env.production` 中配置：

```env
VITE_API_BASE_URL=https://api.xthblog.site/api/v1
```

## APP

正式包使用服务器域名构建：

```powershell
cd E:\xiaotairiji\xiaotai_life
flutter build apk --release --dart-define=XIAOTAI_API_BASE_URL=https://api.xthblog.site/api/v1
```

本地真机/模拟器调试仍可继续使用局域网或模拟器地址：

```powershell
flutter run --dart-define=XIAOTAI_API_BASE_URL=http://10.0.2.2:3100/api/v1
```

## 推荐 Nginx 路由

```text
https://admin.xthblog.site/        -> 管理端静态文件
https://admin.xthblog.site/api/v1  -> 反代后端 http://127.0.0.1:3100/api/v1
```

如果采用 API 独立子域名：

```text
https://api.xthblog.site/api/v1 -> 反代后端 http://127.0.0.1:3100/api/v1
```
