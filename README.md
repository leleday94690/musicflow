# MusicFlow

MusicFlow 是一个面向个人音乐收藏的桌面音乐管理应用，前端使用 Flutter，后端使用 Go + MySQL。项目重点解决本地曲库整理、在线检索下载、歌词与封面维护、歌单收藏、播放队列、每日热度统计和桌面端应用内更新。

## 项目简介

MusicFlow 的目标是把分散的音乐文件、在线下载、播放状态和个人偏好整理在一个连续的桌面体验里。

- **曲库管理**：维护歌曲标题、歌手、专辑、封面、歌词、时长、音质等信息。
- **在线检索与下载**：通过后端接口检索歌曲并加入个人曲库。
- **播放体验**：支持播放、暂停、上一首、下一首、播放进度、播放模式和播放队列。
- **歌单与收藏**：支持收藏常听歌曲，并按场景维护歌单。
- **每日热度**：根据播放历史统计每日热门歌曲。
- **下载管理**：集中展示下载任务、状态和错误信息。
- **应用内更新**：客户端自动检查新版本，下载完成后引导安装。
- **桌面体验**：支持 macOS 和 Windows，Windows 支持系统托盘、最小化到托盘和退出确认。

## 当前版本

| 平台 | 当前线上版本 | 说明 |
| --- | --- | --- |
| macOS | `1.0.24+25` | 优化下载管理、最近播放和个人存储统计展示。 |
| Windows | `1.0.24+25` | 同步下载管理、最近播放和个人存储统计展示优化。 |

版本号来自 `frontend/pubspec.yaml`：

```yaml
version: 1.0.24+25
```

其中：

- **`1.0.24`**：展示给用户看的版本号。
- **`25`**：构建号，用于判断是否有更新。

发布新版本时需要同时递增版本号和构建号，例如：

```text
1.0.24+25 -> 1.0.25+26
```

## 项目结构

```text
music/
├── backend/                         # Go + MySQL 后端
│   ├── cmd/server/                  # 后端启动入口
│   ├── internal/                    # API、配置、数据访问等核心代码
│   ├── migrations/                  # MySQL 初始化脚本
│   └── releases/manifest.example.json
│                                      # 应用更新 manifest 示例
├── frontend/                        # Flutter 桌面客户端
│   ├── lib/                         # Flutter 页面、服务和状态逻辑
│   ├── macos/                       # macOS 平台工程
│   ├── windows/                     # Windows 平台工程和安装器配置
│   └── pubspec.yaml                 # Flutter 依赖与版本号
├── website/                         # 官网静态页面
│   └── index.html
└── README.md
```

## 本地运行

### 环境要求

- **Flutter**：用于运行桌面客户端。
- **Go**：后端服务。
- **MySQL 8+**：存储曲库、用户、歌单、下载记录等数据。
- **macOS 或 Windows**：桌面端构建与测试环境。

### 初始化数据库

首次部署或本地初始化时，需要执行数据库迁移：

```bash
mysql -u<user> -p < backend/migrations/001_init.sql
```

### 启动后端

```bash
cd backend
cp .env.example .env.local
make dev
```

运行前需要在 `backend/.env.local` 中配置：

```text
MYSQL_DSN=musicflow_user:password@tcp(127.0.0.1:3306)/musicflow?charset=utf8mb4&parseTime=true&loc=Local
APP_CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000,http://localhost:8080,http://127.0.0.1:8080
MUSICFLOW_TOKEN_SECRET=change_this_to_a_long_random_secret
MUSICFLOW_ADMIN_PASSWORD=set_a_strong_password_once
```

说明：

- **`MYSQL_DSN`**：MySQL 连接字符串，必填。
- **`APP_CORS_ORIGINS`**：允许访问后端的前端来源。
- **`MUSICFLOW_TOKEN_SECRET`**：登录 token 签名密钥，生产环境必须使用足够长的随机字符串。
- **`MUSICFLOW_ADMIN_PASSWORD`**：首次启动时创建或重置管理员密码。
- **`MUSICFLOW_DEMO_PASSWORD`**：生产环境建议留空。

### 启动前端

```bash
cd frontend
cp .env.example .env.local
make dev
```

前端默认连接：

```text
http://127.0.0.1:8080
```

如果后端地址不同，可以在 `frontend/.env.local` 中设置：

```text
MUSICFLOW_API_BASE_URL=http://127.0.0.1:8080
```

