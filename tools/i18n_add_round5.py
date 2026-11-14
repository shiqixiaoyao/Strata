#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第五轮词条：扩展进程与快捷指令。

前四轮覆盖的都是主 App 的 SwiftUI 界面。这一轮补的是三类「另一个进程」里的文案：
  1. LaunchAppExtension / ShareExtension 抛给用户的错误串（原来直接 throw 英文字面量）；
  2. StrataJITWorker 写进状态 JSON、由主 App 读取展示的 JIT 进度；
  3. SideStoreSupport 里三个 AppIntent 的标题/说明，以及计划刷新的结果句。

这些 key 都带固定格式符，运行时由 NSLocalizedString / String.loc 直接查表，
不依赖编译器抽取，所以必须逐字与源码一致。
"""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRAGMENT = ROOT / "Resources/Strata2-zh-Hans.xcstrings-fragment.json"

ADD = {
    # —— LaunchAppExtension：快捷指令「启动 App」——
    "Launch App": "启动 App",
    "Launch URL": "启动 URL",
    "This action directly launches an app in normal mode in LiveContainer. To get the launch URL, open LiveContainer, hold the app, tap \"Add to Home Screen\" -> \"Copy Launch URL\"": "这个操作会直接在 LiveContainer 中以普通模式启动 App。要拿到启动 URL，请打开 LiveContainer，长按该 App，点按「添加到主屏幕」→「拷贝启动 URL」。",
    "Failed to start extension %@. To use the Launch App shortcut, reinstall LiveContainer with LaunchAppExtension and ShareExtension installed. If you use SideStore, choose \"Keep App Extensions (Use Main Profile)\". If you use Impactor, choose \"Only Register Main Bundle\". For other sideloaders, select keep all extensions, i.e. DO NOT Remove any extension.": "启动扩展失败：%@。要使用「启动 App」快捷指令，请重新安装 LiveContainer 并保留 LaunchAppExtension 与 ShareExtension。用 SideStore 安装时选「保留 App 扩展（使用主描述文件）」；用 Impactor 时选「只注册主 Bundle」；其他侧载工具请选择保留全部扩展，也就是不要移除任何扩展。",
    "Not a livecontainer URL!": "这不是 LiveContainer 的 URL！",
    "lcSharedDefaults failed to initialize, because no app group was found. Did you sign LiveContainer correctly?": "lcSharedDefaults 初始化失败：没有找到 App 群组。LiveContainer 的签名是否正确？",
    "Not a livecontainer launch URL!": "这不是 LiveContainer 的启动 URL！",
    "URLComponents failed to initialize.": "URLComponents 初始化失败。",
    "No bundle-name parameter found.": "没有找到 bundle-name 参数。",
    "Failed to find AppInfo!": "找不到 AppInfo！",
    "Failed to load AppInfo!": "无法加载 AppInfo！",
    "unable to construct new url": "无法构造新的 URL",
    # —— ShareExtension：共享面板里的错误 ——
    "Unable to build launch URL.": "无法构造启动 URL。",
    "Unable to build install URL.": "无法构造安装 URL。",
    "Unable to build SideStore launch URL.": "无法构造 SideStore 启动 URL。",
    "The shared item is still loading.": "共享内容仍在载入中。",
    # —— StrataJITWorker：写进状态 JSON 的进度与错误 ——
    "Invalid JIT request.": "无效的 JIT 请求。",
    "JIT helper connected.": "JIT 辅助进程已连接。",
    "Developer disk image cache reset.": "开发者磁盘映像缓存已重置。",
    "Invalid device endpoint.": "无效的设备地址。",
    "Connecting to device at %@:%d…": "正在连接设备 %@:%d…",
    "Device ready. TXM/SPTM: %@": "设备已就绪。TXM/SPTM：%@",
    "strata.jit.txm.present": "存在",
    "strata.jit.txm.absent": "不存在",
    "strata.jit.txm.unknown": "未知",
    "Cannot determine device JIT requirements.": "无法判断这台设备是否需要 JIT。",
    "This guest needs a compatible iOS JIT script. Configure its JIT script in app settings before launching.": "这个访客 App 需要兼容的 iOS JIT 脚本。请在启动前到 App 设置里配置它的 JIT 脚本。",
    "Connecting debugger…": "正在连接调试器…",
    "JIT request completed.": "JIT 请求已完成。",
    "Checking device reachability…": "正在检查设备连通性…",
    "Checking the developer disk image…": "正在检查开发者磁盘映像…",
    "Downloading the developer disk image: %d%% · %@": "正在下载开发者磁盘映像：%d%% · %@",
    "Mounting the developer disk image: %d%%": "正在挂载开发者磁盘映像：%d%%",
    "Verifying the developer disk image…": "正在校验开发者磁盘映像…",
    "Device ready.": "设备已就绪。",
    # —— SideStoreSupport：快捷指令动作的标题与说明 ——
    "Is Strata Refresh Due?": "Strata 刷新是否到期？",
    "Checks the enabled 1–5 day schedule before your Shortcut connects LocalDevVPN.": "在你的快捷指令连接 LocalDevVPN 之前，先检查已启用的 1–5 天刷新计划。",
    "Run Strata Scheduled Refresh": "运行 Strata 计划刷新",
    "Waits for bundled SideStore to finish. Returns result text instead of throwing a signing error, so your Shortcut can run its VPN cleanup step. Connect LocalDevVPN first.": "等待内置 SideStore 完成刷新。以文本返回结果而不是抛签名错误，这样你的快捷指令还能继续执行 VPN 清理步骤。请先连接 LocalDevVPN。",
    "Can Disconnect Strata VPN?": "可以断开 Strata VPN 吗？",
    "Checks whether Strata still has an active JIT or scheduled refresh session. Does not detect VPN use by other apps.": "检查 Strata 是否还有进行中的 JIT 或计划刷新会话。不会检测其他 App 对 VPN 的使用。",
    "Strata Refresh Gate (Text)": "Strata 刷新判定（文本）",
    "Strata Disconnect Gate (Text)": "Strata 断开判定（文本）",
    # —— LiveProcess（访客进程）：启动失败与 JIT 等待的提示 ——
    "Cannot resolve guest file access. Relaunch from the app library.": "无法解析访客 App 的文件访问权限。请从 App 列表重新启动。",
    "The guest cannot read its selected 32-bit runtime after granting file access.": "授权文件访问后，访客 App 仍无法读取所选的 32 位运行时。",
    "Cannot read guest debugging status.": "无法读取访客 App 的调试状态。",
    "Invalid JIT guest startup request.": "无效的访客 JIT 启动请求。",
    "Guest startup paused until debugger attaches.": "访客启动已暂停，等待调试器连接。",
    "Cannot save the guest JIT startup acknowledgement.": "无法保存访客 JIT 启动确认。",
    "Debugger attached; entering the existing guest runtime.": "调试器已连接，正在进入已有的访客运行时。",
    "Guest timed out waiting for debugger attachment. Check the saved JIT status.": "访客等待调试器连接超时。请检查已保存的 JIT 状态。",
    # —— 计划刷新的结果句（会写进 StrataRefreshStatus 并显示在设置页）——
    "Skipped: Strata refresh is not due, disabled or recently attempted.": "已跳过：Strata 刷新还没到期、已关闭，或刚刚尝试过。",
    "Skipped: waiting for Wi-Fi; cellular attempts are disabled or network status is unavailable.": "已跳过：正在等待 Wi-Fi；蜂窝网络刷新已关闭，或无法获取网络状态。",
    "Skipped: another refresh started while checking the network.": "已跳过：检查网络期间已有另一次刷新开始。",
    "Failed: bundled SideStore is unavailable.": "失败：内置 SideStore 不可用。",
    "Failed: %@": "失败：%@",
    "Refreshing through Shortcuts and bundled SideStore…": "正在通过快捷指令与内置 SideStore 刷新…",
    "Refreshed: SideStore confirmed all apps refreshed successfully.": "已刷新：SideStore 确认所有 App 刷新成功。",
    "Failed: SideStore refresh timed out. Check VPN, pairing and account status.": "失败：SideStore 刷新超时。请检查 VPN、配对和账号状态。",
}


def main() -> None:
    frag = json.loads(FRAGMENT.read_text(encoding="utf-8"))
    files = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True).stdout.split("\n")
    blob = "\n".join(
        (ROOT / f).read_text(encoding="utf-8")
        for f in files
        if f.endswith((".swift", ".m")) and (ROOT / f).exists()
    )

    # 源码里的引号写成 \", 比对时要认这种转义形式
    missing = [k for k in ADD if k not in blob and k.replace('"', '\\"') not in blob]
    if missing:
        for k in missing:
            print("!! 源码中找不到:", repr(k[:90]))

    before = len(frag)
    frag.update(ADD)
    FRAGMENT.write_text(
        json.dumps(frag, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"词条 {before} -> {len(frag)}（新增 {len(frag) - before} 条，本轮 {len(ADD)} 条）")
    if missing:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
