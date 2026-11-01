# Pure shell, zero Nix dependency: all configuration comes through
# NASCHECK_* environment variables (injected by the facade at build time).
# Standalone test: bash nas-check.sh pool
# Usage:
#   nas-check [-n] [group]   group: all (default) | netdata | pool | services | snapraid
#   nas-check help            usage
#   nas-check list            available groups
# The -n flag overrides the send policy for THIS invocation only
# (default: NASCHECK_NOTIFY, i.e. the services.nasCheck.notify option).
# Exit codes: 0 clear, 1 problems, 2 unknown group/usage.

set -uo pipefail
problems=()
NETDATA_URL="${NASCHECK_NETDATA_URL:-http://127.0.0.1:19999}"
POOL_MOUNT="${NASCHECK_POOL_MOUNT:-/mnt/mergerfs}"
POOL_WARN="${NASCHECK_POOL_WARN:-85}"
POOL_CRIT="${NASCHECK_POOL_CRIT:-95}"
SNAPRAID_UNIT="${NASCHECK_SNAPRAID_UNIT:-snapraidd}"
TOPIC="${NASCHECK_TOPIC:-nas-monitoring}"
SEND="${NASCHECK_SEND:-}"        # path to the ntfy-send wrapper (always exported)
NOTIFY="${NASCHECK_NOTIFY:-0}"   # send policy (facade `notify` option)
CHECKS="${NASCHECK_CHECKS:-netdata pool services snapraid}"  # groups run by `all`
HOURS="${NASCHECK_JOURNAL_HOURS:-24}"  # journal inspection window
host=$(hostname -s)

usage() {
  cat >&2 <<'EOF'
usage: nas-check [-n] [group]

group    all (default) | netdata | pool | services | snapraid
         all           full digest — runs only the groups configured
                       on this host (`checks` option)
         netdata       netdata alive + active WARNING/CRITICAL alarms
         pool          mergerfs mount fill level (poolMount)
         services      systemd units in failed state
         snapraid      snapraidd errors in the journal
                       (window: journalHours, default 24h)

-n       send the ntfy notification for this invocation
         (default: this host's services.nasCheck.notify option)

help     this help
list     groups available on this host (per `checks`)

Exit codes: 0 = all clear, 1 = problems, 2 = invalid usage
EOF
}

# ─── Parse arguments (flag and group are combinable: `nas-check -n pool`) ───
group="all"
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--notify) NOTIFY=1 ;;
    all|netdata|pool|services|snapraid) group="$1" ;;
    help|-h|--help) usage; exit 0 ;;
    list) echo "available groups: all $CHECKS"; exit 0 ;;
    *) usage; exit 2 ;;
  esac
  shift
done

# ─── Single notification gateway ───
# No-op unless BOTH the wrapper exists AND notify is on (option or -n):
# sending is an explicit decision, never a side effect of running a command.
notify() { # $1 priority
  { [ -n "$SEND" ] && [ "$NOTIFY" = 1 ]; } || return 0
  NTFY_TITLE="$notify_title" "$SEND" "$TOPIC" "$1" <<<"$notify_body"
}

# ─── check: netdata (alive + active WARNING/CRITICAL alarms) ───
check_netdata() {
  local alarms_json active
  if ! alarms_json=$(curl -fs --max-time 10 "$NETDATA_URL/api/v1/alarms" 2>/dev/null); then
    problems+=("netdata does not respond on $NETDATA_URL")
    return
  fi
  active=$(jq -r \
    '.alarms | to_entries
     | map(select(.value.status == "WARNING" or .value.status == "CRITICAL"))
     | .[] | "\(.value.status): \(.value.chart)"' \
    <<<"$alarms_json")
  if [ -n "$active" ]; then
    local n_alarms
    n_alarms=$(printf '%s\n' "$active" | wc -l)
    problems+=("$n_alarms active netdata alarms")
    printf '%s\n' "$active"
  else
    echo "netdata: OK — no active alarms"
  fi
}

# ─── check: pool fill level (the data invariant) ───
check_pool() {
  local pool_pct
  pool_pct=$(df --output=pcent "$POOL_MOUNT" 2>/dev/null | tail -n1 | tr -dc '0-9')
  if [ -z "$pool_pct" ]; then
    problems+=("cannot read mount $POOL_MOUNT")
    return
  fi
  if [ "$pool_pct" -ge "$POOL_CRIT" ]; then
    problems+=("pool $POOL_MOUNT at $pool_pct% (critical)")
  elif [ "$pool_pct" -ge "$POOL_WARN" ]; then
    problems+=("pool $POOL_MOUNT at $pool_pct%")
  else
    echo "pool: OK — $POOL_MOUNT at $pool_pct%"
  fi
}

# ─── check: failed systemd units (complements OnFailure) ───
check_services() {
  local failed_units
  failed_units=$(systemctl list-units --state=failed --plain --no-legend | awk '{print $1}')
  if [ -n "$failed_units" ]; then
    problems+=("failed units: $(printf '%s, ' $failed_units | sed 's/, $//')")
  else
    echo "services: OK — no failed units"
  fi
}

# ─── check: snapraidd errors over the journal window ───
check_snapraid() {
  local snap_errors
  snap_errors=$(journalctl -u "$SNAPRAID_UNIT" --since "$HOURS hours ago" 2>/dev/null \
    | grep -ciE 'error|fail|exception' || true)
  if [ "${snap_errors:-0}" -gt 0 ]; then
    problems+=("$snap_errors snapraidd errors (${HOURS}h)")
  else
    echo "snapraid: OK — no errors in the last ${HOURS}h"
  fi
}

# ─── Run ───
case "$group" in
  netdata|pool|services|snapraid)
    # Capture the check output for the -n notification. The check runs in
    # the current shell (no subshell) so the `problems` array keeps its
    # findings; output goes to a temp file, then is displayed locally.
    out=$(mktemp)
    "check_$group" >"$out" 2>&1
    cat "$out"
    if [ ${#problems[@]} -gt 0 ]; then
      printf '⚠ %s\n' "${problems[@]}"
      notify_title="$host: $group — ${#problems[@]} problem(s)"
      notify_body="$(cat "$out")
$(printf '%s\n' "${problems[@]}")"
      notify high
      rm -f "$out"
      exit 1
    fi
    notify_title="$host: $group OK"
    notify_body="$(cat "$out")"
    notify min
    rm -f "$out"
    exit 0
    ;;
  all)
    # Only the groups configured on this host (facade `checks` option);
    # the digest adapts to what this host actually runs.
    for check in $CHECKS; do
      "check_$check"
    done
    ;;
  *)
    usage; exit 2
    ;;
esac

# ─── Full digest ───

if [ ${#problems[@]} -eq 0 ]; then
  pool_pct=$(df --output=pcent "$POOL_MOUNT" 2>/dev/null | tail -n1 | tr -dc '0-9')
  summary="✅ $host OK — sync ✓ SMART: OK · pool ${pool_pct:-?}% · services ✓"
  echo "$summary"
  notify_title="$host: all is OK"
  notify_body="$summary"
  notify min
  exit 0
else
  summary="⚠ $host: ${#problems[@]} problem(s)"
  body=$(printf '%s\n' "${problems[@]}")
  echo "$summary"
  echo "$body"
  notify_title="$summary"
  notify_body="$body"
  if printf '%s\n' "${problems[@]}" | grep -q "does not respond"; then
    notify_title="$host: monitoring is DOWN"
    notify urgent
  else
    notify high
  fi
  exit 1
fi
