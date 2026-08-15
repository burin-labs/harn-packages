#!/usr/bin/env bash
# Carry the reconciler's proposal to a pull request, or withdraw a superseded
# one. `reconcile-index.harn` decides what the index should say and writes the
# title and body; this script only transports them.
#
# The branch is bot-owned. Every run resets it to current main and re-applies
# the current proposal, so a daily schedule updates one pull request instead of
# accumulating one per day.
#
# Commits go through the contents API rather than `git push`. The API signs
# them with GitHub's key, which the required-signature rule on main expects,
# and it needs no credential in the checkout: the reconcile job checks out with
# `persist-credentials: false` because a credential config there points outside
# the Harn sandbox and breaks every `git` call in the worktree.
set -euo pipefail

action="${1:?usage: propose-index-drift.sh open|withdraw}"
repo="${INDEX_REPO:?INDEX_REPO must name owner/name}"
branch="${PROPOSAL_BRANCH:-reconcile/index-drift}"
index_path="harn-package-index.toml"
title_file="reconcile-pr-title.txt"
body_file="reconcile-pr-body.md"

open_pr_number() {
  gh pr list --repo "$repo" --head "$branch" --state open --json number \
    --jq '.[0].number // empty'
}

branch_exists() {
  gh api "repos/$repo/git/ref/heads/$branch" >/dev/null 2>&1
}

if [[ "$action" == "withdraw" ]]; then
  number="$(open_pr_number)"
  if [[ -z "$number" ]]; then
    echo "No open proposal to withdraw."
    exit 0
  fi
  gh pr close "$number" --repo "$repo" --delete-branch \
    --comment "The index now agrees with every upstream release, so this proposal is superseded. The reconciler will open a fresh one if drift returns."
  echo "Withdrew superseded proposal #$number."
  exit 0
fi

base_sha="$(gh api "repos/$repo/git/ref/heads/main" --jq .object.sha)"
push_needed=1

if branch_exists; then
  # An unchanged proposal is left alone so the pull request keeps its review
  # history instead of gaining an identical commit every morning.
  head_content="$(gh api "repos/$repo/contents/$index_path?ref=$branch" --jq .content |
    tr -d '\n' | base64 --decode)"
  if [[ "$head_content" == "$(cat "$index_path")" ]]; then
    push_needed=0
    echo "Proposal branch already carries this exact index."
  else
    gh api --method PATCH "repos/$repo/git/refs/heads/$branch" \
      -F sha="$base_sha" -F force=true >/dev/null
  fi
else
  gh api --method POST "repos/$repo/git/refs" \
    -f ref="refs/heads/$branch" -f sha="$base_sha" >/dev/null
fi

if [[ "$push_needed" == "1" ]]; then
  blob_sha="$(gh api "repos/$repo/contents/$index_path?ref=$branch" --jq .sha)"
  gh api --method PUT "repos/$repo/contents/$index_path" \
    -f message="$(cat "$title_file")" \
    -f branch="$branch" \
    -f sha="$blob_sha" \
    -f content="$(base64 <"$index_path" | tr -d '\n')" >/dev/null
  echo "Pushed the proposed index to $branch."
fi

number="$(open_pr_number)"
if [[ -z "$number" ]]; then
  # Drift with no open proposal is the state this whole mechanism exists to
  # prevent, so a closed pull request does not silence it.
  gh pr create --repo "$repo" --base main --head "$branch" \
    --title "$(cat "$title_file")" --body-file "$body_file"
else
  gh pr edit "$number" --repo "$repo" \
    --title "$(cat "$title_file")" --body-file "$body_file"
  echo "Updated proposal #$number."
fi
