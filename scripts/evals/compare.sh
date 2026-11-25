#!/usr/bin/env bash
set -euo pipefail

# Runs a skill's evals on the skill as it was at an earlier commit and on the
# working tree, and compares the grades expectation by expectation.
#
# Usage:
#   scripts/evals/compare.sh <skill> [--base <ref>] [eval-id...]
#
# It exports the repo at <ref> (origin/main by default) with `git archive`,
# puts the working tree's evals/ folder in place of the old skill's, so both
# sides run the same evals, and runs run.sh on that copy (with --from) and on
# the working tree. Then it prints, for each expectation, whether it passed
# before and now, marked gained, lost or unchanged. An expectation with no
# grade counts as failed. It exits 1 if any expectation was lost.
#
# The base run's results are kept in <skill>-workspace/<timestamp>-base/,
# next to the working tree's. run.sh's environment variables apply to both
# runs.

usage() {
	sed -n '/^# Usage:/,/^# It exports/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d' >&2
	exit 2
}

die() {
	echo "error: $*" >&2
	exit 1
}

repo="$(cd "$(dirname "$0")/../.." && pwd)"

[ $# -ge 1 ] || usage
skill="$1"
shift
base="origin/main"
ids=()
while [ $# -gt 0 ]; do
	case "$1" in
	--base)
		[ $# -ge 2 ] || usage
		base="$2"
		shift
		;;
	-h | --help) usage ;;
	[0-9]*) ids+=("$1") ;;
	*) usage ;;
	esac
	shift
done

# find_skill <root>: prints the skill's folder under <root>, or nothing.
find_skill() {
	local b
	for b in portable templates drafts; do
		if [ -f "$1/skills/$b/$skill/SKILL.md" ]; then
			echo "$1/skills/$b/$skill"
			return
		fi
	done
}

now_dir="$(find_skill "$repo")"
[ -n "$now_dir" ] || die "no skill named '$skill'"
[ -f "$now_dir/evals/evals.json" ] || die "$skill has no evals/evals.json"
git -C "$repo" rev-parse --verify --quiet "$base^{commit}" >/dev/null || die "unknown ref '$base'"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/skill-compare.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/base"
git -C "$repo" archive "$base" | tar -x -C "$tmp/base"
base_dir="$(find_skill "$tmp/base")"
[ -n "$base_dir" ] || die "$skill doesn't exist at $base"
rm -rf "$base_dir/evals"
cp -R "$now_dir/evals" "$base_dir/evals"

# run <log> [run.sh flags...]: runs the evals, showing run.sh's output, and
# prints the results folder it reports.
run() {
	local log="$1"
	shift
	"$repo/scripts/evals/run.sh" "$skill" "$@" ${ids[@]+"${ids[@]}"} | tee "$log" >&2
	sed -n 's/^results: //p' "$log" | tail -n 1
}

echo "== $skill at $base" >&2
base_results="$(run "$tmp/base.log" --from "$tmp/base")"
[ -n "$base_results" ] || die "run.sh reported no results for $base"
kept="$now_dir-workspace/$(basename "$base_results")-base"
mkdir -p "$now_dir-workspace"
cp -R "$base_results" "$kept"
echo "== $skill in the working tree" >&2
now_results="$(run "$tmp/now.log")"
[ -n "$now_results" ] || die "run.sh reported no results for the working tree"

# grades <results>: prints "<eval id><TAB><index><TAB><passed>" for every
# graded expectation.
grades() {
	local f id
	for f in "$1"/eval-*/grading.json; do
		[ -f "$f" ] || continue
		id="${f%/grading.json}"
		id="${id##*/eval-}"
		jq -r --arg id "$id" '.expectations | to_entries[] | "\($id)\t\(.key)\t\(.value.passed == true)"' "$f"
	done
}
grades "$kept" >"$tmp/before"
grades "$now_results" >"$tmp/now"

# grade <file> <id> <index>: prints pass, fail or "-" (not graded).
grade() {
	local passed
	passed="$(awk -F '\t' -v id="$2" -v i="$3" '$1 == id && $2 == i { print $3; exit }' "$1")"
	case "$passed" in
	true) echo pass ;;
	false) echo fail ;;
	*) echo - ;;
	esac
}

selected="$(printf '%s\n' ${ids[@]+"${ids[@]}"} | jq -R 'select(length > 0) | tonumber' | jq -s .)"
gained=0
lost=0
unchanged=0
printf '%-5s %-7s %-7s %-10s %s\n' eval before now change expectation
while IFS="$(printf '\t')" read -r id index text; do
	before="$(grade "$tmp/before" "$id" "$index")"
	now="$(grade "$tmp/now" "$id" "$index")"
	if [ "$before" = pass ] && [ "$now" != pass ]; then
		change=lost
		lost=$((lost + 1))
	elif [ "$before" != pass ] && [ "$now" = pass ]; then
		change=gained
		gained=$((gained + 1))
	else
		change=unchanged
		unchanged=$((unchanged + 1))
	fi
	printf '%-5s %-7s %-7s %-10s %s\n' "$id" "$before" "$now" "$change" "$text"
done < <(jq -r --argjson ids "$selected" '
	.evals[] | select(($ids | length) == 0 or (.id as $id | $ids | index($id)))
	| .id as $id | .expectations | to_entries[]
	| "\($id)\t\(.key)\t\(.value | gsub("[\t\n]"; " "))"' "$now_dir/evals/evals.json")
echo
echo "$gained gained, $lost lost, $unchanged unchanged"
echo "results: $kept (base), $now_results (now)"
[ "$lost" -eq 0 ]
