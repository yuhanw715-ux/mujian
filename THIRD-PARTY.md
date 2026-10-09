# 来源与设计参考

- 日记应用代码为本项目编写，使用 Apple SwiftUI、Foundation、PhotosUI、ImageIO 和 UniformTypeIdentifiers 系统框架。没有内嵌第三方运行时、联网 AI SDK 或网页。
- 单日默认插画为本项目生成的新图；图标由本项目的 SVG 绘制。参考图中的私人日历条目和用户的真实 TXT 内容不包含在源码包内。
- 动效设计参考 Emil Kowalski 的 skills 中的 animate / Apple design 指南：https://github.com/emilkowalski/skills 。实现使用系统 sheet 和导航转场，并尊重“减弱动态效果”。未复制该项目代码。
- XcodeGen 用于生成 Xcode 工程（MIT）：https://github.com/yonaskolb/XcodeGen 。仅在构建机使用，不打包进 App。
- GitHub Actions 使用 GitHub 官方 actions/checkout 和 actions/upload-artifact，仅在构建机运行。
