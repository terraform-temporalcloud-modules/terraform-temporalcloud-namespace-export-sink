// Verifies create_namespace_export_sink = false against a real provider.
//
// This is the only apply test in this module. Creating a sink needs an S3 or GCS
// bucket and an IAM role or service account that Temporal Cloud can assume, none
// of which exist on the test account — tests/README.md records that gap and what
// provisioning it would take. Rather than leave a permanently failing test, the
// applied coverage stops here.
//
// Creates no resources, so it is cheap. It still configures the provider, which
// is why it needs TEMPORAL_CLOUD_API_KEY.

provider "temporalcloud" {}

run "creates_nothing" {
  variables {
    create_namespace_export_sink = false
  }

  // "Creates nothing" is the claim this file makes, so check it directly
  // rather than inferring it from the output fallbacks below.
  assert {
    condition     = length(temporalcloud_namespace_export_sink.this) == 0
    error_message = "create_namespace_export_sink = false must declare no resource"
  }

  // Every output is count-gated behind try(); these assertions prove the
  // fallbacks evaluate rather than erroring when the module is switched off.
  assert {
    condition     = output.namespace_export_sink_id == ""
    error_message = "namespace_export_sink_id should fall back to empty when create_namespace_export_sink = false"
  }

  assert {
    condition     = output.namespace_export_sink_name == ""
    error_message = "namespace_export_sink_name should fall back to empty when create_namespace_export_sink = false"
  }

  assert {
    condition     = output.namespace_export_sink_namespace == ""
    error_message = "namespace_export_sink_namespace should fall back to empty when create_namespace_export_sink = false"
  }

  assert {
    condition     = output.namespace_export_sink_enabled == false
    error_message = "namespace_export_sink_enabled should fall back to false when create_namespace_export_sink = false"
  }

  assert {
    condition     = output.namespace_export_sink_s3 == null
    error_message = "namespace_export_sink_s3 should fall back to null when create_namespace_export_sink = false"
  }

  assert {
    condition     = output.namespace_export_sink_gcs == null
    error_message = "namespace_export_sink_gcs should fall back to null when create_namespace_export_sink = false"
  }
}