也可以指定 Flutter 运行设备：

```bash
make dev FLUTTER_DEVICE=macos
make dev FLUTTER_DEVICE=windows
```

## 常用检查命令

### 后端测试

```bash
cd backend
make test
```

### 前端静态分析

```bash
cd frontend
make analyze
```

### 前端测试

```bash
cd frontend
make test
```

### 格式化指定 Dart 文件

```bash
cd frontend
dart format lib/main.dart lib/src/update_service.dart
```

## 应用内更新机制

MusicFlow 的客户端更新由后端 manifest 控制。客户端启动后会请求更新接口，后端根据平台、当前版本和构建号判断是否返回新版本。

### 更新接口

检查更新：

```text
GET /api/app-update/latest?platform=<platform>&channel=stable&version=<version>&buildNumber=<buildNumber>
```

示例：

```text
GET /api/app-update/latest?platform=windows&channel=stable&version=1.0.22&buildNumber=23
```

下载更新：

```text
GET /api/app-update/download/<fileName>
```

示例：

```text
GET /api/app-update/download/MusicFlow-Setup-1.0.24+25.exe
```

### manifest 文件

本地示例文件：

```text
backend/releases/manifest.example.json
```

生产环境默认路径：

```text
/opt/musicflow/releases/manifest.json
```

后端会读取 `MUSICFLOW_UPDATE_MANIFEST` 指定的 manifest；如果没有设置，则默认读取上面的生产路径。

manifest 中每个平台一条记录：

```json
{
  "platform": "windows",
  "channel": "stable",
  "version": "1.0.24",
  "buildNumber": 25,
  "releaseNotes": "同步下载管理、最近播放与个人存储统计展示优化，改善页面加载反馈和数据呈现稳定性。",
  "downloadUrl": "http://8.136.123.14/api/app-update/download/MusicFlow-Setup-1.0.24+25.exe",
  "fileName": "MusicFlow-Setup-1.0.24+25.exe",
  "fileSize": 11088235,
  "sha256": "c6fe8260b27374fb2679b17664330b042988572c7f3177040f5cc538fd4820f2",
  "mandatory": false
}
```

字段说明：

- **`platform`**：平台，支持 `macos` 和 `windows`。
- **`channel`**：更新通道，目前使用 `stable`。
- **`version`**：展示版本号。
- **`buildNumber`**：构建号，必须递增。
- **`releaseNotes`**：更新说明，客户端会展示。
- **`downloadUrl`**：安装包下载地址。
- **`fileName`**：安装包文件名。
- **`fileSize`**：安装包字节大小。
- **`sha256`**：安装包 SHA256 校验值。
- **`mandatory`**：是否强制更新。

### 更新判断规则

后端会按 `platform + channel` 找到最新记录，然后比较：

```text
manifest.version + manifest.buildNumber
```

和客户端传入的：

```text
version + buildNumber
```

只有 manifest 中的版本更高时才返回：

```json
{
  "available": true
}
```

如果客户端已经是最新版本，则返回：

```json
{
  "available": false
}
```

## 如何发布新版本

发布新版本时，推荐按下面顺序执行：

1. **修改代码并完成测试**
2. **更新 `frontend/pubspec.yaml` 版本号**
3. **构建对应平台安装包**
4. **计算安装包大小和 SHA256**
5. **更新 `backend/releases/manifest.example.json`**
6. **更新 `website/index.html` 官网下载链接和版本说明**
7. **上传安装包到服务器**
8. **上传 manifest 到服务器**
9. **上传官网页面到服务器**
10. **验证更新接口和下载链接**
11. **提交并推送代码**

## macOS 如何更新

### 1. 修改版本号

编辑：

```text
frontend/pubspec.yaml
```

例如从：

```yaml
version: 1.0.22+23
```

改为：

```yaml
version: 1.0.24+25
```

### 2. 构建 macOS 应用

```bash
cd frontend
flutter build macos --release
```

构建完成后，产物通常在：

```text
frontend/build/macos/Build/Products/Release/
```

### 3. 制作 DMG

将 release 目录中的 `MusicFlow.app` 打包成 DMG，文件名建议使用：

```text
MusicFlow-1.0.24.dmg
```

macOS 的 manifest `fileName`、官网链接和实际上传文件名需要保持一致。

### 4. 计算文件大小和 SHA256

