#!/usr/bin/env python3
"""Pre-flight for Lisa Pascal sources (Tim's checklist).  Usage:
   preflight.py <lisa source root or -> FILE.TEXT ...
Checks: braces balanced and never nested (outside quotes); begin/case/record
against end; longest line and string literal; identifiers that clash in the
first 8 characters (the Lisa compiler ignores the rest); new identifiers that
match a word in the interface of a Lisa unit the tool uses."""
import re, sys, glob, os
root, files = sys.argv[1], sys.argv[2:]
KW = set("""and array begin case const div do downto else end file for forward function goto if in
interface implementation label mod nil not of or otherwise packed procedure program record repeat set
string then to type unit until uses var while with exit halt true false integer longint boolean char
real text ord chr length concat copy pos sizeof abs odd succ pred""".split())
def strip(src):
    """-> (code without comments and string bodies, list of literals, problems)"""
    out, lits, probs = [], [], []
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n": line += 1
        if c == "'":
            j = i + 1; s = ""
            while j < n:
                if src[j] == "'":
                    if j + 1 < n and src[j+1] == "'": s += "'"; j += 2; continue
                    break
                if src[j] == "\n": probs.append("line %d: string runs past the end of the line" % line); break
                s += src[j]; j += 1
            lits.append((line, s)); out.append("''"); i = j + 1; continue
        if c == "{":
            j = i + 1
            while j < n and src[j] != "}":
                if src[j] == "{": probs.append("line %d: NESTED open brace in a comment" % line)
                if src[j] == "\n": line += 1
                j += 1
            if j >= n: probs.append("line %d: comment never closed" % line)
            out.append(" "); i = j + 1; continue
        if c == "}": probs.append("line %d: close brace with no open brace" % line)
        if src.startswith("(*", i):
            j = src.find("*)", i + 2)
            if j < 0: probs.append("line %d: (* never closed" % line); j = n
            line += src.count("\n", i, j); out.append(" "); i = j + 2; continue
        out.append(c); i += 1
    return "".join(out), lits, probs
def idents(code): return re.findall(r"[A-Za-z_][A-Za-z0-9_]*", code)
lisa = {}
if root != "-":
    pats = ["LIBSM/LIBSM-UNITSTD", "LIBSM/LIBSM-UNITHZ", "LIBQD/libqd-STORAGE", "LIBQD/libqd-QUICKDRAW", "LIBFM/libfm-fontmgr",
            "LIBOS/libos-syscall", "LIBWM/LIBWM-EVENTS", "LIBWM/libwm-folders", "LIBWM/LIBWM-MENUS", "LIBAM/LIBAM-ALERTMGR",
            "LIBSB/libsb-WMLSTD", "LIBSB/libsb-WMLCRS", "LIBFC/libfc-FILERCOMM"]
    for p in pats:
        g = glob.glob(os.path.join(root, "LISA_OS/LIBS", p + "*"))
        assert g, p
        src = open(g[0], errors="replace").read()
        m = re.search(r"\bimplementation\b", src, re.I)
        code, _, _ = strip(src[:m.start()] if m else src)
        for w in idents(code):
            lisa.setdefault(w.lower()[:8], set()).add((w, os.path.basename(g[0]).split(".")[0]))
    print("Lisa interface words read from %d units: %d distinct 8-character stems" % (len(pats), len(lisa)))
allids, total_bad = {}, 0
for f in files:
    src = open(f).read()
    code, lits, probs = strip(src)
    nolit = re.sub(r"'[^'\n]*'", "", src)
    ob, cb = nolit.count("{"), nolit.count("}")
    toks = [t.lower() for t in idents(code)]
    b, e, cs, rc = toks.count("begin"), toks.count("end"), toks.count("case"), toks.count("record")
    longest = max(len(l) for l in src.split("\n"))
    litmax = max([len(s) for _, s in lits] or [0])
    tabs = src.count("\t"); nonascii = sum(1 for ch in src if ord(ch) > 126)
    is_unit = toks[0] == "unit"
    okbe = (b + cs + rc + (1 if is_unit else 0) == e)
    print("%-18s braces %d/%d  begin %d + case %d + record %d%s = end %d %s  longest line %d  longest literal %d  tabs %d  non-ASCII %d" %
          (os.path.basename(f), ob, cb, b, cs, rc, " + unit 1" if is_unit else "", e, "ok" if okbe else "MISMATCH", longest, litmax, tabs, nonascii))
    for p in probs: print("   PROBLEM", p); total_bad += 1
    if ob != cb or not okbe or tabs or nonascii or longest > 144: total_bad += 1; print("   PROBLEM in the counts above")
    for ln, s in lits:
        if len(s) > 80: print("   PROBLEM line %d: literal of %d characters" % (ln, len(s))); total_bad += 1
    for w in idents(code):
        if w.lower() not in KW: allids.setdefault(w.lower(), set()).add(os.path.basename(f))
stems = {}
for w in allids: stems.setdefault(w[:8], []).append(w)
clash = {k: v for k, v in stems.items() if len(v) > 1}
print("%d distinct identifiers; clashes in the first 8 characters: %d" % (len(allids), len(clash)))
for k, v in sorted(clash.items()): print("   CLASH", k, v); total_bad += 1
if lisa:
    hits = sorted(w for w in allids if w[:8] in lisa)
    exact = [w for w in hits if any(x.lower() == w for x, _ in lisa[w[:8]])]
    stemonly = [w for w in hits if w not in exact]
    print("identifiers that ARE a Lisa interface word (expected: the calls and types we use, plus harmless locals):")
    print("   " + " ".join(exact))
    print("identifiers that only SHARE 8 characters with a different Lisa word (each one is a risk):")
    for w in stemonly: print("   RISK", w, "~", sorted(lisa[w[:8]])); total_bad += 1
    if not stemonly: print("   none")
print("PRE-FLIGHT", "CLEAN" if total_bad == 0 else "FOUND %d PROBLEM(S)" % total_bad)
