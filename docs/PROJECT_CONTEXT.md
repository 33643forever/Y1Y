# Project Context

## 项目信息

- **始于**：2026 年 3 月
- **作者**：tape
- **许可**：MIT
- **发布渠道**：GitHub Releases
- **用户反馈**：GitHub Issues（待启用）

## 项目定位

Y1Y 是一个 macOS 菜单栏常驻的全局 AI 文本处理工具。用户在其他应用中选中文本，按下全局快捷键即可唤出浮窗，无需离开当前应用即可调用 AI 模型。

## 技术栈

| 层 | 技术 |
|---|---|
| 语言 | Swift 5.0 |
| UI 框架 | SwiftUI + AppKit 混合；深色高对比主题（`#1c1c1e`），圆润卡片设计 |
| 窗口系统 | NSPanel (KeyablePanel) |
| 网络 | URLSession + async/await |
| 流式传输 | SSE (Server-Sent Events) via `URLSession.AsyncBytes` |
| Markdown 解析 | swift-markdown 0.8.0 (swiftlang) |
| 持久化 | UserDefaults + Keychain |
| 并发 | Swift Concurrency (async/await, Task), Combine |
| 测试 | XCTest（23 项） |
| 构建 | Xcode (File System Synchronized Groups) |
| 最低部署 | macOS 26.0 |

### 外部依赖

- `swift-markdown` 0.8.0 — 将 Markdown 源文解析为语法树
- `swift-cmark` 0.8.0 — swift-markdown 的底层 C 解析器（传递依赖）

工程通过 Swift Package Manager 管理依赖，版本精确锁定。

## 项目结构

```
Y1Y/
├── App/             应用入口和生命周期
├── Models/          纯数据类型定义
├── Services/        网络请求和系统服务
├── Panels/          窗口管理和几何约束
├── Markdown/        Markdown 解析、渲染和滚动
├── Views/           SwiftUI 视图组件
├── Settings/        设置管理和账户状态
└── Utilities/       Keychain 等基础工具
Y1YTests/          单元测试
```

## 核心模块

### 1. App (应用入口)

- `Y1YApp.swift` — `@main` 入口，使用 `@NSApplicationDelegateAdaptor` 桥接到 AppDelegate
- `AppDelegate.swift` — 应用生命周期，状态栏菜单，快捷键注册，设置窗口管理

应用设置为 `.accessory` 激活策略（无 Dock 图标，仅菜单栏）。

### 2. Services (服务层)

- `AIService` — 聊天流请求（SSE）、模型列表获取、推理模式控制。状态以 `@Published` 属性暴露
- `GlobalHotkeyManager` — 使用 Carbon Event Manager 注册全局快捷键 `⌘E`
- `SelectionReader` — 通过模拟 `⌘C` 读取选中文本
- `OpenRouterAccountClient` — OpenRouter 余额查询和连接检查，使用 `OpenRouterAccountServing` 协议实现可测试

### 3. Panels (窗口管理)

- `FloatingPanelManager` — 多窗口管理器，负责创建、登记、销毁浮窗
- `FloatingPanelController` — 单个浮窗的 AppKit 控制器，管理 NSPanel 生命周期
- `PanelSession` — 独立窗口会话，持有 AIService、固定状态、页面阶段
- `PanelGeometryService` — 窗口尺寸和位置约束计算（最小 380×360，五倍上限，屏幕可见区域）
- `PanelCascadePlacementService` — 新窗口自动错开排列算法
- `PanelPinButton` — 固定/取消固定按钮（胶囊 pill 样式）
- `PanelResizeCapability` — 窗口缩放能力切换
- `PanelWindowLevelPolicy` — 固定/未固定窗口层级策略（`.floating` vs `.normal`）
- `OutsideClickMonitor` — 全局鼠标事件监听，统一处理外部点击关闭

### 4. Markdown (渲染)

- `MarkdownRenderStore` — 节流解析状态机，以 75ms 间隔在后台解析
- `MarkdownStreamingFallbackPolicy` — 流式未闭合标记检测（围栏、强调、链接）
- `MarkdownInlineView`/`MarkdownBlockView` — 行内和块级 Markdown 渲染器
- `MarkdownCodeBlockView` — 带独立复制按钮的代码块
- `MarkdownPlainTextRenderer` — 不支持语法（表格、图片、HTML 等）降级为纯文本
- `ResponseScrollCoordinator` — 用户滚动优先的自动滚动协调器
- `StreamingMarkdownContentView` — 流式 Markdown 内容视图（在普通文本和 Markdown 间切换）

### 5. Settings (设置)

- `SettingsManager` — 单例设置管理器，属性写时持久化到 UserDefaults/Keychain
- `OpenRouterAccountViewModel` — 余额自动刷新、连接状态、缓存管理
- `BalanceCacheStore` — 按作用域（baseURL + API Key 哈希）缓存余额

## 数据流

### 主流程

1. 用户选中文本 → 按 `⌘E`
2. `GlobalHotkeyManager` 触发回调 → `AppDelegate.handleHotkeyTriggered()`
3. `SelectionReader.getSelectedText()` 模拟 `⌘C` 读取选中文本
4. `FloatingPanelManager.show(at:with:)` 创建 `PanelSession` + `FloatingPanelController`
5. 浮窗显示提示词列表，用户选择一个提示词
6. `AIService.sendRequest()` 发起 SSE 流式请求
7. 流式数据经 `MarkdownRenderStore` 节流解析后渲染到 SwiftUI 视图
8. `ResponseScrollCoordinator` 管理自动滚动/用户滚动优先级
9. 回复结束 → `isLoading = false` → 最终 Markdown 渲染

### 多窗口流程

1. 固定一个结果 → 再次按 `⌘E` → 创建新会话
2. 新窗口自动错开排列，与已有窗口互不影响
3. 每个窗口独立管理：回复流、缩放、固定、移动

### 余额流程

1. 打开设置页 → `OpenRouterAccountViewModel.refresh()`
2. 判断 API 地址是否为 OpenRouter → 若不是则隐藏余额区域
3. 判断 API Key 是否为空 → 为空则显示 "请先配置 API Key"
4. 调用 `checkConnection()` → 失败则显示连接失败状态
5. 调用 `fetchAvailableBalance()` → 成功则更新缓存和 UI
6. 失败且有历史缓存 → 显示旧数据并标记为 `isStale`

## 开发规范（推断）

- 单个 Swift 文件对应一个主要类型或一组紧密相关的类型
- 使用 `ObservableObject` + `@Published` 管理 UI 状态
- 网络层使用 `async/await` + `Task`
- 测试使用 `@testable import Y1Y` 访问内部类型
- 不引入外部依赖超过最小值（当前仅 swift-markdown）
- 中文作为 UI 语言，错误提示和帮助文字使用中文
