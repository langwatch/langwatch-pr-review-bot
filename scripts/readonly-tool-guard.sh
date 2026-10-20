#!/usr/bin/env bash
# Read-only guard for the commands the reviewer may run (git, rg, ast-grep/sg).
#
# The action installs this script under the names git, rg, ast-grep and sg in a
# directory it puts first on the reviewer's PATH. The working tree is the untrusted
# pull request and the reviewer's environment holds the Claude token, so every call
# is checked before the real binary runs:
#   - only read-only subcommands and flags are allowed;
#   - nothing that runs a program or loads repository config is allowed (git grep -O,
#     rg --pre / --hostname-bin, an sgconfig.yml from the pull request);
#   - no argument may name an existing path outside the workspace (this blocks
#     /proc/*/environ, credential files, and symlinks the pull request points outward);
#   - the real binary runs with a scrubbed environment that carries no secrets.
# The real binaries' absolute paths come from REVIEW_GUARD_REAL_<TOOL>, set by the
# action. A refusal exits 2 with a one-line reason on stderr.
set -euo pipefail

tool="$(basename "$0")"
workspace="${REVIEW_GUARD_WORKSPACE:-${GITHUB_WORKSPACE:-$PWD}}"
workspace="$(cd "$workspace" && pwd -P)"

refuse() {
  echo "readonly-tool-guard: refused ${tool}: $*" >&2
  exit 2
}

# An argument that names an existing filesystem path must resolve inside the workspace.
# Checked on the argument itself, on the value of --opt=value, and on the value glued to
# a short flag (-fFILE). Strings that are not existing paths (patterns, revisions) pass.
check_path() {
  local candidate="$1" resolved
  [[ -n "$candidate" ]] || return 0
  [[ -e "$candidate" || -L "$candidate" ]] || return 0
  resolved="$(realpath -- "$candidate" 2>/dev/null || realpath -m -- "$candidate" 2>/dev/null || true)"
  [[ -n "$resolved" ]] || refuse "cannot resolve path '${candidate}'"
  case "$resolved" in
    "$workspace" | "$workspace"/*) return 0 ;;
    *) refuse "path '${candidate}' is outside the workspace" ;;
  esac
}

check_args() {
  local a
  for a in "$@"; do
    check_path "$a"
    if [[ "$a" == --*=* ]]; then
      check_path "${a#*=}"
    elif [[ "$a" =~ ^-[A-Za-z].+ ]]; then
      check_path "${a:2}"
    fi
  done
}

run_real() {
  local real="$1"
  shift
  [[ -n "$real" && -x "$real" ]] || refuse "the real binary is not installed"
  exec env -i \
    PATH="${REVIEW_GUARD_PATH:-/usr/local/bin:/usr/bin:/bin}" \
    HOME="${HOME:-/tmp}" \
    LANG="${LANG:-C.UTF-8}" \
    TERM=dumb \
    PAGER=cat \
    GIT_PAGER=cat \
    GIT_CONFIG_NOSYSTEM=1 \
    "$real" "$@"
}

case "$tool" in
  git)
    sub="${1:-}"
    case "$sub" in
      diff | log | show | blame | grep) ;;
      *) refuse "only 'git diff|log|show|blame|grep' are allowed" ;;
    esac
    for a in "$@"; do
      case "$a" in
        -O* | --open-files-in-pager* | --output* | --no-index | --ext-diff | -f | --file | --file=* | --contents | --contents=*)
          refuse "flag '${a}' is not allowed" ;;
      esac
    done
    check_args "${@:2}"
    run_real "${REVIEW_GUARD_REAL_GIT:-}" "$@"
    ;;
  rg)
    for a in "$@"; do
      case "$a" in
        --pre | --pre=* | --pre-glob | --pre-glob=* | --hostname-bin | --hostname-bin=* | \
          -z | --search-zip | -L | --follow | -f | --file | --file=* | --ignore-file | --ignore-file=*)
          refuse "flag '${a}' is not allowed" ;;
      esac
      # A cluster of short flags (-iL) must not smuggle in follow-symlinks or decompress.
      if [[ "$a" =~ ^-[A-Za-z]+$ && "$a" =~ [Lz] ]]; then
        refuse "flag '${a}' is not allowed"
      fi
    done
    check_args "$@"
    run_real "${REVIEW_GUARD_REAL_RG:-}" --no-config "$@"
    ;;
  ast-grep | sg)
    [[ "${1:-}" == "run" ]] || refuse "only 'run --pattern' is allowed"
    has_pattern=false
    for a in "${@:2}"; do
      case "$a" in
        -p | --pattern | --pattern=* | -p?*) has_pattern=true ;;
        -c | --config | --config=* | -c?* | -U | --update-all | -i | --interactive | --follow | --stdin)
          refuse "flag '${a}' is not allowed" ;;
      esac
    done
    [[ "$has_pattern" == "true" ]] || refuse "a --pattern is required"
    check_args "${@:2}"
    # A trusted, empty root config: without -c, ast-grep loads sgconfig.yml from the
    # pull request, whose customLanguages entry loads a native library (code execution).
    [[ -n "${REVIEW_GUARD_SGCONFIG:-}" && -f "${REVIEW_GUARD_SGCONFIG}" ]] || refuse "the trusted ast-grep config is missing"
    run_real "${REVIEW_GUARD_REAL_AST_GREP:-}" run -c "$REVIEW_GUARD_SGCONFIG" "${@:2}"
    ;;
  *)
    refuse "unknown tool"
    ;;
esac
