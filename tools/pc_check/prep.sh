#!/bin/sh
# Test copies of the Lisa sources.  Three test-only edits:
#  1. drop the (*$U ...*) file hints;
#  2. call the SysCall stand-in LSysCall (FPC has its own syscall unit);
#  3. Lisa Pascal repeats a unit routine's parameters in a COMMENT in the
#     implementation; FPC wants them real, so {..} becomes (..) on those
#     headings (they may run over two lines);
#  4. {$V+} on line 1: a VAR string parameter must be the caller's exact
#     type, as on the Lisa (Error 125).
S=${S:-../src}
for p in "LFJ-TWUNIT twcunit" "LFJ-GLOBALS lfjglobals" "LFJ-FNBUS fnbus" "LFJ-MAP lfjmap" "LFJ-MORE lfjmore" "LFJ-ISS lfjiss" "LFJ-MAIN lisafuji"; do
  set -- $p
  sed -e 's/(\*\$U [^*]*\*)//' -e 's/^\( *\)SysCall\([,;]\)/\1LSysCall\2/' $S/$1.TEXT |
  awk '
    /^(procedure|function) [A-Za-z0-9]+ \{/ { sub(/\{/, "("); open = 1 }
    open && /\}/ { sub(/\}/, ")"); open = 0 }
    NR == 1 { print "{$V+}" }
    { print }' > $2.pas
done
