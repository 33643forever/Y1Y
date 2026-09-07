# Changelog

本文件根据 Git 历史整理，按功能阶段分组。

## v0.9 — OpenRouter 分支 (当前)

### 基础与环境

- 统一最低 macOS 部署目标为 26.0
- 引入 swift-markdown 0.8.0 作为 Markdown 解析依赖
- 统一工程设置与 README 的系统要求描述

### 数据模型

- 新增 ResponsePanelSize、PanelPhase、PinState 等窗口状态模型
- 新增 BalanceSnapshot、OpenRouterConnectionState、OpenRouterAccountState 等账户状态模型
- 新增 PanelPreferencesStore（窗口尺寸持久化）
- 新增 BalanceCacheStore（余额缓存，作用域隔离）

### Markdown 渲染

- 支持标题、粗体、斜体、删除线、行内代码、链接的行内渲染
- 支持有序/无序列表、引用、分隔线、标题的块级渲染
- 代码块支持独立复制按钮（只复制代码正文）
- 不支持语法（表格、图片、HTML、脚注）降级为可读纯文本
- 流式 Markdown 节流解析（75ms 间隔）
- 流式未闭合标记（围栏、强调、链接）降级为普通文本
- 流式结束后执行最终解析

### 用户滚动

- 新增 ResponseScrollCoordinator，管理自动跟随/用户浏览状态
- 用户离开底部 24pt 以上时暂停自动滚动
- 用户回到底部 8pt 以内时恢复自动滚动

### 窗口缩放

- 提示词列表页保持固定紧凑尺寸，不支持缩放
- AI 回复页支持拖拽缩放，最小 380×360 pt
- 理论最大为最小值的五倍（1900×1800），同时受屏幕可见区域限制
- 缩放和移动后自动校正位置，确保窗口在屏幕内

### 窗口尺寸记忆

- 用户手动缩放后自动保存尺寸
- 跨浮窗关闭和再次打开保留
- 应用重启后仍可恢复
- 显示器配置变化时重新校正保存尺寸

### 多窗口

- 从单窗口控制器重构为多窗口管理器（FloatingPanelManager）
- 每个窗口拥有独立的 PanelSession（AIService、回复、固定状态）
- 新窗口自动错开排列（24pt 固定偏移，屏幕边缘自动回弹）

### 图钉固定

- AI 回复页右上角提供固定/取消固定按钮
- 固定后窗口提升到 `.floating` 层级，位于普通应用窗口上方
- 固定后外部点击不关闭
- 取消固定后不立即关闭，等待下一次外部点击
- 多个固定窗口可同时存在，互不影响

### 余额迁移

- 从浮窗中移除余额显示
- 设置页新增 OpenRouter 余额区域
- 打开设置页自动刷新
- 显示美元余额（两位小数）、相对刷新时间、连接状态
- 失败时保留历史缓存并标记为旧数据
- 非 OpenRouter 地址时隐藏整个区域
- API Key 为空时显示配置提醒

### 测试

- 18 项单元测试覆盖 Markdown 解析、窗口几何、账户状态
- Mock 网络测试覆盖首字节超时、HTTP 错误、空流、正常流、用户取消

### 修复

- 移除 `connectionProxyDictionary = [:]` 导致的代理配置冲突（回退后恢复）
- 添加 `request.timeoutInterval = 30` 到聊天流请求，解决请求长时间无响应仍显示"处理中"
- 推理开关关闭时不发送 `include_reasoning` 参数，避免部分模型误开启推理
- 缺失出站网络沙盒权限导致无法联网（修复后启用 `com.apple.security.network.client`）
- 图钉状态图标不随固定状态刷新
- 提示词列表初始尺寸动画导致新窗口错开竞态

### 文档

- README 更新为与当前实现一致的功能列表
- 技术方案和需求文档已更新实现状态
- 文件结构重组为按功能划分的目录
- 项目根 README 缩略为指引，完整内容迁移到 `docs/README.md`
- 生成可分发 DMG 安装包（Release 构建 + hdiutil 打包）

### UI 重新設計（C3 圆润卡片风格）

- 面板背景：`ultraThinMaterial` → 纯色 `#1c1c1e`，搭配深色高对比色调
- 面板圆角：10 → 16 pt
- 所有按钮统一为胶囊 pill 形状，`frame(height: 28)` 统一高度
- 输入框改为胶囊形（cornerRadius: 20），深色底色 + 边框
- 发送按钮从 SF Symbol 改为 👌 emoji，32×32 胶囊点按区域
- 代码块圆角 7 → 12 pt，底色加深 `#0a0a0c`
- 推理区域圆角 6 → 12 pt
- 引用、分隔线、标题颜色适配深色主题

### 布局调整

- 提示词列表宽度：280 → 210 pt，SwiftUI 层加显式 `frame(width:)` 防止 NSHostingView 撑宽
- 模型名称：提示词列表页居中；结果页移回左侧（返回按钮旁边），纯文字展示（无下拉、无底色）
- 结果页顶部按钮布局：`[‹] [模型名] [Spacer] [复制全部] [📌]`
- 复制全部按钮从底部 footer 移到右上角
- 右上角移除提示词标题，仅保留图钉
- 返回按钮改为纯图标（无文字）

### 图标与 emoji

- 默认提示词图标：SF Symbols → emoji（📖📝🌐✏️💡）
- 设置页图标选择器：从固定 Picker 改为 TextField，支持系统 emoji 键盘
- 菜单栏图标：sparkles → bolt.fill（⚡ 形状的 SF Symbol）
- 修复 `lockFocus()/unlockFocus()` 渲染 emoji 在 macOS 26 上的启动崩溃

### 其他

- 浮窗右上角移除推理开关（🧠 按钮）
- `.gitignore` 添加 `*.dmg` 规则
- 全部 23 项测试通过

## v0.8 — 初始版本 (历史)

- 基础浮窗功能（单窗口）
- 全局快捷键 ⌘E
- OpenAI 兼容 API 接入
- SSE 流式回复
- 自定义提示词
- 收藏模型管理
- 设置页面

## 说明

- 项目始于 2026 年 3 月，作者 tape
- 发布渠道：GitHub Releases
- 用户反馈：GitHub Issues（模板已准备，待仓库启用）
- 以上版本阶段编号为推断，Git 无对应 tag
- 早期提交（af46ad2 first commit）之前的历史不在本仓库中
