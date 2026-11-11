"""Compare the compiled en and zh-Hans string tables inside a built IPA.

Xcode extracts every LocalizedStringKey the app can show into
`en.lproj/Localizable.strings`. Anything missing from `zh-Hans.lproj` will fall
back to English at runtime, so this diff is the authoritative "still untranslated"
list — it also covers keys produced by string interpolation, which the source
scan cannot predict.

Usage: python i18n_audit_ipa.py <path-to-ipa>
"""
import plistlib
import sys
import zipfile
from pathlib import Path


def load_strings(zf: zipfile.ZipFile, name: str) -> dict[str, str]:
    try:
        raw = zf.read(name)
    except KeyError:
        return {}
    try:
        data = plistlib.loads(raw)
    except Exception:
        # old-style text .strings
        data = {}
        for line in raw.decode("utf-8", "ignore").splitlines():
            if "=" not in line or line.strip().startswith("//"):
                continue
            key, _, value = line.partition("=")
            data[key.strip().strip('"')] = value.strip().rstrip(";").strip().strip('"')
    return {k: v for k, v in data.items() if isinstance(v, str)}


def main() -> int:
    ipa = Path(sys.argv[1])
    with zipfile.ZipFile(ipa) as zf:
        names = zf.namelist()
        en = next((n for n in names if n.endswith("en.lproj/Localizable.strings")), None)
        zh = next((n for n in names if n.endswith("zh-Hans.lproj/Localizable.strings")), None)
        if not en:
            print("未在 IPA 中找到 en.lproj/Localizable.strings")
            return 2
        en_map = load_strings(zf, en)
        zh_map = load_strings(zf, zh) if zh else {}
        # 扩展组件也有自己的表
        extra = []
        for n in names:
            if n.endswith("en.lproj/Localizable.strings") and n != en:
                extra.append(n)

    missing = {k: v for k, v in en_map.items() if k not in zh_map}
    print(f"en 词条 {len(en_map)} / zh-Hans 词条 {len(zh_map)} / 缺中文 {len(missing)}")
    if extra:
        print("其它 en 表:", extra)
    same = [k for k, v in missing.items() if k == v]
    print(f"其中键值相同（无需翻译，多为品牌名）: {len(same)}")
    for k in same:
        print("  =", repr(k))
    rest = {k: v for k, v in missing.items() if k != v}
    print(f"\n待翻译 {len(rest)} 条:")
    for k, v in sorted(rest.items()):
        print(f"  {k!r}\n      -> {v!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
