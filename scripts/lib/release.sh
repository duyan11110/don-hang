# Plumbing, not a lesson: sourced by the scripts of devops/platform-and-release-strategy
# and devops/incidents that release the api on donhang-staging
# (blue-green.sh, canary.sh, canary-steps.sh, incident-drill.sh). The caller
# has already done `cd` to the repository's root.
source scripts/lib/gitops.sh
source scripts/lib/gateway.sh
export MSYS_NO_PATHCONV=1

routes=platform/edge/httproutes.yaml

# config_push: push the working clone; if another commit reached the
# server first (another lab script), rebase onto it and push again.
config_push() {
  git_server_open
  git_auth -C "$config_repo" push -q "$git_server/$repo_path" main 2>/dev/null && return 0
  git_auth -C "$config_repo" pull -q --rebase "$git_server/$repo_path" main
  git_auth -C "$config_repo" push -q "$git_server/$repo_path" main
}
# config_commit <script name> <message>: as in gitops.sh, but only the
# folders these scripts change, and pushed with config_push.
config_commit() {
  git -C "$config_repo" add -A -- envs base platform/edge platform/monitoring apps/monitoring-staging.yaml
  git -C "$config_repo" -c user.name="$1" -c user.email=lab@donhang.example commit -q -m "$2"
  config_push
}
# config_revert <script name> <commit>: git revert that commit, and push.
config_revert() {
  git -C "$config_repo" -c user.name="$1" -c user.email=lab@donhang.example revert --no-edit "$2" >/dev/null
  config_push
}

# release_setup: the working clone at the Git server's newest commit, in
# the Kustomize layout, with this repository's policies (which name
# api-canary and api-green) and routes; staging and its routes synced.
release_setup() {
  [ -d "$config_repo/.git" ] || scripts/devops/gitops-repo.sh >/dev/null
  git_server_open
  git_auth -C "$config_repo" pull -q --rebase --autostash "$git_server/$repo_path" main
  if [ ! -f "$config_repo/envs/staging/kustomization.yaml" ]; then
    echo "the config repository is not in the Kustomize layout yet: run scripts/k8s/kustomize-config-repo.sh first" >&2
    exit 1
  fi
  cp "$layout/base/network-policies.yaml" "$layout/base/egress-policies.yaml" "$config_repo/base/"
  cp "deploy/gitops/config-repo/$routes" "$config_repo/$routes"
  # Nothing left from an earlier run that stopped half-way: no api-green,
  # no api-canary, no patch of incident-drill.sh.
  overlay_remove api-green.yaml
  overlay_remove api-canary.yaml
  perl -0pi -e 's/# Product reads: one at a time, none waiting\.\npatches:\n(?:  .*\n)*//' \
    "$config_repo/envs/staging/kustomization.yaml"
  if [ -n "$(git -C "$config_repo" status --porcelain -- envs base platform/edge)" ]; then
    config_commit "$(basename "$0")" "Staging's api, policies and routes as Đơn Hàng's repository has them" >/dev/null
  fi
  sync_app staging
  sync_app edge-staging
  # The commits of this run come after this one (run_log shows them).
  run_start=$(config_head --verify)
}

# run_log <script name>: the commits that script made in this run.
run_log() {
  git -C "$config_repo" log --format='%h %an: %s' --author="$1" "$run_start..HEAD"
}

# sync_app <Application>: ask Argo CD to compare now, wait until it has
# compared the newest commit, found the cluster in sync and healthy. (A
# commit outside the Application's folder starts no sync of its own.)
# Other scripts may push to the same repository meanwhile (a lab run of the
# k8s track), so any newer commit that contains ours will do.
sync_app() {
  local saved=$app mine sync health rev phase
  app=$1
  mine=$(config_head --verify)
  app_refresh
  for _ in $(seq 600); do
    read -r sync health rev phase < <(kubectl get application "$app" -n argocd \
      -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision} {.status.operationState.phase}{"\n"}')
    if [ "$sync" = Synced ] && [ "$health" = Healthy ] && [ "$phase" != Running ] && [ -n "$rev" ]; then
      git -C "$config_repo" cat-file -e "$rev^{commit}" 2>/dev/null \
        || git_auth -C "$config_repo" fetch -q "$git_server/$repo_path" main
      git -C "$config_repo" merge-base --is-ancestor "$mine" "$rev" 2>/dev/null && { app=$saved; return 0; }
    fi
    sleep 1
  done
  echo "$app has not synced $mine after 600 s ($sync, $health)" >&2
  app=$saved
  return 1
}

# monitoring_up: staging's Prometheus (platform/monitoring and its
# Application), then wait until it scrapes every api Pod.
monitoring_up() {
  mkdir -p "$config_repo/platform"
  rm -rf "$config_repo/platform/monitoring"
  cp -R deploy/gitops/config-repo/platform/monitoring "$config_repo/platform/monitoring"
  # The rule tests are for promtool in CI, not for the cluster.
  rm -f "$config_repo/platform/monitoring/rules/slo.test.yml"
  cp deploy/gitops/config-repo/apps/monitoring-staging.yaml "$config_repo/apps/"
  if [ -n "$(git -C "$config_repo" status --porcelain -- platform/monitoring apps/monitoring-staging.yaml)" ]; then
    config_commit "$(basename "$0")" "Prometheus on staging (platform/monitoring)" >/dev/null
  fi
  kubectl apply -f "$config_repo/apps/monitoring-staging.yaml" >/dev/null
  sync_app monitoring-staging
  kubectl rollout status deployment/prometheus -n monitoring --timeout=300s >/dev/null
  wait_targets api "$(kubectl get pods -n donhang -l app=api --no-headers | wc -l)"
}

# promql <expression>: the result of an instant query, one line per series
# ("{labels} => value"), asked inside the Prometheus Pod with promtool.
promql() {
  kubectl exec -n monitoring deployment/prometheus -c prometheus -- \
    promtool query instant http://localhost:9090 "$1" 2>/dev/null | sed -E 's/ @\[[0-9.]+\]$//'
}
# promql_value <expression>: the value of a query that returns one series
# (0 when it returns none).
promql_value() {
  local value
  value=$(promql "$1" | sed -nE 's/^.* => (.*)$/\1/p' | head -n 1)
  echo "${value:-0}"
}

# wait_targets <app> <count>: wait until Prometheus scrapes that many Pods
# of that Deployment successfully.
wait_targets() {
  for _ in $(seq 120); do
    [ "$(promql_value "count(up{job=\"api\", app=\"$1\"} == 1)")" = "$2" ] && return 0
    sleep 2
  done
  echo "Prometheus does not scrape $2 Pods of $1" >&2
  return 1
}

# overlay_add <file> / overlay_remove <name>: put a manifest of
# deploy/gitops/lessons/ into envs/staging and its kustomization.yaml, or
# take it out again.
overlay_add() {
  local name
  name=$(basename "$1")
  cp "$1" "$config_repo/envs/staging/$name"
  grep -q "^  - $name\$" "$config_repo/envs/staging/kustomization.yaml" \
    || perl -0pi -e "s/(resources:\n(?:  - [^\n]*\n)*)/\$1  - $name\n/" "$config_repo/envs/staging/kustomization.yaml"
}
overlay_remove() {
  rm -f "$config_repo/envs/staging/$1"
  perl -ni -e "print unless /^  - \Q$1\E\$/" "$config_repo/envs/staging/kustomization.yaml"
}

# set_backends <service> <weight> [<service> <weight>]...: the backendRefs
# of the HTTPRoute api's first rule (/api/v1, /api/v2, /openapi). One
# service without a weight: "set_backends api-green".
set_backends() {
  local refs=""
  while [ $# -gt 0 ]; do
    refs+="        - name: $1"$'\n'"          port: 8080"$'\n'
    [ -n "${2:-}" ] && refs+="          weight: $2"$'\n'
    shift 2 || shift
  done
  REFS="$refs" perl -0pi -e 's/(      backendRefs:\n)(?:        - name: api[a-z-]*\n          port: 8080\n(?:          weight: \d+\n)?)+/$1$ENV{REFS}/' \
    "$config_repo/$routes"
}

# route_backends: the HTTPRoute api's first rule as the cluster has it.
route_backends() {
  kubectl get httproute api -n donhang \
    -o jsonpath='{range .spec.rules[0].backendRefs[*]}{.name} weight {.weight}, {end}' \
    | sed -E 's/ weight ,/,/g; s/, $//'
  echo
}

# read_products <count> [parallel]: send that many product reads through
# the Gateway, some at once; print one HTTP status code per request.
read_products() {
  local count=$1 parallel=${2:-20}
  for _ in $(seq "$count"); do echo "url = \"$gateway/api/v1/products?limit=20\""; done \
    | curl -s --parallel --parallel-max "$parallel" -w '%{stderr}%{http_code}\n' -K - 2>&1 >/dev/null
}

# requests_by <labels>: product reads counted so far by Prometheus, summed by
# those labels ("app" or "app, code"), as "<label values> <count>" lines.
requests_by() {
  promql "sum by ($1) (http_requests_received_total{method=\"GET\", endpoint=\"api/v1/products\"})" \
    | sed -E 's/^\{([^}]*)\} => (.*)$/\1 \2/; s/[a-z]+="([^"]*)"/\1/g; s/, / /g'
}

# wait_route <backends>: wait until the HTTPRoute api in the cluster names
# those backends, as route_backends prints them ("api weight 90, ...").
wait_route() {
  for _ in $(seq 120); do
    [ "$(route_backends)" = "$1" ] && return 0
    sleep 1
  done
  echo "the route api is still $(route_backends), not $1" >&2
  return 1
}
