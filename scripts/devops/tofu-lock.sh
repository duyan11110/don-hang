#!/usr/bin/env bash
# Hold the lock on staging's platform state with an apply that waits for its answer, and see a plan fail at once, then wait for the lock with -lock-timeout.
# Runs on the host: OpenTofu keeps the state and its lock in Compose's PostgreSQL (after scripts/devops/tofu-environments.sh).
set -euo pipefail
cd "$(dirname "$0")/../.."

# Something for apply to ask about: a label added by hand, which apply would
# remove (devops.l3.configuration-drift explains). The answer is "no".
kubectl --context kind-donhang-staging label namespace donhang owner=by-hand --overwrite >/dev/null

# lesson: devops.l3.remote-state-and-locking
# Terminal 1: an apply that holds the lock while it waits for "yes"; here
# the answer, "no", comes 30 seconds after it starts.
echo "== terminal 1: tofu apply, waiting for an answer"
(sleep 30; echo no) | scripts/devops/tofu-env.sh staging platform apply -input=true -no-color >/dev/null 2>&1 &
apply=$!
sleep 15

# Terminal 2: a plan while the state is locked fails at once...
echo "== terminal 2: tofu plan"
scripts/devops/tofu-env.sh staging platform plan -no-color 2>&1 | grep -e '^Error' || true
echo

# ...unless it is told to wait for the lock.
echo "== terminal 2: tofu plan -lock-timeout=60s"
started=$SECONDS
scripts/devops/tofu-env.sh staging platform plan -lock-timeout=60s -no-color | grep -e '^No changes' -e '^Plan:'
echo "it waited about $(( SECONDS - started )) s, until terminal 1's apply ended"
wait "$apply" || true
kubectl --context kind-donhang-staging label namespace donhang owner- >/dev/null
