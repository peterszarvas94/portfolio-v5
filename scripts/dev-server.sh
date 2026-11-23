#!/usr/bin/env bash
# Start and stop the live-reload dev server (`mise run dev`) in the background, one per worktree.
#
# Usage (from the repo or any worktree; T3's project scripts set T3CODE_WORKTREE_PATH):
#   scripts/dev-server.sh start     start it if it is not running, wait until it answers, print the URL
#   scripts/dev-server.sh stop      stop it
#   scripts/dev-server.sh restart   stop, then start
#   scripts/dev-server.sh status    print the URL if it is running
#   scripts/dev-server.sh logs      follow its output
#
# It binds to all addresses (IPv4 and IPv6) so it is reachable across the tailnet. Each worktree
# gets the first free port from 8080 for the page and from 7332 for the file server behind it.
# The process ID, ports and log are kept in .dev/ in the worktree.
set -euo pipefail

die() { echo "dev-server: $*" >&2; exit 1; }

root="$(git -C "${T3CODE_WORKTREE_PATH:-$PWD}" rev-parse --show-toplevel 2>/dev/null)" ||
  die "not in a git worktree: ${T3CODE_WORKTREE_PATH:-$PWD}"
state="$root/.dev"
pidfile="$state/pid" envfile="$state/env" logfile="$state/log"

host="$(tailscale status --json 2>/dev/null | jq -r '.Self.HostName // empty' 2>/dev/null || true)"
host="${host:-$(hostname -s)}"

port_free() { [[ -z $(ss -Hltn "sport = :$1" 2>/dev/null) ]]; }
free_port() { # free_port <from> [<skip>]: the first free port from <from>, other than <skip>
  local p=$1
  while ! port_free "$p" || [[ $p == "${2:-}" ]]; do p=$((p + 1)); done
  echo "$p"
}

running() { [[ -f $pidfile ]] && kill -0 -- "-$(<"$pidfile")" 2>/dev/null; }
url() { . "$envfile"; echo "http://$host:$DEV_PORT/"; }

cmd_start() {
  if running; then
    echo "Already running: $(url)"
    return 0
  fi
  mkdir -p "$state"
  local port app_port
  port="$(free_port "${DEV_PORT:-8080}")"
  app_port="$(free_port 7332 "$port")"
  printf 'DEV_PORT=%s\nDEV_APP_PORT=%s\n' "$port" "$app_port" >"$envfile"

  # setsid makes the server the leader of its own process group, so stop can end templ,
  # `go run` and the built server together.
  (cd "$root" && DEV_PORT=$port DEV_APP_PORT=$app_port DEV_BIND='[::]' \
    setsid bash -c 'echo $$ >"$1"; exec mise run dev' _ "$pidfile" </dev/null >"$logfile" 2>&1 &)

  local u="http://$host:$port/"
  for _ in $(seq 120); do
    if curl -fsS -o /dev/null --max-time 2 "$u" 2>/dev/null; then
      echo "Running: $u"
      echo "Logs: $logfile"
      return 0
    fi
    running || { tail -n 30 "$logfile" >&2; die "the dev server exited; log above"; }
    sleep 0.5
  done
  tail -n 30 "$logfile" >&2
  die "no answer from $u after 60s; it is still running (scripts/dev-server.sh stop to end it)"
}

cmd_stop() {
  if ! running; then
    rm -f "$pidfile"
    echo "Not running."
    return 0
  fi
  local pgid
  pgid="$(<"$pidfile")"
  kill -TERM -- "-$pgid" 2>/dev/null || true
  for _ in $(seq 20); do
    kill -0 -- "-$pgid" 2>/dev/null || break
    sleep 0.25
  done
  kill -KILL -- "-$pgid" 2>/dev/null || true
  rm -f "$pidfile"
  echo "Stopped."
}

cmd_status() {
  if running; then echo "Running: $(url)"; else echo "Not running."; return 1; fi
}

case "${1:-}" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  restart) cmd_stop && cmd_start ;;
  status) cmd_status ;;
  logs) [[ -f $logfile ]] || die "no log yet"; exec tail -n 50 -f "$logfile" ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac
