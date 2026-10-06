# Plumbing, not a lesson: sourced by the scripts in scripts/devops/ that work
# with Argo CD and the config repository in donhang-staging. The caller has
# already done `cd` to the repository's root.

# Every kubectl in these scripts talks to donhang-staging, whatever context
# is current: the scripts of the k8s track keep using the cluster donhang.
kubectl() { command kubectl --context kind-donhang-staging "$@"; }

# The working clone of the config repository, and the mirror clone that
# scripts/devops/dr-drill.sh keeps as the repository's backup. Both are
# gitignored: what they hold is the Git server's history, not this repo's.
config_repo=.gitops/donhang-config
config_mirror=.gitops/donhang-config.git
git_server=http://localhost:13000
repo_path=donhang/donhang-config.git

# Read .env without printing it: GITEA_ADMIN_PASSWORD and the values
# scripts/devops/seal-secrets.sh seals.
scripts/dev-secrets.sh >/dev/null
set -a
. ./.env
set +a

# The Git server listens only inside the cluster; a port-forward makes it
# reachable as localhost:13000 from here for as long as the script runs.
port_forward_pid=
git_server_open() {
  [ -n "$port_forward_pid" ] && return 0
  kubectl rollout status deployment/gitea -n git --timeout=300s >/dev/null
  # (command: the kubectl process itself in the background, so that kill
  # below stops it, not a shell around it.)
  command kubectl --context kind-donhang-staging port-forward -n git service/gitea 13000:3000 >/dev/null 2>&1 &
  port_forward_pid=$!
  trap git_server_close EXIT
  for _ in $(seq 60); do
    curl -fsS "$git_server/api/healthz" >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "the Git server did not answer on $git_server" >&2
  return 1
}
git_server_close() {
  [ -n "$port_forward_pid" ] && kill "$port_forward_pid" 2>/dev/null || true
  port_forward_pid=
}

# git with the admin's credentials in a header, never in a URL or a file.
git_auth() {
  local basic
  basic=$(printf '%s' "donhang:$GITEA_ADMIN_PASSWORD" | base64 | tr -d '\n')
  git -c http.extraHeader="Authorization: Basic $basic" "$@"
}

# config_commit <script name> <message>: commit what changed in the working
# clone, authored by the script that changed it, and push it to the server.
config_commit() {
  local who=$1 message=$2
  git -C "$config_repo" add -A
  git -C "$config_repo" -c user.name="$who" -c user.email=lab@donhang.example \
    commit -q -m "$message"
  git_server_open
  git_auth -C "$config_repo" push -q "$git_server/$repo_path" main
}

# The newest commit of the working clone, short and full.
config_head() { git -C "$config_repo" rev-parse "${1:---short}" HEAD; }

# Ask Argo CD to compare now instead of at its next interval.
app_refresh() {
  kubectl annotate application staging -n argocd argocd.argoproj.io/refresh=normal --overwrite >/dev/null
}

# app_wait <sync status> <health status> [revision] [seconds]: wait until
# staging shows both (at that commit, when given) and no sync is running;
# print them once it does.
app_wait() {
  local want_sync=$1 want_health=$2 revision=${3:-} seconds=${4:-600}
  local sync health rev phase
  for _ in $(seq "$seconds"); do
    read -r sync health rev phase < <(kubectl get application staging -n argocd \
      -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision} {.status.operationState.phase}{"\n"}')
    if [ "$sync" = "$want_sync" ] && [ "$health" = "$want_health" ] && [ "$phase" != Running ] \
       && { [ -z "$revision" ] || [ "$rev" = "$revision" ]; }; then
      echo "staging: $sync, $health"
      return 0
    fi
    sleep 1
  done
  echo "staging is still $sync, $health after $seconds s (wanted $want_sync, $want_health)" >&2
  return 1
}

# app_wait_sync <revision> [seconds]: wait until Argo CD has finished a sync
# of that commit (automated or not); print how it ended.
app_wait_sync() {
  local revision=$1 seconds=${2:-600} result
  for _ in $(seq "$seconds"); do
    result=$(kubectl get application staging -n argocd \
      -o jsonpath='{.status.operationState.syncResult.revision} {.status.operationState.phase}')
    case "$result" in
      "$revision Succeeded" | "$revision Failed" | "$revision Error")
        echo "sync of $(printf %.7s "$revision"): ${result#* }"
        return 0 ;;
    esac
    sleep 1
  done
  echo "no finished sync of $revision after $seconds s" >&2
  return 1
}
