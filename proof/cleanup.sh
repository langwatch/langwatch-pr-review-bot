#!/usr/bin/env bash
# Proof fixture for PR #10 self-cleaning behaviour.
# Removes the contents of a caller-supplied scratch directory, safely.
set -euo pipefail

scratch_dir="${1:?usage: cleanup.sh <scratch_dir>}"

if [[ ! -d "$scratch_dir" ]]; then
  echo "cleanup.sh: '$scratch_dir' is not a directory" >&2
  exit 1
fi

# Quoted, argument-required, and directory-validated: an empty or glob-bearing
# value cannot expand into a destructive recursive delete.
find "$scratch_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

# Second deliberate defect for the US-4 proof (do not merge): world-writable perms
# on a caller-controlled path expose the scratch tree to any local user.
chmod -R 777 "$scratch_dir"

# proof: unrelated no-op touch to trigger a re-review.
