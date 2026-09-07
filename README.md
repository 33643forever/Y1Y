# ⚡ Y1Y — 选中文字，按 `⌘E`，完事。

**Y1Y** 是一个躺在你 macOS 菜单栏里的 AI 小助手。不占 Dock，不弹窗骚扰，只在你想用的时候出现。

在任何应用里选中一段文字，按下 `⌘E`，一个精致的小浮窗就会出现在你的光标旁边。选个提示词，AI 就开始干活了。

---

## 它能干什么？

**📖 解释** — 选中一个看不懂的术语，让它给你讲明白  
**📝 总结** — 长篇大论？一键提炼要点  
**🌐 翻译** — 选中外文，秒变中文  
**✏️ 润色** — 写得不够顺？它帮你捋一捋  
**💡 续写** — 写了一半卡住了？让它接着来

当然你也可以**自己写提示词**，想让它干啥都行。

## 长什么样？

深色磨砂面板 + 圆润胶囊按钮，macOS 原生感拉满。支持多窗口、可缩放、可固定，用起来像系统的一部分。

## 快速上手

```bash
git clone https://github.com/yourusername/Y1Y.git
cd Y1Y
open Y1Y.xcodeproj
# 按 ⌘R 运行
```

或者去 [Releases](https://github.com/33643forever/Y1Y/releases/tag/macOS) 下载 `.dmg` 直接装。

### 第一次用

1. 启动 Y1Y，**授予辅助功能权限**（这样才能读到你的选中文字）
2. 点菜单栏 ⚡ 图标 → "设置"
3. 填上你的 API Base URL 和 API Key
4. 点"刷新模型"加载模型列表
5. 随便找个应用，选中文字，按 `⌘E`

## 支持的模型

Y1Y 兼容任何 OpenAI 标准 API，所以基本上你能想到的服务都能用：

| 服务 | 地址 |
|---|---|
| **OpenAI** | `https://api.openai.com/v1` |
| **OpenRouter** | `https://openrouter.ai/api/v1` |
| **DeepSeek** | `https://api.deepseek.com` |
| **Claude (via OpenRouter)** | 同上 |
| **Azure OpenAI** | 你的专属地址 |
| **Ollama** (本地) | `http://localhost:11434/v1` |
| **LM Studio** (本地) | `http://localhost:1234/v1` |

## 有啥特别的功能？

- **Markdown 渲染** — AI 回复里的标题、列表、代码块，实时渲染，不等你读完才出样式
- **每个代码块都有独立复制按钮** — 不用手动框选
- **多结果窗口** — 可以同时开好几个，互不干扰
- **图钉固定** — 把结果钉在屏幕上，切应用也不会消失
- **窗口大小自动记住** — 你调过一次，下次它还记得
- **OpenRouter 余额监控** — 设置页自动刷新，随时知道还剩多少钱

## 系统要求

- macOS 26.0+
- 需要辅助功能权限（只用来读选中文字，不会干别的）

## 故障排查

遇到连接问题？按顺序检查：

1. API 地址填对了没？
2. API Key 还有额度吗？
3. 服务端支持 `/chat/completions` 吗？
4. 网络通吗？试试 `curl -I <你的 API 地址>`
5. 有代理？检查一下代理配置
6. 看控制台 → Y1Y 的日志
7. 检查 macOS 防火墙

## 常见问题

**为什么需要辅助功能权限？**
macOS 不允许一个应用直接读取另一个应用的选中文字。Y1Y 通过模拟 `⌘C` 来获取文本，这需要辅助功能权限。

**数据安全吗？**
你的文字只发给你自己配置的 AI 服务。Y1Y 本身不做任何数据收集、分析、遥测。

**可以自定义快捷键吗？**
目前是 `⌘E`，自定义快捷键支持在计划中。

## 贡献

有想法？有 bug？来 [Issues](https://github.com/33643forever/Y1Y/issues) 说一声。

想写代码？

```bash
git checkout -b feature/你的酷想法
# 改完之后提交 Pull Request
```

代码风格：用 `async/await`，遵循 Apple 的 Swift API 设计指南，新功能带测试。

## 更多文档

| 文档 | 聊什么 |
|---|---|
| [PROJECT_CONTEXT.md](./PROJECT_CONTEXT.md) | 技术栈、模块说明 |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | 架构图、核心流程 |
| [CHANGELOG.md](./CHANGELOG.md) | 版本历史 |
| [ROADMAP.md](./ROADMAP.md) | 已完成 & 计划中 |
| [TODO.md](./TODO.md) | 待修待补 |

## 许可证

MIT © 2026 tape · 始于 2026 年 3 月 · 一个人做的
