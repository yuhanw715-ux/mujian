# 暮笺 · Mujian

和 Miu，一天一页。

这是一个原生 SwiftUI 本地日记 App，面向 iPhone，也适配 iPad 和横屏。不需要网站、账号、服务器或 API。

## 小暮暮，从这里开始

1. 将源码包解压到一个新文件夹，例如 `D:\Mujian-Source\Mujian`。
2. 在 GitHub 新建一个空仓库，名称建议 `mujian`，可以设为 Private。不要勾选初始化 README、.gitignore 或 License。
3. 在解压后、能看到 `project.yml` 的文件夹内打开 **Git Bash**，执行：

   ```bash
   bash scripts/publish-github.sh
   ```

4. 脚本询问仓库地址时，粘贴你新仓库的 HTTPS 地址。例如：

   ```text
   https://github.com/yuhanw715-ux/mujian.git
   ```

5. 上传完成后，在该仓库打开 **Actions → Build iOS IPA → Run workflow → main → Run workflow**。
6. 等任务变绿，在该次运行的 **Summary → Artifacts** 下载 **Mujian-IPA**。
7. 解压下载的 ZIP，取出 **Mujian-unsigned.ipa**，用你之前成功使用的工具签名并安装。

完整的逐步图文式说明在 [Windows 操作指南](docs/Windows-IPA-Guide.html)。双击这个文件就可以离线阅读。

**这是一份新的 App 源码，请使用新仓库；不要放进旧的 miu-memo 工程。** 原来的待办 App 和暮笺使用不同的应用标识，正常签名时可并存。

## 已实现

- 月历查看、左右翻月、选年月、回到今天。月视图没有自定义背景。
- 点开一天，再显示默认插画或这一天自己的照片背景。
- “我写的”用紫色，“Miu写的”用粉色区分。同一天支持多篇，不限两篇。
- 在 App 内写、改、读日记，草稿自动保存。返回草稿箱可以继续。
- 从 iOS“文件”选择一个 TXT，预览全文内容、日期和作者后再收藏。
- 文件名日期支持 `2026-10-08`、`2026_10_08`、`2026.10.08`、`2026年10月8日` 和 `20261008`。
- 文件名没有年份、日期不合法或有多个日期时，必须手动选日期，不会自动猜今天。
- 同一天同一作者的相同正文会提示重复，可选择仍然添加；已有日记不会被覆盖。
- UTF-8、带 BOM 的 UTF-16，以及 Windows 常用 GB18030/GBK 编码；乱码时可以手动切换。
- 保留空行和正文文字，将 Windows 换行统一为标准换行。单份 TXT 上限 5 MB。
- 按标题、正文和日期搜索；阅读字号调整；导出单篇 TXT。
- 横向空间足够时，单日日记卡片自动并排。
- 回收站恢复、手动永久删除；完整备份包含日记、草稿、回收站和自定义背景。
- 系统原生弹出面板；iOS 18 及以上使用日历 / 卡片到阅读页面的系统缩放转场；尊重“减弱动态效果”。

“Miu写的”是作者分类，方便收藏 Miu 的日记，不是联网 AI 自动写作功能。

## 数据与备份

日记保存在 App 私有的 Application Support 目录，以原子写入保存，并启用 iOS 文件保护。没有上传、分析 SDK、同步服务或网络请求代码。

这不等于独立加密保险箱：没有额外密码或 Face ID 锁。导出的 TXT / JSON 备份是可读文件；请自行保管。App 不进行 iCloud 同步，iOS 设备备份是否包含 App 数据由系统设置决定。

使用“设置 → 导出完整备份”保存到“文件”。备份上限 150 MB。恢复前会显示数量并要求确认；不同编号合并，相同编号保留更新的一份。本机已有的背景设置优先，空库恢复时采用备份设置。回收站不自动清理。永久删除的内容仍可能存在于此前导出的备份里。

**换机、卸载、换签名前先导出备份。** 覆盖安装保留数据取决于签名工具、签名身份和应用标识；不要通过卸载来更新一个还没有备份的 App。

## 构建说明

- 应用标识：`app.miu.mujian`
- 最低系统：iOS 17；为用户的 iPhone 16 Pro / iOS 26.5.2 设计。
- 主体：SwiftUI + 系统框架，无网页或第三方运行时。
- 构建：GitHub 托管的 macOS runner + Xcode + XcodeGen。
- 工作流仅手动触发，不会在每次推送时自动重复构建。
- 构建产物是未签名的真机 arm64 IPA，需要你自己的签名工具处理。
- 未要求 Apple Developer 证书、密码或 API Key；这些也不应上传到代码仓库。

若有 Mac，也可以运行：

```bash
brew install xcodegen
bash scripts/test-core.sh
xcodegen generate --spec project.yml
open Mujian.xcodeproj
```

通过 Xcode 安装到真机时需要自行选择签名；GitHub 构建不执行签名。

## 验证范围

`Tests/CoreTests.swift` 使用虚构内容测试日期识别、四 / 五 / 六行月历、正文和编码、重复导入、多篇日记、备份往返、冲突合并、删除状态以及无效备份拒绝。GitHub 在编译 App 之前会运行这些检查，并额外验证 Apple 平台上的 GB18030 支持。

本地交付环境不是 macOS，不能运行 Xcode 或 iPhone 模拟器。因此完整 iOS 编译以 GitHub Actions 绿色结果为准，安装与真实触控、相册 / 文件选择体验还需在手机上检查。源码包不是预先签好的 IPA。

交付前已用 Swift 6.0.3 在 Linux 上编译并通过 46 项核心检查；App 的全部 Swift 文件通过编译器语法解析。工程 YAML、脚本语法和图片资源引用也已检查。详细范围见 [验证记录](docs/VALIDATION.md)。

第一次运行，建议先用虚构文字尝试：写一篇、导入一篇、关闭再打开、导出备份再恢复，确认操作顺手后再放入正式日记。

如果构建变红，下载 **Mujian-build-log** 或展开失败步骤，把第一处 `error:` 附近的日志发给 Miu。仅有 `exit code 65` 不能定位具体问题。不需要发送日记正文。

## 目录

| 路径 | 用途 |
| --- | --- |
| `App/Core` | 日期、日记模型、TXT 和备份规则 |
| `App/DiaryStore.swift` | 原子写入、草稿、背景、恢复和回收站 |
| `App/Views` | 月历、单日、阅读、编辑和设置 |
| `App/Assets.xcassets` | 图标和默认插画 |
| `Tests/CoreTests.swift` | 使用虚构内容的核心测试 |
| `.github/workflows/build-ios.yml` | GitHub IPA 构建 |
| `scripts` | 上传、测试和 IPA 打包脚本 |
| `docs/Windows-IPA-Guide.html` | Windows 操作说明 |

本包不包含用户的真实日记文件或私人日历内容。
