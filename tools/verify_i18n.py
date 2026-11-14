#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""校验中文本地化是否覆盖了所有会显示到界面上的文案。

检查项：
  1. fragment 是合法 JSON，值与键都非空；
  2. 源码里每个 `"…".loc` 的目标串都能在 fragment 或 catalog 里查到中文；
  3. 源码里每个 LCStr("key", "fallback") 的 key 都能查到中文；
  4. 带格式符的词条，其中文译文的格式符集合与英文 key 一致（否则 String(format:) 会崩或串位）；
  5. 没有 `"".loc` 这种空串包装。
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRAGMENT = ROOT / "Resources/Strata2-zh-Hans.xcstrings-fragment.json"
CATALOG = ROOT / "Resources/Localizable.xcstrings"

fails: list[str] = []


def fail(msg: str) -> None:
    fails.append(msg)


def specifiers(text: str) -> list[str]:
    return sorted(re.findall(r"%(?:\d+\$)?[@dfslu]+", text))


def main() -> int:
    frag = json.loads(FRAGMENT.read_text(encoding="utf-8"))
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]

    zh: dict[str, str] = {}
    for key, entry in catalog.items():
        unit = entry.get("localizations", {}).get("zh-Hans", {}).get("stringUnit", {})
        if unit.get("value"):
            zh[key] = unit["value"]
    zh.update(frag)

    if not isinstance(frag, dict) or not frag:
        fail("fragment 不是非空 JSON 对象")
    for k, v in frag.items():
        if not isinstance(k, str) or not k:
            fail(f"fragment 存在空键: {k!r}")
        if not isinstance(v, str) or not v.strip():
            fail(f"fragment 词条为空: {k!r}")

    files = [
        f
        for f in subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True).stdout.split("\n")
        if f.endswith((".swift", ".m")) and not f.startswith("Vendor/")
    ]
    sources = {f: (ROOT / f).read_text(encoding="utf-8") for f in files if (ROOT / f).exists()}

    loc_pat = re.compile(r'"((?:[^"\\\n]|\\.){2,})"\.loc')
    lcstr_pat = re.compile(r'LCStr\(\s*"([^"\\\n]+)"')
    empty_loc = re.compile(r'"\s*"\.loc')

    seen_loc = 0
    for name, text in sources.items():
        for m in empty_loc.finditer(text):
            line = text.count("\n", 0, m.start()) + 1
            fail(f"{name}:{line} 出现空串 .loc")

        for m in loc_pat.finditer(text):
            raw = m.group(1)
            if "\\(" in raw:
                continue
            # 源码里的引号写成 \"，词条里是裸引号
            key = raw.replace('\\"', '"')
            seen_loc += 1
            value = zh.get(key)
            if value is None:
                line = text.count("\n", 0, m.start()) + 1
                fail(f"{name}:{line} .loc 缺中文词条: {key!r}")
                continue
            if specifiers(key) != specifiers(value):
                line = text.count("\n", 0, m.start()) + 1
                fail(
                    f"{name}:{line} 格式符不一致 {key!r} -> {value!r}"
                    f"（{specifiers(key)} vs {specifiers(value)}）"
                )

        for m in lcstr_pat.finditer(text):
            key = m.group(1)
            if key not in zh:
                line = text.count("\n", 0, m.start()) + 1
                fail(f"{name}:{line} LCStr 缺中文词条: {key!r}")

    # 关键字含 %lld / %@ 的条目，中文译文必须保留同样的占位符
    for key, value in frag.items():
        if specifiers(key) and specifiers(key) != specifiers(value):
            fail(f"fragment 格式符不一致: {key!r} -> {value!r}")

    print(f"检查 .loc 调用 {seen_loc} 处，词条合计 {len(zh)} 条")
    if fails:
        print(f"\nFAIL（{len(fails)} 项）")
        for item in fails[:60]:
            print("  -", item)
        return 1
    print("\nPASS 所有界面文案均有中文词条，且格式符匹配")
    return 0


if __name__ == "__main__":
    sys.exit(main())
