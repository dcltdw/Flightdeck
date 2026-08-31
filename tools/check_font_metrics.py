#!/usr/bin/env python3
"""Verify the hardcoded ascents in ``source/`` match the generated font atlases.

``Theme.mc`` positions text by baseline and subtracts a per-font ascent to reach
the ``drawText`` cell top, so every ``base=`` in ``resources-390x390/fonts/*.fnt``
has a matching literal in the Monkey C source. Change the source font without
updating those literals and every string silently shifts vertically — the build
still succeeds and the simulator is the only thing that notices.

This is that check, so it doesn't depend on someone noticing.

Usage:
  python3 tools/check_font_metrics.py     # exit 0 clean, 1 on any mismatch
"""

import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))

# Source constants are all expressed at the 390 reference and scaled at draw.
REF_BUCKET = "resources-390x390"

# font id -> (human description, regex capturing the ascent literal in source)
CHECKS = [
    ("hero", "L.heroAsc", r"L\.heroAsc = (\d+)"),
    ("value52", "L.valAsc", r"L\.valAsc = (\d+)"),
    ("label", "L.lblAsc", r"L\.lblAsc = (\d+)"),
    ("title", "L.titleAsc", r"L\.titleAsc = (\d+)"),
    ("value60", "VAL60_ASC", r"VAL60_ASC = (\d+)"),
    ("value40", "VAL40_ASC", r"VAL40_ASC = (\d+)"),
    ("value64", "cutFont ladder", r"fonts\.value64\(\), (\d+)\]"),
    ("value76", "cutFont ladder", r"fonts\.value76\(\), (\d+)\]"),
    ("value88", "cutFont ladder", r"fonts\.value88\(\), (\d+)\]"),
    ("value104", "cutFont ladder", r"fonts\.value104\(\), (\d+)\]"),
    ("value52", "cutFont ladder", r"fonts\.value52\(\), (\d+)\]"),
    ("value44", "cutFont ladder", r"fonts\.value44\(\), (\d+)\]"),
    ("value", "fitGridFont/fitValueFont floor", r"fonts\.value, (\d+)\]"),
]


def fnt_bases():
    bases = {}
    for path in glob.glob(os.path.join(ROOT, REF_BUCKET, "fonts", "*.fnt")):
        m = re.search(r"base=(\d+)", open(path).read())
        if m:
            bases[os.path.basename(path)[:-4]] = int(m.group(1))
    return bases


def source_text():
    paths = glob.glob(os.path.join(ROOT, "source", "*.mc"))
    paths += glob.glob(os.path.join(ROOT, "source", "themes", "*.mc"))
    return "".join(open(p).read() for p in paths)


def main():
    bases = fnt_bases()
    if not bases:
        sys.exit("No .fnt files under %s — run tools/gen_fonts.py first." % REF_BUCKET)
    text = source_text()

    failures = 0
    for fid, where, pattern in CHECKS:
        want = bases.get(fid)
        if want is None:
            print("MISSING  %-9s no %s.fnt in %s" % (fid, fid, REF_BUCKET))
            failures += 1
            continue
        found = sorted({int(m) for m in re.findall(pattern, text)})
        if not found:
            print("MISSING  %-9s no literal matched in source (%s)" % (fid, where))
            failures += 1
        elif found != [want]:
            print("MISMATCH %-9s .fnt base=%d but source has %s (%s)"
                  % (fid, want, found, where))
            failures += 1
        else:
            print("ok       %-9s base=%-4d %s" % (fid, want, where))

    if failures:
        print("\n%d problem(s). Re-run tools/gen_fonts.py and reconcile the ascent "
              "table it prints against the constants above." % failures)
        return 1
    print("\nAll %d ascents agree with %s." % (len(CHECKS), REF_BUCKET))
    return 0


if __name__ == "__main__":
    sys.exit(main())
