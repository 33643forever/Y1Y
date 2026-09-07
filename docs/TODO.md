# TODO

根据代码审查和已知问题整理，按优先级排列。

## 高优先级

### [ ] 确认 OpenRouter "处理中" 问题是否已解决

- 现状：已添加 `request.timeoutInterval = 30`，但尚未在有 VPN/代理的环境下以真实 API Key 手工验收
- 建议：用户在配置了真实 Key 的情况下，在有 VPN/代理的环境测试流式回复
- 如果仍有卡住现象，可能需要增加 per-line 空闲超时

## 中优先级

### [ ] 自定义快捷键未实际生效

- 代码中已有 `HotkeyConfig` 模型，`SettingsManager` 已保存配置
- 但 `GlobalHotkeyManager` 硬编码了 `⌘E`（`kVK_ANSI_E + cmdKey`）
- 需要实现从配置读取快捷键并注册的逻辑

### [ ] `ContentView.swift` 为模板遗留代码

- 文件位于 `Y1Y/Views/ContentView.swift`
- 内容仅为 "Hello, world!" 占位视图，未被任何实际代码引用
- 建议清理删除

### [ ] Markdown 代码语法高亮

- 代码块目前为纯等宽字体，无语法高亮
- 如果产品需要，需调研合适的 macOS 原生语法高亮方案
- swift-markdown 不提供语法高亮，需要额外的词法分析器

## 低优先级

### [ ] 长回复性能优化

- 当前 MarkdownRenderStore 每 75ms 重新解析完整文本
- 非常长的回复可能产生可感知的卡顿
- 可考虑增量解析（只解析新增尾部），但需验证是否必要

### [ ] 错误信息中文化一致性

- 大部分错误提示使用中文，但 `AIError` 的错误描述为英文
- `AIError.invalidResponse` → "Invalid response from server."
- `AIError.httpError` → "HTTP \(code): \(body)"（body 可能包含英文）

### [ ] 测试覆盖完善

- 当前 23 项测试覆盖核心路径
- 未覆盖：真实 NSPanel 交互、多显示器场景、全屏应用环境

### [-] 设置页 UI 已优化（提示词编辑区域仍有改进空间）

- 浮窗面板已完成 C3 圆润卡片风格重设计（深色主题、胶囊按钮、统一高度）
- 提示词图标已改为 emoji 自由输入
- 设置页整体布局仍为基本功能布局，可参考 macOS 系统设置风格进一步优化

## 技术债

### [ ] 全局监听器生命周期管理

- `GlobalHotkeyManager` 通过 `static var activeInstance` 持有自身引用
- 这种模式在多个实例时可能产生问题
- 建议由 AppDelegate 统一持有实例

### [ ] 导入声明整理

- `PresetPromptView.swift` 顶部没有显式 import AppKit 但仍使用了 `NSEvent`
- 可能通过其他文件的导入间接可用，但建议显式声明依赖

### [ ] 测试使用 `SettingsManager.shared`

- 多个测试修改 `SettingsManager.shared` 的全局状态
- 测试间可能产生状态泄漏，建议测试中使用隔离的配置实例

### [ ] `AIService.directSession` 的代理绕过

- `connectionProxyDictionary = [:]` 可导致有代理的用户无法连接
- 当前已恢复该设置以保持认证头完整性
- 如果用户报告特定代理环境下的连接问题，需重新审视此设计决策
