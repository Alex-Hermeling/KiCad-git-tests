#!/usr/bin/env bash
# Replace or remove one pull request's diff images on the `pr-diffs` branch.
#
#   update-pr-diffs-branch.sh <pr-number> [<image dir>]
#
# With an image dir, its contents become pr-<number>/ on the branch.
# Without one, pr-<number>/ is deleted (used when the PR is closed).
#
# The branch is rewritten as a single orphan commit every time, so images from
# old pushes and closed PRs never pile up in the repository's history.
#
# Needs GITHUB_TOKEN (contents: write) and GITHUB_REPOSITORY.
set -euo pipefail

pr="$1"
src="${2:-}"
[ -n "$src" ] && src=$(cd "$src" && pwd)

branch=pr-diffs
remote="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
work="${RUNNER_TEMP:-/tmp}/pr-diffs-work"

# Two PRs can publish at the same moment. The push is guarded with
# --force-with-lease, so the loser retries on top of the winner's commit.
for attempt in 1 2 3 4 5; do
  cd /
  rm -rf "$work"
  git init -q "$work"
  cd "$work"
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

  old=""
  if git ls-remote --exit-code --heads "$remote" "$branch" >/dev/null; then
    git fetch -q --depth 1 "$remote" "refs/heads/$branch"
    old=$(git rev-parse FETCH_HEAD)
    git read-tree -u --reset FETCH_HEAD
  elif [ -z "$src" ]; then
    echo "No $branch branch, nothing to remove."
    exit 0
  fi

  rm -rf "pr-$pr"
  if [ -n "$src" ]; then
    mkdir -p "pr-$pr"
    cp -r "$src"/. "pr-$pr"/
    message="Diff images for PR #$pr"
  else
    message="Remove diff images for closed PR #$pr"
  fi

  git add -A
  commit=$(git commit-tree "$(git write-tree)" -m "$message")

  if git push -q --force-with-lease="refs/heads/$branch:$old" "$remote" "$commit:refs/heads/$branch"; then
    echo "$message ($branch @ ${commit::7})"
    exit 0
  fi
  echo "$branch changed while updating (attempt $attempt), retrying..." >&2
  sleep $((attempt * 3))
done

echo "Gave up updating $branch after 5 attempts." >&2
exit 1