```bash
stat -f '%z' MusicFlow-1.0.24.dmg
shasum -a 256 MusicFlow-1.0.24.dmg
```

### 5. 更新 manifest 的 macOS 条目

修改：

```text
backend/releases/manifest.example.json
```

更新 macOS 部分：

```json
{
  "platform": "macos",
  "channel": "stable",
  "version": "1.0.24",
  "buildNumber": 25,
  "releaseNotes": "这里填写 macOS 本次更新内容。",
  "downloadUrl": "http://8.136.123.14/api/app-update/download/MusicFlow-1.0.24.dmg",
  "fileName": "MusicFlow-1.0.24.dmg",
  "fileSize": 0,
  "sha256": "替换为实际 sha256",
  "mandatory": false
}
```

### 6. 上传 macOS 安装包

将 DMG 上传到服务器：

```text
/opt/musicflow/releases/files/
```

### 7. 更新官网 macOS 链接

修改：

```text
website/index.html
```

将 macOS 下载链接改为：

```text
/releases/MusicFlow-1.0.24.dmg
```

### 8. 上传 manifest 和官网

将本地 manifest 上传为：

```text
/opt/musicflow/releases/manifest.json
```

将官网首页上传为：

```text
/var/www/musicflow-site/index.html
```

### 9. 验证 macOS 更新

检查旧版本是否能看到更新：

```bash
curl 'http://8.136.123.14/api/app-update/latest?platform=macos&channel=stable&version=1.0.22&buildNumber=23'
```

预期：

```json
{
  "available": true
}
```

检查当前版本不会重复提示：

```bash
curl 'http://8.136.123.14/api/app-update/latest?platform=macos&channel=stable&version=1.0.24&buildNumber=25'
```

预期：

```json
{
  "available": false
}
```

## Windows 如何更新

### 1. 修改版本号

编辑：

```text
frontend/pubspec.yaml
```

例如：

```yaml
version: 1.0.24+25
```

Windows 用户如果已经安装了上一个版本，必须让 `buildNumber` 递增，否则客户端会认为自己已经是最新版。

### 2. 构建 Windows 应用

在 Windows 环境中执行：

```bash
cd frontend
flutter build windows --release
```

### 3. 生成 Windows 安装包

Windows 安装器配置在：

```text
frontend/windows/installer/musicflow.iss
```

使用 Inno Setup 生成安装包。文件名建议：

```text
MusicFlow-Setup-1.0.24+25.exe
```

如果同时提供 ZIP 包，建议文件名：

```text
MusicFlow-Windows-1.0.24+25.zip
```

### 4. 计算文件大小和 SHA256

macOS/Linux 上可以使用：

```bash
stat -f '%z' MusicFlow-Setup-1.0.24+25.exe
shasum -a 256 MusicFlow-Setup-1.0.24+25.exe
```

Windows PowerShell 可以使用：

```powershell
(Get-Item .\MusicFlow-Setup-1.0.24+25.exe).Length
Get-FileHash .\MusicFlow-Setup-1.0.24+25.exe -Algorithm SHA256
```

### 5. 更新 manifest 的 Windows 条目

修改：

```text
backend/releases/manifest.example.json
```

更新 Windows 部分：

```json
{
  "platform": "windows",
  "channel": "stable",
  "version": "1.0.24",
  "buildNumber": 25,
  "releaseNotes": "这里填写 Windows 本次更新内容。",
  "downloadUrl": "http://8.136.123.14/api/app-update/download/MusicFlow-Setup-1.0.24+25.exe",
  "fileName": "MusicFlow-Setup-1.0.24+25.exe",
  "fileSize": 0,
  "sha256": "替换为实际 sha256",
  "mandatory": false
}
```

### 6. 上传 Windows 安装包

将安装包上传到：

```text
/opt/musicflow/releases/files/
```

至少需要上传：

```text
MusicFlow-Setup-1.0.24+25.exe
```

如果官网或备份需要，也可以同时上传：

```text
MusicFlow-Windows-1.0.24+25.zip
```

### 7. 更新官网 Windows 链接

修改：

```text
website/index.html
```

将 Windows 下载链接改为：

```text
/releases/MusicFlow-Setup-1.0.24+25.exe
```

### 8. 上传 manifest 和官网

将本地 manifest 上传为：

```text
/opt/musicflow/releases/manifest.json
```

将官网首页上传为：

