# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-namespace-export-sink/compare/v1.0.0...v2.0.0) (2026-08-01)

### ⚠ BREAKING CHANGES

* namespace and sink_name no longer have defaults. A module call
that sets create_namespace_export_sink = false must now pass them explicitly.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>

### Features

* Require the inputs the provider requires ([1b08192](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-namespace-export-sink/commit/1b0819236e40487a4fd265e6038c431c76b1b6e1))

## 1.0.0 (2026-08-01)

### Features

* Initial namespace export sink module ([39098a8](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-namespace-export-sink/commit/39098a87631338efea57eb96dd8b2dcfe05a1b30))
