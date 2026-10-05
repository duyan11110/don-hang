#!/usr/bin/env bash
# Run the event sourcing sample: one order's stream, replay, two writers, two projections and a snapshot.
# Runs on the host: it needs dotnet, like scripts/debug/run-throws-deep.sh.
set -euo pipefail
cd "$(dirname "$0")/../.."

dotnet run --project samples/DonHang.Samples --verbosity quiet -- event-sourcing
