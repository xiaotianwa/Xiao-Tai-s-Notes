# 宝塔部署说明

## 域名规划

```text
api.xthblog.site   -> 后端 API，反代到 127.0.0.1:3100
admin.xthblog.site -> 管理端静态站点
```

DNS 解析需要把 `api` 和 `admin` 都解析到服务器公网 IP。

## 使用当前最新本地代码刷新服务器

服务器只需要保留运行后端和管理端所需的 `xiaotai_server` 目录。旧的增量包、临时上传目录、APP 原型图、截图、文档、`.idea`、`.vscode`、本地日志、旧 `dist`、旧 `node_modules` 都属于服务器无关内容，可以删除。生产数据和密钥不要删：

```text
/www/wwwroot/xiaotai/xiaotai_server/backend/.env
/www/wwwroot/xiaotai/xiaotai_server/backend/data
/www/wwwroot/xiaotai/xiaotai_server/backend/storage
/www/wwwroot/xiaotai/xiaotai_server/admin/.env.production
```

推荐把本地最新的 `xiaotai_server` 上传/同步到服务器的：

```text
/www/wwwroot/xiaotai/xiaotai_server
```

同步时不要覆盖上面列出的生产 `.env`、数据库和上传文件。同步完成后，在宝塔终端执行仓库里的脚本：

```bash
cd /www/wwwroot/xiaotai
bash deploy/baota-refresh-current-code.sh
```

如果你没有把 `deploy` 目录上传到服务器，可以直接在宝塔终端按下面后端和管理端章节的命令手动执行。

## 需要填写的位置

后端生产环境变量填写在：

```text
/www/wwwroot/xiaotai/xiaotai_server/backend/.env
```

可从 `xiaotai_server/backend/.env.production.example` 复制。至少需要确认：

```env
NODE_ENV=production
PORT=3100
PUBLIC_BASE_URL=https://api.xthblog.site
CORS_ORIGINS=https://admin.xthblog.site,https://xthblog.site
DATABASE_URL=file:../data/xiaotai.db
JWT_ACCESS_SECRET=填写强随机字符串
JWT_REFRESH_SECRET=填写另一个强随机字符串
COS_ENABLED=false
```

如果启用腾讯云 COS，把 `COS_ENABLED=true`，并继续填写 `COS_SECRET_ID`、`COS_SECRET_KEY`、`COS_BUCKET`、`COS_REGION`、`COS_PUBLIC_BASE_URL`。

管理端构建变量填写在：

```text
/www/wwwroot/xiaotai/xiaotai_server/admin/.env.production
```

可从 `xiaotai_server/admin/.env.production.example` 复制。截图里的提示就是这里缺少 `VITE_ADMIN_ACCESS_PASSWORD` 导致的：

```env
VITE_API_BASE_URL=https://api.xthblog.site/api/v1
VITE_ADMIN_ACCESS_PASSWORD=填写进入管理端登录页前的访问密码
```

注意：`VITE_ADMIN_ACCESS_PASSWORD` 是构建期变量，填写或修改后必须在 `admin` 目录重新执行 `npm run build`，刷新浏览器后才会生效。

首次创建管理员账号时，在后端目录临时执行：

```bash
cd /www/wwwroot/xiaotai/xiaotai_server/backend
ADMIN_INIT_USERNAME=admin ADMIN_INIT_PASSWORD='填写至少8位强密码' ADMIN_INIT_NICKNAME='小泰管理员' npm run seed:admin
```

## 后端

后端目录：

```text
/www/wwwroot/xiaotai/xiaotai_server/backend
```

常用命令：

```bash
cd /www/wwwroot/xiaotai/xiaotai_server/backend
npm ci
npm run prisma:generate
npx prisma migrate deploy
npm run build
pm2 start /www/wwwroot/xiaotai/xiaotai_server/ecosystem.config.cjs
pm2 save
```

查看状态：

```bash
pm2 status
pm2 logs xiaotai-backend
curl http://127.0.0.1:3100/health
```

## 管理端

管理端目录：

```text
/www/wwwroot/xiaotai/xiaotai_server/admin
```

构建命令：

```bash
cd /www/wwwroot/xiaotai/xiaotai_server/admin
npm ci
npm run build
```

宝塔网站根目录指向：

```text
/www/wwwroot/xiaotai/xiaotai_server/admin/dist
```

## Nginx 反代

API 站点 `api.xthblog.site`：

```nginx
location / {
    proxy_pass http://127.0.0.1:3100;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

管理端站点 `admin.xthblog.site` 需要 SPA 回退：

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

## SSL

在宝塔 `网站 -> SSL` 给 `api.xthblog.site` 和 `admin.xthblog.site` 分别申请 Let's Encrypt 证书，并开启强制 HTTPS。APP 正式包使用：

```bash
flutter build apk --release --dart-define=XIAOTAI_API_BASE_URL=https://api.xthblog.site/api/v1
```
