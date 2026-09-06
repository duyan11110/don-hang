#!/usr/bin/env bash
# Run the sample that throws from three calls deep and print the stack trace.
set -euo pipefail
cd "$(dirname "$0")/../.."

dotnet run --project samples/DonHang.Samples --verbosity quiet -- throws-deep
