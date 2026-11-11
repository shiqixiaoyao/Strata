#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第四轮词条：把插值句改写成固定格式串后需要的中文。

SwiftUI 对 `Text("…\\(value)…")` 生成的 catalog key 依赖插值类型（Int 是 %lld、
String 是 %@），改写成 LCStr 后 key 由我们自己固定，译文才对得上。
"""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRAGMENT = ROOT / "Resources/Strata2-zh-Hans.xcstrings-fragment.json"

ADD = {
    "strata.memory.availableToStrata %@": "Strata 当前可用：%@ MB",
    "strata.memory.pid %@": "进程号：%@",
    "strata.memory.availableToGuest %@": "采样时运行中 App 可用：%@ MB",
    "strata.memory.usedByGuest %@": "采样时运行中 App 已用：%@ MB",
    "strata.home.page %lld": "第 %lld 页",
    "strata.home.removeWidget %@": "移除「%@」小组件",
    "strata.home.removeFromHome %@": "从主屏幕移除 %@",
    "strata.home.showPage %lld": "显示第 %lld 页",
    "strata.home.removePage %lld": "移除第 %lld 页",
    "strata.home.removePageConfirm %lld": "移除第 %lld 页？",
    "strata.identity.fingerprint %@": "身份指纹\n%@",
}


def main() -> None:
    frag = json.loads(FRAGMENT.read_text(encoding="utf-8"))
    blob = "\n".join(
        (ROOT / f).read_text(encoding="utf-8")
        for f in subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True).stdout.split("\n")
        if f.endswith((".swift", ".m")) and (ROOT / f).exists()
    )
    missing = [k for k in ADD if k not in blob]
    if missing:
        for k in missing:
            print("!! 源码中找不到:", repr(k))
        raise SystemExit(1)
    before = len(frag)
    frag.update(ADD)
    FRAGMENT.write_text(json.dumps(frag, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"fragment: {before} -> {len(frag)} 条")


if __name__ == "__main__":
    main()
