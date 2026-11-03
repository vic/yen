#!/usr/bin/env bash
# Fleet cost oracles (NIX_SHOW_STATS): a lever must save work and keep every drvPath.
#   modlist: web-1 and app-2 with the trimmed base module lists use at most 95% of the thunks of the full lists
# Run from this directory: bash cost.sh   (each case capped at 600 s and 12 GiB)
set -u
cd "$(dirname "${BASH_SOURCE[0]}")"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0
# in CI (no systemd user session) the cap is `timeout` alone; locally it adds a 12 GiB scope
run() { # name args -> stats json + output
  if [ -n "${CI:-}" ]; then
    NIX_SHOW_STATS=1 NIX_SHOW_STATS_PATH="$tmp/$1.json" timeout -k 5 600 nix-instantiate --eval --strict "${@:2}" >"$tmp/$1.out" 2>"$tmp/$1.err"
  else
    timeout -k 5 600 systemd-run --user --scope -q -p MemoryMax=12G -E NIX_SHOW_STATS=1 -E NIX_SHOW_STATS_PATH="$tmp/$1.json" \
      nix-instantiate --eval --strict "${@:2}" >"$tmp/$1.out" 2>"$tmp/$1.err"
  fi
}
run full --arg trimmed false bench-modlist.nix && run trim --arg trimmed true bench-modlist.nix || { echo "FAIL modlist (eval)"; exit 1; }
for m in cpuTime nrThunks nrFunctionCalls; do printf '%s full=%s trimmed=%s\n' "$m" "$(jq ".$m" "$tmp/full.json")" "$(jq ".$m" "$tmp/trim.json")"; done
for m in values.bytes sets.bytes list.bytes gc.totalBytes; do printf '%s full=%s trimmed=%s\n' "$m" "$(jq ".$m" "$tmp/full.json")" "$(jq ".$m" "$tmp/trim.json")"; done
if ! cmp -s "$tmp/full.out" "$tmp/trim.out"; then echo "FAIL modlist-drv (drvPaths differ)"; fails=$((fails + 1)); else echo "PASS modlist-drv"; fi
f=$(jq .nrThunks "$tmp/full.json"); t=$(jq .nrThunks "$tmp/trim.json")
if [ $((t * 100)) -le $((f * 95)) ]; then echo "PASS modlist-thunks ($t <= 0.95 x $f)"; else echo "FAIL modlist-thunks ($t > 0.95 x $f)"; fails=$((fails + 1)); fi
exit $fails
