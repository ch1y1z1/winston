# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Winston 是一个用 SwiftUI 构建的原生 iOS Reddit 客户端，支持 iOS 17+ 和 macOS。应用采用现代的 SwiftUI 架构，具有主题系统、Reddit API 集成、Core Data 持久化和复杂的导航系统。

## 核心架构

### 应用结构
- **入口点**: `winstonApp.swift` - 主应用结构体，包含 Core Data 设置和快捷操作
- **主内容**: `AppContent.swift` - 根内容视图，处理主题、生物识别认证和场景生命周期
- **导航系统**: 基于 `Router.swift` 的自定义导航，支持标签内导航和手势
- **标签界面**: `Tabber` 组件管理主要的标签导航

### 数据层
- **持久化**: 使用 Core Data 配合 CloudKit (`NSPersistentCloudKitContainer`)
- **缓存模型**: `CachedSub`, `CachedMulti`, `CachedFilter` 等管理离线数据
- **主要模型**: `Post`, `Comment`, `Subreddit`, `User`, `Multi` 等 Reddit 实体

### Reddit API 集成
- **认证管理**: `RedditCredentialsManager` 处理 OAuth 认证
- **API 客户端**: `RedditAPI.swift` 中的模块化 API 调用
- **端点组织**: 按功能分组的 API 调用（posts, comments, subs, user 等）

### 主题系统
- **主题模型**: `WinstonTheme` 和相关组件定义应用外观
- **主题商店**: 在线主题下载和共享功能
- **自定义主题**: 用户可创建和修改主题

## 常用开发命令

### 构建和运行
```bash
# 在 Xcode 中打开项目
open winston.xcodeproj

# 或者使用 xcodebuild（需要指定 scheme）
xcodebuild -project winston.xcodeproj -scheme winston -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### 测试
```bash
# 运行单元测试
xcodebuild test -project winston.xcodeproj -scheme winston -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 重要目录结构

- **`winston/views/`** - SwiftUI 视图组件，按功能组织
- **`winston/models/`** - 数据模型和 API 客户端
- **`winston/components/`** - 可重用的 UI 组件
- **`winston/utils/`** - 辅助工具和实用函数
- **`winston/extensions/`** - Swift 扩展，按类型组织
- **`managed/`** - Core Data 生成的类文件

## 关键组件

### 导航 (`winston/Navigation/`)
- `Router.swift` - 自定义导航管理器，支持嵌套导航栈
- `Nav.swift` - 导航目标定义
- `GlobalDestinationsProvider.swift` - 全局导航状态管理

### UI 组件 (`winston/components/`)
- **Links**: 各种链接组件 (PostLink, CommentLink, UserLink 等)
- **Media**: 媒体处理 (图片、视频、GIF 查看器)
- **Modals**: 模态窗口 (回复、新帖子等)

### 设置系统 (`winston/views/Settings/`)
- 模块化设置面板
- 主题编辑器
- 认证设置
- 行为和外观定制

## 开发注意事项

### Core Data
- 主上下文用于 UI 更新
- 后台上下文 (`primaryBGContext`) 用于 API 数据处理
- 使用 CloudKit 同步，需要正确的 entitlements 设置

### 主题系统
- 所有 UI 组件都应支持主题化
- 使用 `@Environment(\.useTheme)` 访问当前主题
- 新组件需要相应的主题模型定义

### Reddit API
- 需要用户提供的 Reddit API 凭据
- 所有 API 调用都应处理错误和加载状态
- 支持多账户切换

### 本地化
- 使用 `Localizable.xcstrings` 进行字符串本地化
- 支持多语言界面

### 构建配置
- 最低支持 iOS 17.0
- 使用 entitlements 进行权限管理
- Safari Web Extension 集成支持