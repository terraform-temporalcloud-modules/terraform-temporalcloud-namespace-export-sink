#!/usr/bin/env bash
#
# Orphan check for export sinks — a deliberate no-op.
#
# In the sibling modules this script reads a data source, lists anything the test
# suite left behind and fails the job. There is no equivalent here: the provider
# ships no data source that enumerates namespace export sinks, and a sink has no
# account-wide listing endpoint. Nothing can be read back to compare against.
#
# It is kept, and still wired into the Apply Tests workflow, so that the shape
# matches the other modules and so the gap is reported in the job log rather than
# being invisible. If a `temporalcloud_namespace_export_sinks` data source is ever
# added, implement it here and in tests/orphan-check/ the way the namespace module
# does. Faking a check that cannot see anything would be worse than none.
#
# tests/README.md records how to look for leftovers by hand.

set -euo pipefail

cat <<'EOF'
Orphan check skipped: export sinks cannot be enumerated.

The temporalcloud provider offers no data source listing namespace export sinks,
so there is no way to discover one left behind by an interrupted run.

A sink belongs to a namespace, so destroying the namespace removes it. To check by
hand, open the namespace in the Temporal Cloud UI and look at its Export
configuration, or run:

  tcld namespace export s3 describe --namespace <namespace>.<account_id>
  tcld namespace export gcs describe --namespace <namespace>.<account_id>
EOF
