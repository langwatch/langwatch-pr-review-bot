#!/usr/bin/env bash
# Throwaway proof fixture for PR #10's self-cleaning behaviour (do not merge).
# Removes a caller-supplied scratch directory after a run.
set -euo pipefail

scratch_dir="${1:-}"

# DEFECT (deliberate): unquoted and unguarded. When $scratch_dir is empty this
# expands to `rm -rf /*`, and word-splitting/globbing on the value makes it worse.
rm -rf $scratch_dir/*
