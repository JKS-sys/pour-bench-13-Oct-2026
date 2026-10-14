#!/usr/bin/env bash
# pour-bench · bench.sh — Pour against Homebrew on this machine, honestly.
#
#   bash bench.sh                      default package set
#   bash bench.sh jq wget ffmpeg       your own set
#   POUR_ONLY=1 bash bench.sh          when Homebrew is not installed
#   BENCH_OUT=/tmp/try bash bench.sh   write the results somewhere else
#
# For each package, in this order, each starting from "not installed":
#   brew cold  → nothing installed, empty download cache → brew install
#   brew warm  → nothing installed, downloads cached      → brew install
#   pour cold  → nothing installed, empty store and cache → pour install
#   pour warm  → nothing installed, store kept            → pour install
# plus search/info/outdated timings. Writes results/<date>/benchmark.md and
# raw timings to results/<date>/timings.tsv. Nothing is invented: every number
# is a measured wall-clock time on the machine that ran this.
set -uo pipefail
cd "$(dirname "$0")"
PKGS=("$@"); [ ${#PKGS[@]} -gt 0 ] || PKGS=(jq wget tree ripgrep fd bat sqlite python@3.13 node ffmpeg)
DATE=$(date -u +%Y-%m-%d); OUT=${BENCH_OUT:-results/$DATE}; mkdir -p "$OUT"
TSV=$OUT/timings.tsv; : > "$TSV"
POUR=${POUR_BIN:-$(command -v pour || echo /opt/pour/bin/pour)}
HAVE_BREW=0; [ -z "${POUR_ONLY:-}" ] && command -v brew >/dev/null && HAVE_BREW=1
# Timing uses bash's own `time` keyword (TIMEFORMAT=%3R): it costs nothing,
# so a 4 ms command is reported as 4 ms, not 4 ms plus a Python start-up.
TIMEFORMAT=%3R
timeit() { # timeit <label> <cmd...>  → prints whole ms, logs
  local label=$1; shift; local t rc
  t=$( { time "$@" >/dev/null 2>&1; } 2>&1 ); rc=$?
  t=$((10#${t/./}))
  printf '%s\t%s\t%s\n' "$label" "$t" "$rc" >> "$TSV"; echo "$t"
}
mean_ms() { # mean_ms <label> <runs> <cmd...>  → mean ms with one decimal, logs
  local label=$1 n=$2; shift 2; local t
  t=$( { time for ((i = 0; i < n; i++)); do "$@" >/dev/null 2>&1; done; } 2>&1 )
  t=$(python3 -c "print(f'{$t*1000/$n:.1f}')")
  printf '%s\t%s\t%s\n' "$label (mean of $n)" "$t" 0 >> "$TSV"; echo "$t"
}
fmt() { python3 -c "v=float('$1'); print(f'{v/1000:.2f} s' if v >= 1000 else (f'{v:.0f} ms' if v >= 100 else f'{v:g} ms'))"; }
ratio() { python3 -c "a,b=float('$1'),float('$2'); print('—' if b==0 else f'{a/b:.1f}×')"; }

echo "# Pour vs Homebrew — $DATE" > "$OUT/benchmark.md"
{
  echo
  echo "Machine: $(uname -srm) · $(sysctl -n machdep.cpu.brand_string 2>/dev/null || grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs) · $(python3 -c 'import os; print(os.cpu_count())') CPUs"
  echo "Pour: $($POUR --version) · Homebrew: $([ $HAVE_BREW = 1 ] && brew --version | head -1 || echo 'not installed (Pour-only run)')"
  echo
  echo "| Package | brew cold | pour cold | speed-up | brew warm | pour warm | speed-up |"
  echo "|---|---|---|---|---|---|---|"
} >> "$OUT/benchmark.md"

# Fair protocol (the one zerobrew uses): before every cold run NOTHING is
# installed in that manager and its download cache is empty; before every
# warm run nothing is installed either, but the downloads from the cold run
# are still cached. So both tools install the package AND its whole
# dependency tree every time.
reset_pour() { # reset_pour [keep-cache]
  local names; names=$("$POUR" list --json 2>/dev/null | python3 -c 'import sys,json; print(" ".join(x["name"] for x in json.load(sys.stdin)["formulae"]))' 2>/dev/null)
  [ -n "$names" ] && "$POUR" uninstall --ignore-dependencies $names >/dev/null 2>&1 || true
  if [ "${1:-}" != keep ]; then "$POUR" cleanup >/dev/null 2>&1 || true; rm -rf "$("$POUR" --cache)"/downloads/* "$("$POUR" --prefix)"/store/* 2>/dev/null || true; fi
}
reset_brew() { # reset_brew [keep-cache]
  local names; names=$(brew list --formula -1 2>/dev/null | tr '\n' ' ')
  [ -n "$names" ] && brew uninstall --ignore-dependencies --force $names >/dev/null 2>&1 || true
  if [ "${1:-}" != keep ]; then brew cleanup -s --prune=all >/dev/null 2>&1 || true; rm -rf "$(brew --cache)"/* 2>/dev/null || true; fi
}
for p in "${PKGS[@]}"; do
  bc=0; bw=0
  if [ $HAVE_BREW = 1 ]; then
    reset_brew
    bc=$(timeit "brew-cold-$p" brew install "$p")
    reset_brew keep
    bw=$(timeit "brew-warm-$p" brew install "$p")
  fi
  reset_pour
  pc=$(timeit "pour-cold-$p" "$POUR" install "$p")
  reset_pour keep
  pw=$(timeit "pour-warm-$p" "$POUR" install "$p")
  printf '| %s | %s | %s | %s | %s | %s | %s |\n' "$p" "$([ $HAVE_BREW = 1 ] && fmt $bc || echo —)" "$(fmt $pc)" "$([ $HAVE_BREW = 1 ] && ratio $bc $pc || echo —)" "$([ $HAVE_BREW = 1 ] && fmt $bw || echo —)" "$(fmt $pw)" "$([ $HAVE_BREW = 1 ] && ratio $bw $pw || echo —)" >> "$OUT/benchmark.md"
  echo "$p: pour cold $(fmt $pc), warm $(fmt $pw)$([ $HAVE_BREW = 1 ] && echo " · brew cold $(fmt $bc), warm $(fmt $bw)")"
done

{
  echo
  echo "## Everyday commands"
  echo
  echo "| Command | Homebrew | Pour | speed-up |"
  echo "|---|---|---|---|"
} >> "$OUT/benchmark.md"
# Each command runs several times and the mean is reported: 3 runs for
# Homebrew (they take a while), 20 for Pour. Both have jq installed here.
"$POUR" install jq >/dev/null 2>&1; [ $HAVE_BREW = 1 ] && brew install jq >/dev/null 2>&1
for cmd in "search json" "info jq" "outdated" "list"; do
  b=0; [ $HAVE_BREW = 1 ] && b=$(mean_ms "brew-$cmd" 3 brew $cmd)
  pm=$(mean_ms "pour-$cmd" 20 "$POUR" $cmd)
  printf '| `%s` | %s | %s | %s |\n' "$cmd" "$([ $HAVE_BREW = 1 ] && fmt "$b" || echo —)" "$(fmt "$pm")" "$([ $HAVE_BREW = 1 ] && ratio "$b" "$pm" || echo —)" >> "$OUT/benchmark.md"
done
echo >> "$OUT/benchmark.md"
echo "Raw timings: \`$OUT/timings.tsv\`. Re-run with \`bash bench.sh\`." >> "$OUT/benchmark.md"
echo; cat "$OUT/benchmark.md"
