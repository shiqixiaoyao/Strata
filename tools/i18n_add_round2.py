#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""追加一轮中文词条到 Resources/Strata2-zh-Hans.xcstrings-fragment.json。

这一轮处理的是 Strata 4.0 同步后仍然显示英文的界面文案：
  * Strata3 运行时中心 / 签名身份 / 扩展组件 的长段说明
  * 帧生成、运存、iPhone 应用、自动刷新、VPN 指南的正文
  * 设置页与工具页里以 String 传参、此前没走 LocalizedStringKey 的短词
"""
import json
from pathlib import Path

FRAGMENT = Path(__file__).resolve().parent.parent / "Resources/Strata2-zh-Hans.xcstrings-fragment.json"

ADD = {
    # ---- Strata3 · 扩展组件 ----
    "Guest extensions are listed for inspection. They are not registered with iOS by importing a guest app, so system widgets, Safari extensions and guest Share actions are not enabled here.":
        "访客 App 的扩展组件在此仅供查看。导入访客 App 并不会把它们注册到 iOS，所以系统小组件、Safari 扩展和访客的分享操作在这里不会启用。",
    "Strata integration": "Strata 集成",

    # ---- Strata3 · 签名身份 ----
    "One local signing identity for Strata's existing signer and future engine adapters. Certificates do not extend provisioning expiration or grant new permissions.":
        "为 Strata 现有签名器与后续引擎适配器提供统一的本地签名身份。证书不会延长描述文件的有效期，也不会授予新权限。",
    "Use the identity that signed the executing app. Passwords are kept exactly as entered, including empty passwords and spaces. The vault is not included in guest backups.":
        "使用签署当前运行 App 的那个身份。密码按输入原样保存，包括空密码和其中的空格。此凭据库不会包含在访客备份里。",
    "Apple account permissions and profile renewal remain in bundled SideStore. Local signing can reuse a valid identity; it cannot renew an expired profile offline.":
        "Apple 账号授权与描述文件续期仍由内置 SideStore 负责。本地签名可以复用有效身份，但无法离线续期已过期的描述文件。",
    "Password (may be empty)": "密码（可留空）",

    # ---- Strata3 · 运行时中心 · 宿主 JIT ----
    "An opt-in cold-start host attachment is included in Strata 3.0. The supplied IPA's unknown binaries were not merged. Enable the experiment per guest below, prepare the device in JIT setup, then use Launch with JIT.":
        "Strata 3.0 内置一个可选的冷启动宿主挂载功能。所提供的 IPA 中来源不明的二进制没有被合并。请在下方为单个访客开启该实验，先在 JIT 设置中准备好设备，再使用「使用 JIT 启动」。",
    "The comparison screenshot reports different host and extension memory budgets. It does not demonstrate in-process JIT. JIT permission is process-specific; attaching to a helper does not grant it to the host.":
        "对比截图只反映宿主与扩展组件拿到的内存额度不同，并不能证明实现了进程内 JIT。JIT 权限是按进程授予的，挂载到辅助进程不会把权限传给宿主。",
    "The existing guest-extension path remains the default and is always used for Multitask. Experimental host startup waits at most 12 seconds for debugger attachment, then returns to the launcher on failure. EspressoU/Pong has verified in-process recompiler operation with a reported 6 GiB budget on the test iPhone 15 Pro. Other guests and devices still require testing.":
        "现有的访客扩展组件路径仍是默认方案，多任务也始终走它。实验性宿主启动最多等 12 秒完成调试器挂载，失败则退回启动器。EspressoU/Pong 已在测试用 iPhone 15 Pro 上验证进程内重编译器可运行，报告的内存额度为 6 GiB。其他访客 App 与设备仍需测试。",
    "Applies to Launch with JIT using the built-in provider. Prepare device first with LocalDevVPN connected. Host startup has a 12-second attachment deadline. Disable this to return to guest-extension JIT. Multitask always uses the existing extension path.":
        "仅适用于使用内置提供者的「使用 JIT 启动」。请先在连接 LocalDevVPN 的状态下准备设备。宿主启动有 12 秒的挂载时限。关闭此项即回到访客扩展组件 JIT。多任务始终使用现有的扩展组件路径。",

    # ---- Strata3 · 运行时中心 · 备份与诊断 ----
    "Backups are stored in Files → Strata → Strata3 → Backups. Restoring keeps the previous container as a hidden .strata-rollback folder beside it for recovery.":
        "备份保存在「文件」→「Strata」→「Strata3」→「Backups」。恢复时会把原有容器留成旁边的隐藏文件夹 .strata-rollback，方便回滚。",
    "Exports current host memory, the latest saved guest memory/Metal sample and guest identifiers. Pairing files, signing identities, Apple credentials, arbitrary guest files and raw JIT logs are excluded.":
        "导出当前宿主内存、最近一次保存的访客内存/Metal 采样以及访客标识。配对文件、签名身份、Apple 凭据、任意访客文件和原始 JIT 日志都不在导出范围内。",
    "App settings & launch options": "App 设置与启动选项",
    "Export diagnostic report": "导出诊断报告",

    # ---- 多任务说明 ----
    "Lets you switch to another app and come back without losing progress. Uses more battery; iOS may still close very large games when memory runs out.":
        "允许你切到别的 App 再回来而不丢进度。会更耗电；内存不足时 iOS 仍可能结束超大型游戏。",

    # ---- 自动刷新 ----
    "When Strata opens, it checks your signing expiry and selected interval. You choose Refresh or Later. Refresh uses the supplied Set VPN Shortcut; a daily automation is optional.":
        "Strata 打开时会检查签名到期时间和你设定的间隔，由你选择「刷新」还是「稍后」。刷新使用随附的 Set VPN 快捷指令；每日自动化是可选项。",
    "Cellular attempts are passed to SideStore without a Wi-Fi restriction. SideStore's installed version and connection setup must support cellular refresh. Configure its Cellular Refresh feature and required Shortcuts in SideStore when available; this switch does not change those settings or your VPN addresses.":
        "蜂窝网络尝试会直接交给 SideStore，不做 Wi-Fi 限制。已安装的 SideStore 版本与连接配置必须支持蜂窝刷新。若 SideStore 提供「蜂窝刷新」，请在 SideStore 里配置该功能及所需快捷指令；此开关不会改动那些设置，也不会改动你的 VPN 地址。",
    "Mobile data": "蜂窝数据",
    "Installed signing expires": "已安装签名的到期时间",
    "Last successful refresh": "上次成功刷新的时间",
    "Next requested refresh": "下次计划刷新的时间",

    # ---- 帧生成 ----
    "Experimental 2× optical-flow frame generation for compatible Metal surfaces. Other rendering paths continue normally. Restart a guest after changing its settings.":
        "为兼容的 Metal 画面提供实验性的 2× 光流补帧。其他渲染路径照常工作。改动某个访客的设置后需要重启该访客。",
    "Displayed mode requests a doubled cadence within the screen limit. Uncapped benchmark computes extra frames offscreen and counts completed GPU work; it does not disable iOS display synchronization or make a 120 Hz screen show 240 distinct frames.":
        "「显示」模式在屏幕刷新率上限内请求加倍的节奏。「不限帧基准」在离屏计算额外帧并统计完成的 GPU 工作量；它不会关闭 iOS 的显示同步，也不会让 120 Hz 屏幕真的显示 240 个不同画面。",
    "3× and 4× add two or three generated frames per real frame and are capped by the display: on 120 Hz, 30 fps → 4× (120), 40 fps → 3× (120), 60 fps → 2× (120). More generated frames add latency and artifacts. Cadence requests apply to CADisplayLink-based loops and may be ignored by a game's own renderer. Actual rates depend on GPU headroom, thermal conditions and the display. Offscreen benchmark frames are not displayed.":
        "3× 和 4× 会在每个真实帧后插入两到三个生成帧，并受屏幕刷新率限制：在 120 Hz 下，30 fps → 4×（120）、40 fps → 3×（120）、60 fps → 2×（120）。生成的帧越多，延迟和画面瑕疵越明显。刷新节奏请求只对基于 CADisplayLink 的循环生效，游戏自带的渲染器可能忽略它。实际帧率取决于 GPU 余量、散热状况和屏幕。离屏基准生成的帧不会显示出来。",
    "MetalFG — upstream project": "MetalFG — 上游项目",

    # ---- iPhone 应用 / 应用清单 ----
    "Not in the list?": "列表里没有？",
    "iPhone app": "iPhone App",
    "App URL, e.g. music://": "App 链接，例如 music://",
    "Reading installed apps…": "正在读取已安装的 App…",
    "Adds the app with its App Store name and icon. If iOS blocks opening it directly and it has no known app link, set an App URL or Shortcut for it under Advanced.":
        "用 App Store 里的名称和图标添加该 App。如果 iOS 阻止直接打开、它又没有已知的 App 链接，请在「高级」里为它设置 App 链接或快捷指令。",
    "Choose the iPhone apps you want in Strata. They open normally in iOS; guest JIT, RAM and multitasking options do not apply.":
        "选择你想放进 Strata 的 iPhone App。它们会在 iOS 里正常打开；访客的 JIT、运存和多任务选项对它们不适用。",
    "Only apps you select are added. Removing an entry never uninstalls the iPhone app. Advanced URL and Shortcut entries remain available for apps that cannot open directly.":
        "只会添加你选中的 App。删掉条目绝不会卸载该 iPhone App。对无法直接打开的 App，仍可使用「高级」里的链接和快捷指令条目。",
    "Added app name": "已添加的 App 名称",
    "Search the App Store for “%@”": "在 App Store 中搜索“%@”",
    "Showing the app list exported from your Mac on %@. iOS doesn't let Strata see apps installed since then: search the App Store below, or export again from your Mac.":
        "下面是从 Mac 导出的 App 列表（%@）。此后安装的 App，iOS 不允许 Strata 查看：请在下方搜索 App Store，或重新从 Mac 导出。",
    "Showing the app list exported from your Mac. iOS doesn't let Strata see apps installed since then: search the App Store below, or export again from your Mac.":
        "下面是从 Mac 导出的 App 列表。此后安装的 App，iOS 不允许 Strata 查看：请在下方搜索 App Store，或重新从 Mac 导出。",

    # ---- 运存 ----
    "RAM bypass adds Apple's Increased Debugging Memory Limit. It only raises the limit while a debugger is attached, so use it with Launch with JIT; ordinary launches stay at the regular extra-memory limit. Apple may refuse it for some accounts. iOS still decides the final amount.":
        "运存扩展会加上 Apple 的「提高调试内存上限」权限。它只在调试器挂载期间提高上限，所以要配合「使用 JIT 启动」；普通启动仍是常规的额外内存上限。Apple 可能对某些账号拒绝授予，最终额度还是由 iOS 决定。",

    # ---- 设置页 ----
    "Search settings": "搜索设置",
    "Manage Apps": "管理 App",
    "Choose Interface": "选择界面",
    "Same categories everywhere": "各界面共用同一套分类",
    "Seamless app switching": "无缝切换 App",
    "Keep running app alive": "保持运行中的 App 存活",
    "Reopen app after iOS closes it": "被 iOS 结束后自动重开 App",
    "Memory overlay": "内存浮层",
    "Each app runs in its own process, full screen. Switching returns to it where you left it instead of restarting it. Turn off for apps that misbehave; HostJIT, Classic Mode and Request Game Mode always run inside Strata.":
        "每个 App 都在独立进程里全屏运行，切回来时会回到你离开的位置，而不是重新启动。遇到异常的 App 可以关掉此项；HostJIT、经典模式和「请求游戏模式」始终在 Strata 内运行。",
    "Memory & Signing": "内存与签名",
    "Tweaks": "插件",
    "Advanced (LiveContainer)": "高级（LiveContainer）",
    "Runtime": "运行环境",
    "No settings match “%@”.": "没有匹配“%@”的设置。",

    # ---- VPN 自动化指南 ----
    "Add your Set VPN shortcut, optionally create the automation below. It uses the native Set VPN action and the existing Refresh All Apps action. Review the selected VPN and app before first use.":
        "添加你的 Set VPN 快捷指令，也可以按下方步骤创建自动化。它使用系统原生的「设定 VPN」动作和现有的「刷新全部 App」动作。首次使用前请核对选中的 VPN 和 App。",
    "Choose Shortcuts from the share sheet, then Add Shortcut. A daily Personal Automation is optional. If an action is unavailable, use the manual recipe below.":
        "在分享面板里选「快捷指令」，再点「添加快捷指令」。每日个人自动化是可选项。若有动作不可用，请用下方的手动步骤。",
    "Create a daily Time of Day Personal Automation. Add Is Strata Refresh Due? → If Yes → Run Shortcut: Set VPN → End If. Choose Run Immediately where available. This outer check applies your selected 1–5 day interval; Set VPN itself stays simple.":
        "创建一个每日的「特定时间」个人自动化。依次加入「Strata 该刷新了吗？」→「如果 是」→「运行快捷指令：Set VPN」→「结束如果」。有「立即运行」就选它。这层外部判断负责执行你设定的 1–5 天间隔，Set VPN 本身保持简单。",
    "The simple shortcut disconnects LocalDevVPN at the end without checking for other users. If a JIT session or another app still needs the VPN, omit Disconnect or wait until that session finishes.":
        "简化版快捷指令会在结尾断开 LocalDevVPN，且不检查是否还有别人在用。如果 JIT 会话或别的 App 仍需要 VPN，请去掉「断开连接」，或等那个会话结束。",
    "If iOS interrupts Shortcuts, requires unlocking, or replaces Strata during its own refresh, cleanup may not run and the VPN can remain connected. Check the result and expiry date. An app-open automation alone does not schedule refreshes.":
        "如果 iOS 中断了快捷指令、要求解锁，或者 Strata 在自身刷新过程中被替换，清理动作可能不会执行，VPN 可能一直连着。请检查执行结果和到期日期。只靠「打开 App」的自动化并不会安排刷新。",
    "Open Shortcuts": "打开快捷指令",
    "Run Set VPN": "运行 Set VPN",
    "Wait 5 seconds": "等待 5 秒",

    # ---- 画廊菜单 ----
    "Move Left": "左移",
    "Move Right": "右移",
    "Move to Start": "移到最前",

    # ---- 分区标题（避开同词多义）----
    "strata.settings.section.apps": "应用",
    "strata.settings.section.system": "系统",
    "strata.action.play": "启动",
    "Every %lld days · SideStore": "每 %lld 天 · SideStore",
    "strata.about.version %@": "版本 %@",
    "strata.storage.lastCalculated %@": "上次统计：%@",
    "strata.memory.sampled %@": "采样时间：%@",
    "strata.memory.signedHost %@": "宿主签名标识：%@",
    "strata.memory.signedGuest %@": "访客签名标识：%@",
    "Runtime Manager · Strata %@": "运行环境管理 · Strata %@",
}


def main() -> None:
    frag = json.loads(FRAGMENT.read_text(encoding="utf-8"))
    before = len(frag)
    added, replaced = 0, 0
    for key, value in ADD.items():
        if key in frag:
            if frag[key] != value:
                replaced += 1
            frag[key] = value
        else:
            added += 1
            frag[key] = value
    FRAGMENT.write_text(json.dumps(frag, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"fragment: {before} -> {len(frag)} 条（新增 {added}，改写 {replaced}）")


if __name__ == "__main__":
    main()
