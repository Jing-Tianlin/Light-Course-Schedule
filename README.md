# 轻课表（Light Course Schedule）

一款简洁、本地优先的移动端大学课表应用。支持从 Word（`.docx`）一键导入课程表，自动解析课程名、周次、节次、地点、教师与班级，并按周查看课表。

## 功能

- **从 Word 导入课表**：选择 `.docx` 文件，自动解析课程安排并本地保存。
- **按周查看**：默认显示当前周；顶部左右按钮切换上一周/下一周，点周次可弹出周次选择（含「本周」快捷按钮）。
- **学期状态提示**：
  - 开学前显示「本学期尚未开始」；
  - 学期结束后显示「本学期已结束」，可一键查看最后一周。
- **一周 7 天同屏**：单屏铺满 7 天，仅纵向滚动，无需左右滑动。
- **课程卡片**：高度随文字自适应；按课程名稳定配色；显示课程名、地点、节次、周次。
- **无课日表情**：工作日 😴、周六 🛋️、周日 🎉。
- **课程详情**：点击课程卡片可查看时间、地点、教师、周次、类型、班级等完整信息。
- **设置**：自定义学期名称、开学日期（周一）、学期总周数、各节次作息时间。
- **清空课表**：设置页可一键删除全部导入课程。
- **数据持久化**：课程与设置保存在本地，重开 App 自动恢复。

## 支持的 Word 课表格式

解析器针对典型大学课表表格（表头为「时段 + 星期一~星期日」，左侧为节次）设计，并兼容多种写法：

- **星期**：`星期一 / 周一`，`星期日 / 周日 / 星期天 / 周天`。
- **课程代码**：`160527C051.01`、`202420251001273`、`CS101`、`MATH202` 等。
- **周次**：`(1~9周)`、`(10-17周)`、`(6周)`、`(第1~10,12周)`、`(9，11，12，13周)`、`(1~5,7~8周)`。
- **节次**：`(1-2节)`、`(4-5节)`、`(8节)`、`(第1-2节)`。
- **教师**：`崔立杰(2022592116)`、`丁英宏(1611)`、`迪拉热·海米提(2023591201)`。

> Word 课表没有统一标准。若某些自由排版/无课程代码的表格无法识别，可针对该文件的格式补充解析规则。

## 技术栈

| 分类 | 说明 |
| --- | --- |
| 框架 | Flutter（Material 3） |
| 状态管理 | `ChangeNotifier` + 单例 |
| 文件解析 | `archive`（解压 docx）+ `xml`（解析 document.xml） |
| 文件选择 | `file_picker` |
| 本地存储 | `shared_preferences` |
| 构建 | Gradle（Groovy DSL） |

## 项目结构

```
lib/
├── main.dart                       # 入口 + 底部 Tab 导航
├── data/
│   └── kebiao_data.dart            # 课表数据仓库与设置（ChangeNotifier）
├── models/
│   └── course.dart                 # Course / WeekRange / Placement / Section 模型
├── services/
│   ├── docx_parser.dart            # .docx 解析器
│   └── course_store.dart           # 本地持久化
├── screens/
│   ├── home_screen.dart            # 课表主页
│   ├── import_screen.dart          # Word 导入
│   ├── settings_screen.dart        # 设置
│   └── edit_schedule_screen.dart   # 作息时间编辑
├── utils/
│   ├── app_theme.dart              # 主题与品牌色
│   └── schedule_utils.dart         # 周次/日期计算
└── widgets/
    ├── week_schedule_view.dart     # 一周课表视图
    ├── course_card.dart            # 课程卡片
    └── course_detail_sheet.dart    # 课程详情弹窗

test/
├── widget_test.dart                # 基础 smoke test
└── model_utils_test.dart           # 模型与工具函数测试

tool/
└── fix_migration_permissions.ps1   # 迁移后权限修复脚本
```

## 构建与运行

### 环境要求

- Flutter SDK 3.x
- Dart SDK 3.x
- Android SDK / Android Studio（构建 APK 时需要）

### 运行

```bash
# 安装依赖
flutter pub get

# 调试运行（Chrome/Edge/WebServer）
flutter run -d chrome
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8080

# 构建调试 APK
flutter build apk --debug

# 构建发布 APK
flutter build apk --release
```

### APK 产物

```text
build/app/outputs/flutter-apk/app-release.apk
```

> 当前 release 包使用 debug 签名，方便直接安装测试；正式发布前请替换为自己的签名配置。

## 国内网络优化

如果依赖下载缓慢，可设置国内镜像后构建：

```powershell
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:GRADLE_USER_HOME = "D:\GradleHome"

flutter build apk --release
```

项目内 `android/settings.gradle` 与 `android/build.gradle` 已内置阿里云/腾讯云 Maven 镜像。

## 常见问题

### 1. Flutter 无法创建 `lockfile` 或提示“拒绝访问”

如果迁移过 Flutter/Gradle/用户缓存目录，可能出现权限问题。请以管理员身份运行：

```powershell
cd D:\TRAE\CODE\Kebiao\kebiao_app
powershell -ExecutionPolicy Bypass -File .\tool\fix_migration_permissions.ps1
```

### 2. Gradle 构建卡在下载依赖

首次使用新的 Gradle Home 时需要下载大量依赖，请耐心等待。如果网络较慢，建议使用国内镜像并复用已有的 Gradle 缓存目录。

### 3. 浏览器调试时无法自动打开

可改用 Web Server 模式：

```bash
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8080
```

然后手动访问 `http://127.0.0.1:8080`。

## 发布安装包

构建产物：

```text
build/app/outputs/flutter-apk/app-release.apk
```

发给他人时，接收方在手机上直接安装 `.apk` 文件即可（首次需允许「安装未知来源应用」）。
