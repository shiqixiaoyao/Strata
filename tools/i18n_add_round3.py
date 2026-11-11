#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第三轮中文词条：Strata3 的错误与状态文案、启动台与画廊菜单、自动刷新状态、
签名/运存/iPhone 应用/工具页等界面上仍然显示英文的句子。

脚本会先确认每条英文都能在源码里逐字找到，避免因弯引号或空格差异写入无用词条。
"""
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRAGMENT = ROOT / "Resources/Strata2-zh-Hans.xcstrings-fragment.json"

ADD = {
    # ---- LCAppModel / HostJIT ----
    "HostJIT needs a registered guest and data container.": "HostJIT 需要一个已注册的访客和数据容器。",
    "Import a pairing file and prepare the device before testing HostJIT.": "请先导入配对文件并准备设备，再测试 HostJIT。",

    # ---- StrataGuestDataLease ----
    "Invalid guest data container.": "访客数据容器无效。",
    "Cannot open the guest data lock.": "无法打开访客数据锁。",
    "The guest or another data operation is using this container. Close it and retry.": "该访客或其他数据操作正在占用此容器，请关闭后重试。",

    # ---- StrataIdentitySettings ----
    "Shared device-only Keychain": "共享的仅本机钥匙串",
    "Legacy preferences": "旧版偏好设置",
    "Certificate expiry": "证书到期时间",
    "Select a .p12 file smaller than 16 MB.": "请选择小于 16 MB 的 .p12 文件。",
    "Signing identity removed.": "已移除签名身份。",
    "The certificate or password could not be read.": "无法读取证书或密码。",
    "This identity belongs to another signing team. Import the identity used to install Strata.": "此身份属于另一个签名团队。请导入安装 Strata 时所用的身份。",
    "This signing certificate has expired.": "此签名证书已过期。",
    "Identity saved. Existing Strata signing now uses the shared Keychain vault.": "身份已保存。Strata 现有签名现已使用共享钥匙串凭据库。",
    "Remove Strata's signing identity? Existing apps and data are kept.": "移除 Strata 的签名身份？现有 App 和数据会保留。",
    "Remove identity": "移除身份",
    "Import .p12 identity": "导入 .p12 身份",
    "Move existing identity to Keychain": "将现有身份移入钥匙串",
    "No signing identity imported.": "尚未导入签名身份。",
    "The previous identity stays available if import fails.": "若导入失败，原身份仍然可用。",

    # ---- StrataPortableBackup ----
    "The guest root cannot be a symbolic link.": "访客根目录不能是符号链接。",
    "This path is outside the guest container.": "此路径位于访客容器之外。",
    "Symbolic links are not opened or backed up.": "符号链接不会被打开或备份。",
    "Cannot enumerate the guest container.": "无法枚举访客容器内容。",
    "The container includes a symbolic link. Back up its source separately.": "容器中包含符号链接，请单独备份其源文件。",
    "Invalid container path.": "容器路径无效。",
    "This container has filenames that differ only by letter case or Unicode normalization. They cannot be stored in this portable backup format.": "此容器中存在仅大小写或 Unicode 规范化不同的文件名，无法存入这种可移植备份格式。",
    "Unsupported file type in guest container.": "访客容器中存在不支持的文件类型。",
    "This container has too many files for this backup format.": "此容器的文件数量超出该备份格式的上限。",
    "The backup manifest is too large.": "备份清单过大。",
    "Cannot create backup.": "无法创建备份。",
    "Guest data changed during backup. Close the guest and retry.": "备份期间访客数据发生变化，请关闭访客后重试。",
    "A backup already exists at this destination.": "该目标位置已存在备份。",
    "The backup is truncated.": "备份文件不完整。",
    "This is not a Strata backup.": "这不是 Strata 的备份。",
    "Invalid backup manifest length.": "备份清单长度无效。",
    "This backup belongs to another app or unsupported format.": "此备份属于其他 App，或格式不受支持。",
    "Invalid or duplicate backup entry.": "备份条目无效或重复。",
    "Invalid backup size.": "备份大小无效。",
    "Backup length does not match its manifest.": "备份长度与清单不符。",
    "Cannot restore file.": "无法恢复文件。",
    "A backup file failed its integrity check. Nothing was replaced.": "某个备份文件未通过完整性校验，未替换任何内容。",
    "The backup contains unexpected trailing data.": "备份尾部存在多余数据。",

    # ---- StrataRuntimeCenter ----
    "Close the guest first.": "请先关闭该访客。",
    "Shared data directory unavailable.": "共享数据目录不可用。",
    "Backup created and verified while copying.": "备份已创建，并在复制过程中完成校验。",
    "Restored. The previous data container remains in its recovery folder.": "已恢复。原有数据容器仍保留在恢复文件夹中。",
    "Guest files": "访客文件",
    "A file with this name already exists. Rename it before importing.": "同名文件已存在，请改名后再导入。",
    "Import a regular file, not a link or directory.": "请导入普通文件，而不是链接或目录。",
    "File imported.": "文件已导入。",
    "Binary file. Use Export to open it in another app.": "二进制文件。请用「导出」在其他 App 中打开。",
    "Saved in Files → Strata → Strata3 → Diagnostics. Guest measurements may be from an earlier launch; compare their timestamps.": "已保存到「文件」→「Strata」→「Strata3」→「Diagnostics」。访客测量数据可能来自更早的一次启动，请对比它们的时间戳。",
    "Runtime & data management": "运行环境与数据管理",
    "Execution engines": "执行引擎",
    "LiveContainer · Ready": "LiveContainer · 就绪",
    "Existing iOS launch, guest-extension JIT and multitasking paths are retained.": "保留现有的 iOS 启动、访客扩展组件 JIT 和多任务路径。",
    "LocalSigner · Signing identity": "LocalSigner · 签名身份",

    # ---- LiveBoard 模式 ----
    "Switchboard": "切换台",
    "Shelf": "陈列架",
    "Arcade": "街机厅",
    "A clean horizontal game row with controller navigation.": "简洁的横向游戏排列，支持手柄导航。",
    "A full-screen poster grid tinted by the selected game.": "全屏海报网格，配色随选中的游戏变化。",
    "A full-screen grid of rounded app tiles tinted by the selected game.": "全屏圆角应用网格，配色随选中的游戏变化。",

    # ---- LiveBoardConsoleScreen ----
    "Your favorites": "你的收藏",
    "Your library": "你的库",
    "Add favorites from an app’s options.": "在 App 的选项里添加收藏。",
    "Install your first app to get started.": "安装第一个 App 即可开始。",
    "All apps": "所有 App",
    "Manage apps": "管理 App",
    "Play Game": "开始游戏",
    "Launch App": "启动 App",
    "Choose landscape cover": "选择横版封面",
    "Reset artwork": "重置封面",
    "Choose portrait cover": "选择竖版封面",
    "Hide in this mode": "在此模式中隐藏",
    "Rename / change app icon": "重命名 / 更换 App 图标",
    "Search library": "搜索库",

    # ---- LiveBoardHomeScreen ----
    "Widget size": "小组件尺寸",
    "Move to Page": "移到页面",
    "Launch options": "启动选项",
    "Unpin from app switcher": "从应用切换器中取消固定",
    "Pin to app switcher": "固定到应用切换器",
    "Open storage management": "打开存储管理",
    "Memory & signing permissions": "内存与签名权限",
    "Drag to rearrange": "拖动以重新排列",
    "Launch app. Touch and hold for more actions.": "启动 App。长按可查看更多操作。",

    # ---- LiveBoardModeLibrary ----
    "Place After": "放在其后",

    # ---- LCSettingsView ----
    "Built-in JIT (LocalDevVPN)": "内置 JIT（LocalDevVPN）",
    "StikDebug (Another LiveContainer/Multitask)": "StikDebug（另一个 LiveContainer/多任务）",
    "StosDebug (Another LiveContainer/Multitask)": "StosDebug（另一个 LiveContainer/多任务）",
    "JitStreamer-EB (Relaunch)": "JitStreamer-EB（重新启动）",
    "Strata floating menu diagnostics": "Strata 浮动菜单诊断",

    # ---- StrataAutoRefresh 状态 ----
    "No refresh attempted yet.": "尚未尝试刷新。",
    "Refreshing through": "正在通过以下方式刷新",
    "The previous refresh did not return a result. Check SideStore's expiry date or refresh again.": "上次刷新没有返回结果。请检查 SideStore 的到期时间，或再次刷新。",
    "Automatic refresh was turned off.": "自动刷新已关闭。",
    "Your refresh interval is due. The installed expiry could not be read; check SideStore's expiry date.": "刷新间隔已到。无法读取已安装签名的到期时间，请检查 SideStore 的到期时间。",
    "Set up Set VPN in Refresh settings, then tap Refresh now.": "请先在刷新设置中配置 Set VPN，再点「立即刷新」。",
    "Could not open Shortcuts. Check that Set VPN is installed.": "无法打开「快捷指令」。请确认已安装 Set VPN。",
    "A scheduled Shortcut refresh is already active.": "已有一个计划中的快捷指令刷新在进行。",
    "Install Strata + SideStore with all extensions on iOS 17 or newer.": "请在 iOS 17 或更新系统上安装带全部扩展的 Strata + SideStore。",
    "Next refresh is not due yet.": "下次刷新时间还没到。",
    "Waiting for Wi-Fi. Enable cellular attempts to use mobile data.": "正在等待 Wi-Fi。开启蜂窝尝试即可使用移动数据。",
    "Refreshing through bundled SideStore… Keep LocalDevVPN connected.": "正在通过内置 SideStore 刷新…请保持 LocalDevVPN 连接。",
    "SideStore refresh timed out. Check VPN, pairing and your SideStore account, then retry.": "SideStore 刷新超时。请检查 VPN、配对和 SideStore 账号后重试。",
    "SideStore reported that all apps refreshed successfully.": "SideStore 报告所有 App 已刷新成功。",
    "Edit VPN Shortcut setup": "编辑 VPN 快捷指令设置",
    "Set up VPN Shortcut": "配置 VPN 快捷指令",
    "Refresh now": "立即刷新",
    "Refresh cancelled.": "刷新已取消。",

    # ---- StrataInstalledAppPicker ----
    "Not added": "未添加",
    "Added": "已添加",
    "The app list is empty or too large.": "App 列表为空或过大。",
    "The app list is too large.": "App 列表过大。",
    "Too many app entries.": "App 条目过多。",
    "iOS has restricted the installed-app list. Import an app list from a paired Mac to choose apps by name.": "iOS 限制了已安装 App 列表。请从已配对的 Mac 导入 App 列表，以便按名称选择。",

    # ---- StrataMemoryCapabilities ----
    "Enter the HTTPS anisette server you use with SideStore.": "输入你与 SideStore 配合使用的 HTTPS anisette 服务器。",
    "Enter your signing Apple ID and password. This installation must have a valid signing team.": "输入用于签名的 Apple ID 和密码。此安装必须拥有有效的签名团队。",
    "This account does not contain Strata's signing team. Use the same Apple ID as SideStore.": "此账号中没有 Strata 的签名团队。请使用与 SideStore 相同的 Apple ID。",
    "Apple returned no registered App IDs for this signing team. Check SideStore's Apple ID and team. Refreshing cannot fix an account mismatch.": "Apple 未返回此签名团队的任何已注册 App ID。请检查 SideStore 的 Apple ID 与团队。刷新无法修复账号不匹配的问题。",
    "Matching registrations found. Review both selections before applying.": "已找到匹配的注册项。应用前请先核对两个选择。",
    "Requesting capability…": "正在申请权限…",
    "Signed out.": "已退出登录。",
    "Normal launch: runs inside Strata's process": "普通启动：在 Strata 进程内运行",
    "Runs in a separate guest process": "在独立的访客进程中运行",
    "Running process: extra memory entitlement present": "运行中进程：已具备额外内存权限",
    "Running process: standard memory entitlement": "运行中进程：标准内存权限",
    "Strata: RAM bypass (debugging limit) in signature": "Strata：签名中已含运存扩展（调试上限）",
    "Strata: RAM bypass not in signature": "Strata：签名中不含运存扩展",

    # ---- StrataPhoneApps ----
    "Enter a name and valid app URL or Shortcut name.": "请输入名称和有效的 App 链接或快捷指令名称。",
    "This iPhone app entry is no longer available.": "此 iPhone App 条目已不可用。",
    "Invalid iPhone app selection.": "iPhone App 选择无效。",
    "iOS doesn’t let Strata open this app directly, and its app link didn’t respond. Set an App URL or Shortcut for it under Settings → iPhone Apps → Advanced.": "iOS 不允许 Strata 直接打开此 App，且它的 App 链接没有响应。请在「设置」→「iPhone Apps」→「高级」中为它设置 App 链接或快捷指令。",
    "Invalid app URL or Shortcut name.": "App 链接或快捷指令名称无效。",
    "iOS could not open this app. Check its URL, or create a Shortcut with Open App and use that Shortcut's name.": "iOS 无法打开此 App。请检查它的链接，或用「打开 App」创建一个快捷指令，再填写该快捷指令的名称。",

    # ---- StrataSwitchboard ----
    "Categories and hidden apps": "分类与隐藏的 App",
    "Choose cover artwork": "选择封面图",

    # ---- StrataToolsPage ----
    "Done editing tools": "完成编辑工具",
    "Edit tools": "编辑工具",
    "Move earlier": "前移",
    "Move later": "后移",

    # ---- StrataVPNAutomationGuide 步骤 ----
    "Install LocalDevVPN and connect it once to add its VPN configuration. Keep its working addresses unchanged.": "安装 LocalDevVPN 并连接一次，以添加它的 VPN 配置。请保持其可用地址不变。",
    "Use the native Set VPN action with Connect.": "使用系统原生的「设定 VPN」动作并选择「连接」。",
    "Let the VPN route settle.": "让 VPN 路由稳定下来。",
    "Choose Strata's bundled SideStore action. Its source waits for the refresh result before returning.": "选择 Strata 内置的 SideStore 动作。它的来源会等刷新结果返回后才结束。",
    "Retained from your supplied shortcut.": "沿用你所提供快捷指令中的这一步。",
    "If refresh errors or iOS interrupts the shortcut, this action may not run. Disconnect manually afterward if necessary.": "如果刷新出错或 iOS 中断了快捷指令，这一步可能不会执行。必要时请事后手动断开。",

    # ---- 其它界面提示 ----
    "Strata is connecting its built-in debugger. The app opens when attachment is confirmed; JIT setup can continue while you use it.": "Strata 正在连接内置调试器。确认挂载完成后 App 就会打开；使用过程中可以继续完成 JIT 设置。",
    "Unable to find PrimaryLiveContainerTeamId": "找不到 PrimaryLiveContainerTeamId",
    "Failed to determine team id.": "无法确定团队 ID。",
}


def main() -> None:
    frag = json.loads(FRAGMENT.read_text(encoding="utf-8"))
    sources = {}
    for f in subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True).stdout.split("\n"):
        if f.endswith((".swift", ".m")):
            try:
                sources[f] = (ROOT / f).read_text(encoding="utf-8")
            except OSError:
                pass
    blob = "\n".join(sources.values())

    missing = [k for k in ADD if k not in blob]
    if missing:
        for k in missing:
            print("!! 源码中找不到:", repr(k))
        raise SystemExit("存在与源码不一致的 key，已中止")

    before = len(frag)
    for key, value in ADD.items():
        frag[key] = value
    FRAGMENT.write_text(json.dumps(frag, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"fragment: {before} -> {len(frag)} 条（新增 {len(frag) - before}）")


if __name__ == "__main__":
    main()