```text
/var/www/musicflow-site/index.html
```

### 9. 验证 Windows 更新

检查旧版本是否能看到更新：

```bash
curl 'http://8.136.123.14/api/app-update/latest?platform=windows&channel=stable&version=1.0.23&buildNumber=24'
```

预期：

```json
{
  "available": true
}
```

检查当前版本不会重复提示：

```bash
curl 'http://8.136.123.14/api/app-update/latest?platform=windows&channel=stable&version=1.0.24&buildNumber=25'
```

预期：

```json
{
  "available": false
}
```

检查下载链接：

```bash
curl -I 'http://8.136.123.14/api/app-update/download/MusicFlow-Setup-1.0.24+25.exe'
curl -I 'http://8.136.123.14/releases/MusicFlow-Setup-1.0.24+25.exe'
```

预期返回：

```text
HTTP/1.1 200 OK
```

## Windows 更新注意事项

Windows 应用内更新由当前正在运行的旧客户端发起，所以：

- **旧客户端更新到新安装包时，执行的是旧客户端里的 updater 逻辑。**
- **新 updater 逻辑只能影响“这个新版本之后”的下一次更新。**

因此，如果修复的是 Windows updater 本身，推荐发布一个新的递增版本，例如：

```text
1.0.23+24 -> 1.0.24+25
```

不要用同一个版本号覆盖旧安装包，否则已经安装旧版本的用户可能不会收到更新提示。

## 官网更新

官网文件：

```text
website/index.html
```

官网线上路径：

```text
/var/www/musicflow-site/index.html
```

官网下载链接通常使用：

```text
/releases/<fileName>
```

该路径由服务器映射到 release 文件目录。更新官网时需要同步修改：

- **首页展示版本**
- **LATEST UPDATE 文案**
- **macOS 下载链接**
- **Windows 下载链接**
- **更新说明卡片**

## 发布后验证清单

每次发布后都建议检查：

- **manifest JSON 合法**

```bash
python3 -m json.tool backend/releases/manifest.example.json >/dev/null
```

- **旧版本能收到更新**

```bash
curl 'http://8.136.123.14/api/app-update/latest?platform=windows&channel=stable&version=<oldVersion>&buildNumber=<oldBuild>'
```

- **当前版本不会重复提示**

```bash
curl 'http://8.136.123.14/api/app-update/latest?platform=windows&channel=stable&version=<newVersion>&buildNumber=<newBuild>'
```

- **API 下载链接正常**

```bash
curl -I 'http://8.136.123.14/api/app-update/download/<fileName>'
```

- **官网下载链接正常**

```bash
curl -I 'http://8.136.123.14/releases/<fileName>'
```

- **官网首页已经显示新版本**

```bash
curl -s http://8.136.123.14/ | grep '<newVersion>'
```

## 生产部署注意事项

- **数据库备份**：定期备份 MySQL。
- **音乐文件备份**：定期备份后端音乐存储目录。
- **CORS 限制**：生产环境只允许可信官网或客户端来源。
- **密钥管理**：不要把 `.env.local`、数据库密码、token secret、SSH 私钥提交到仓库。
- **更新包校验**：每次发布都要记录安装包大小和 SHA256。
- **版本号递增**：发布给用户的更新必须递增 `buildNumber`。
- **对象存储建议**：如果未来用户量变大，音频文件建议迁移到对象存储和 CDN，后端只返回授权播放 URL。

## 曲库数据归属

MusicFlow 的歌曲数据分为两类：

- **公共曲库歌曲**：由管理员创建，展示在所有用户的“全部歌曲”中。
- **个人下载歌曲**：普通用户通过在线搜索下载后进入自己的下载空间，不污染公共曲库。

## 最近更新记录

### Windows `1.0.23+24`

- 修复 Windows 应用内更新安装时可能出现黑色终端窗口并卡住的问题。
- 移除 updater 脚本中的 `tasklist | findstr` 等待循环。
- 优化窗口关闭确认弹窗，支持取消、最小化到托盘和退出应用。
- 优化 Windows 托盘菜单，补充隐藏到托盘和退出入口。

### macOS / Windows `1.0.22+23`

- 优化播放详情页信息层级和骨架屏体验。
- 优化搜索结果切换，减少白屏和闪烁。
- 优化播放队列，支持分页加载和虚拟渲染。
- 接入应用内更新 manifest 和下载接口。
