#!/usr/bin/env python3
"""pkr_dump - list and extract Spider-Man (2000) PC .PKR archives.

Pure stdlib (struct, zlib, argparse). No install needed besides Python 3.

Format (from pkr.h / pkr.cpp in this repo):
  header @0:        magic u32 (0x33524B50 "PKR3"), dir_offset u32
  footer @dir_off:  field0 i32, num_dirs u32, num_files u32
  then num_dirs DIRINFO (0x28): name[32], first_file_idx u32, num_files u32
  then per dir, num_files FILEINFO (0x34): name[32], crc32 u32,
      compressed i32 (-2 = raw, else zlib), offset u32, usize u32, csize u32

Usage (on your PC, where the game is installed):
  python pkr_dump.py list "C:\\Games\\Spider-Man\\data.pkr"
  python pkr_dump.py list data.pkr > pkr_list.txt            (send us this!)
  python pkr_dump.py extract data.pkr -o out
  python pkr_dump.py extract data.pkr -o out -m spidey       (name filter)

Only data you own: point this at YOUR OWN game copy (learning use).
Never commit extracted game assets to git.
"""

import argparse
import struct
import sys
import zlib
from pathlib import Path

MAGIC = 0x33524B50
RAW = -2

HEADER = struct.Struct("<II")
FOOTER = struct.Struct("<iII")
DIRINFO = struct.Struct("<32sII")
FILEINFO = struct.Struct("<32sIiIII")


def _name(raw: bytes) -> str:
    return raw.split(b"\x00")[0].decode("ascii", errors="replace")


def _safe(part: str) -> str:
    cleaned = "".join(c for c in part if c not in "/\\:*?\"<>|").strip().rstrip(".")
    return cleaned or "_"


class Pkr:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.fp = path.open("rb")
        magic, dir_off = HEADER.unpack(self._read_at(0, HEADER.size))
        if magic != MAGIC:
            raise ValueError(
                "%s: bad magic %08X (want %08X)" % (path, magic, MAGIC)
            )
        self.fp.seek(dir_off)
        _f0, num_dirs, num_files_total = FOOTER.unpack(
            self.fp.read(FOOTER.size)
        )
        self.dirs: list[tuple[str, list[dict]]] = []
        dir_names: list[str] = []
        dir_counts: list[int] = []
        for _ in range(num_dirs):
            raw, _first, count = DIRINFO.unpack(self.fp.read(DIRINFO.size))
            dir_names.append(_name(raw))
            dir_counts.append(count)
        for dname, count in zip(dir_names, dir_counts):
            files: list[dict] = []
            for _ in range(count):
                parts = FILEINFO.unpack(self.fp.read(FILEINFO.size))
                files.append(
                    {
                        "name": _name(parts[0]),
                        "crc": parts[1],
                        "compressed": parts[2],
                        "offset": parts[3],
                        "usize": parts[4],
                        "csize": parts[5],
                    }
                )
            self.dirs.append((dname, files))
        self.num_files_total = num_files_total

    def _read_at(self, off: int, size: int) -> bytes:
        self.fp.seek(off)
        data = self.fp.read(size)
        if len(data) != size:
            raise ValueError("short read at offset %d" % off)
        return data

    def read_file(self, info: dict) -> bytes:
        if not info["csize"]:
            raise ValueError("'%s' has no data" % info["name"])
        raw = self._read_at(info["offset"], info["csize"])
        data = raw if info["compressed"] == RAW else zlib.decompress(raw)
        if len(data) != info["usize"]:
            raise ValueError(
                "'%s': size mismatch (%d != %d)"
                % (info["name"], len(data), info["usize"])
            )
        if zlib.crc32(data) & 0xFFFFFFFF != info["crc"]:
            raise ValueError("'%s': CRC mismatch" % info["name"])
        return data

    def close(self) -> None:
        self.fp.close()


def cmd_list(args: argparse.Namespace) -> int:
    pkr = Pkr(Path(args.archive))
    total_c = 0
    total_u = 0
    print("# %s: %d dirs" % (args.archive, len(pkr.dirs)))
    for dname, files in pkr.dirs:
        print("== [%s] (%d files)" % (dname, len(files)))
        for f in files:
            flag = "raw " if f["compressed"] == RAW else "zlib"
            print(
                "  %-28s %s c=%-8d u=%-8d crc=%08X" % (
                    f["name"][:28], flag, f["csize"], f["usize"], f["crc"]
                )
            )
            total_c += f["csize"]
            total_u += f["usize"]
    print("# total: %d files, compressed=%d, uncompressed=%d" % (
        sum(len(files) for _, files in pkr.dirs), total_c, total_u))
    pkr.close()
    return 0


def cmd_extract(args: argparse.Namespace) -> int:
    pkr = Pkr(Path(args.archive))
    out = Path(args.out)
    needle = args.match.lower() if args.match else None
    done = 0
    skipped = 0
    for dname, files in pkr.dirs:
        for f in files:
            hay = (dname + "/" + f["name"]).lower()
            if needle and needle not in hay:
                skipped += 1
                continue
            try:
                data = pkr.read_file(f)
            except ValueError as err:
                print("FAIL %s/%s: %s" % (dname, f["name"], err))
                continue
            dest = out / _safe(dname) / _safe(f["name"])
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            done += 1
    print("extracted %d files to %s (skipped %d)" % (done, out, skipped))
    pkr.close()
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Spider-Man (2000) PKR lister/extractor")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_list = sub.add_parser("list", help="print dirs + files + sizes")
    p_list.add_argument("archive")
    p_list.set_defaults(func=cmd_list)
    p_ext = sub.add_parser("extract", help="extract files (CRC-verified)")
    p_ext.add_argument("archive")
    p_ext.add_argument("-o", "--out", default="pkr_out")
    p_ext.add_argument("-m", "--match", default=None,
                       help="only names containing this substring")
    p_ext.set_defaults(func=cmd_extract)
    args = ap.parse_args(argv)
    try:
        return args.func(args)
    except (ValueError, OSError) as err:
        print("error: %s" % err, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
