# Strata 2.0

[English](README.md) | **简体中文**

基于 [LiveContainer](https://github.com/LiveContainer/LiveContainer) 构建的可定制启动器，提供三种界面，并内置 SideStore 支持。

<p align="center"><img src="Resources/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png" width="160" alt="Strata 图标"></p>

## 三种界面

- **iOS 主屏幕：** 竖屏布局，支持自定义图标与名称、静态/动态壁纸、小组件、文件夹、可拖动的翻页圆点、程序坞收藏、搜索，以及带分类的 App 资源库。
- **影院模式（Cinematic）：** 横屏主机风格的应用栏，支持封面图、分类、可调节的播放控件与手柄导航。
- **大屏模式（Big Picture）：** 横屏资源库，拥有独立的竖版封面图、分类、布局尺寸与手柄导航。

封面图、分类和隐藏 App 的设置在各界面之间相互独立。导入的封面图和壁纸保存在“文件” → 我的 iPhone → Strata → Artwork 中。

## 2.0 的新增内容

- 内置 JIT 准备流程：使用设备配对记录与 LocalDevVPN，并支持按 App 选择自动 / 通用 / 导入的脚本。
- 集成了运存扩展权限的账号配置，可查看真实的主机/访客内存报告。权限仍受 Apple 签名描述文件与 iOS 限制的约束。
- 启动器内部与访客进程中共用同一个三指应用切换器，可显示正在运行的 App 与可选固定项。无需常驻浮动箭头即可打开、恢复、最小化或关闭受支持的访客。
- 原生分页滚动、连续的程序坞/背景过渡动画，以及仅在主屏幕显示的翻页圆点（支持拖动）。
- 拖动可创建文件夹、将 App 拖出文件夹、解散文件夹时保留其中的 App，长按主屏幕空白处即可进入编辑。
- 对支持 Metal 的 App 可使用“带 Metal 性能监控启动”。

## 下载与安装

从 [Releases](https://github.com/huzaifahshahid71-ops/Strata/releases/tag/v2.0.0) 获取 **Strata-2.0+SideStore.ipa**，并使用 SideStore 签名安装。更新兼容的合并安装包时，请**保留当前 App 并选择“保留 App 扩展”**，并使用同一账号与标识以保留数据。操作前请先备份重要的访客数据。

Strata 2.0 是产品发布名称；此构建基于 LiveContainer **3.8.11** 与开发修订版 **25**。底层的包版本/标识保持不变，以兼容后续更新。IPA 中不包含个人签名凭据或配对记录。

## JIT 与运存配置

在设备上导入你自己的配对记录，保留可用的 LocalDevVPN 配置，开启开发者模式，然后使用“JIT → 准备设备”。“带JIT启动”会复用现有的访客运行时与无头的 StikJIT 辅助程序。脚本兼容性因 App 而异：只有已验证的 ID 才会自动选用“通用”脚本；自定义导入与按 App 覆盖依然可用。

运存扩展权限配置会登录 Apple 的服务，为已安装的主机与访客 App ID 申请扩展内存权限。之后请使用已授权的签名描述文件重新安装/刷新。凭据仅在内存中处理，内存报告会区分访客的实际测量值与启动器的读取值。提出申请并不保证 iOS 会授予特定数量的内存。

## 限制与测试情况

- **LiveExec32 仍然需要 JIT。** 本版本中没有可用的免 JIT ARMv7 解释器/AOT 后端。
- **游戏模式由 iOS 控制。** “请求游戏模式”会声明访客支持并请求全屏启动；它无法在共享主机标识下为每个访客可靠地强制开启独立的系统游戏模式状态。
- Metal 性能监控需要受支持的 Metal 渲染路径。此最终构建的实机监控验证与 120 Hz 帧同步测量仍在等待完成。
- 普通的进程内访客无法在另一个主进程访客运行时保持独立挂起；切换时会复用现有的主机重启机制。独立的 JIT/多任务访客则保留各自的生命周期。
- 早期开发版本已在 iPhone 15 Pro 上测试：Angry Birds 可通过内置 JIT 运行，某个普通 JSAB 访客在启用内存权限后报告约 6 GiB 的总占用/余量。这些结果不代表所有访客都兼容。
- 发布构建与打包检查已通过。七项模拟器 UI 测试覆盖主屏幕手势、文件夹创建/拖出/删除、分类、壁纸，以及统一运行/固定切换器；针对文件夹模型的检查同样通过。手机上的最终流畅度、监控与进程切换检查仍需由用户实测。

## 从源码构建

```sh
git clone --recurse-submodules https://github.com/huzaifahshahid71-ops/Strata.git
cd Strata
python3 Scripts/fetch-bundled-dependencies.py
xcodebuild -project LiveContainer.xcodeproj -scheme LiveContainer \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

请使用带 iPhoneOS SDK 的 Xcode 26 或更新版本。目标名称仍为 LiveContainer。构建后步骤会嵌入 JIT 辅助程序与运行时。合并后的下载包保留了 SideStore 的原始组件；从源码全新构建的产物与该合并包并非逐字节一致。安装前请先为未签名构建签名。

## 致谢与许可

请参阅 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)、保留的 [LiveContainer 许可证](LICENSE)、依赖声明以及固定版本的来源信息。StosSign 针对本 Strata 版本的再分发许可已由项目维护者于 2026 年 10 月 29 日确认；不对上游声明任何通用许可。Strata 与 Apple、Sony 或 Valve 均无关联。
