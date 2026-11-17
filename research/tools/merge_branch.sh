#!/usr/bin/env bash
# Merge builder branches into master only if they merge cleanly and the scoreboard holds.
# Usage: research/tools/merge_branch.sh branch...
set -uo pipefail
cd "$(dirname "$0")/../.."
git fetch -q origin
for b in "$@"; do
  if [ -z "$(git log --oneline master..origin/$b)" ]; then echo "$b: nothing new"; continue; fi
  if ! git merge -q --no-edit "origin/$b" >/dev/null 2>&1; then
    echo "$b: CONFLICT in $(git diff --name-only --diff-filter=U | tr '\n' ' ')"; git merge --abort; continue
  fi
  out=$(python3 selfhost/scoreboard.py --enforce 2>&1); rc=$?
  echo "$out" | grep -E "^(bootstrap|run|reject|stdlib)|REGRESSED" | sed "s/^/$b: /"
  if [ $rc -ne 0 ]; then echo "$b: ENFORCE FAILED, undoing merge"; git reset -q --hard HEAD~1; continue; fi
  python3 selfhost/scoreboard.py --update >/dev/null 2>&1
  git add selfhost/scoreboard; git diff --cached --quiet || git commit -qm "Record the boards after merging $b

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  echo "$b: merged"
done
git pull -q --rebase && git push -q && git log --oneline -1
