#!/usr/bin/env python3
"""Build the USB package from source; never include personal journal data."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "koreader" / "ebookdiary.koplugin"
OUTPUT = ROOT / "dist" / "ebook-diary-koreader-prototype.zip"


def main():
    files = [(p, p.relative_to(PLUGIN.parent).as_posix())
             for p in sorted(PLUGIN.rglob("*"))
             if p.is_file() and p.suffix in {".lua", ".svg"}]
    files.append((ROOT / "koreader" / "README.md", "INSTALLATION.md"))
    OUTPUT.parent.mkdir(exist_ok=True)
    with ZipFile(OUTPUT, "w", compression=ZIP_DEFLATED) as archive:
        for path, name in files:
            info = ZipInfo(name, date_time=(2026, 10, 16, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes())
    with ZipFile(OUTPUT) as archive:
        assert archive.testzip() is None
        assert "ebookdiary.koplugin/main.lua" in archive.namelist()
        assert sum(name.endswith(".svg") for name in archive.namelist()) == 5
    print(f"Created {OUTPUT} ({len(files)} files)")


if __name__ == "__main__":
    main()
