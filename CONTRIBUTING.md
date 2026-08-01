# Contributing

## Prerequisites

```bash
brew install pre-commit terraform-docs
brew install terraform-linters/tap/tflint
pre-commit install
```

Local tool versions must match the pins in
[`.github/workflows/pre-commit.yml`](.github/workflows/pre-commit.yml). terraform-docs changed its
markdown table style after v0.20.0, so a mismatch makes CI reject README tables that were generated
correctly on your machine. When you bump one side, bump the other in the same pull request.

## Why this is its own repository

`temporalcloud_namespace_export_sink` is scoped to a single namespace, so by the ownership-by-key rule
this family uses it would fold into the namespace module — the way `namespace_tags` and
`namespace_search_attribute` do. It does not, for two reasons.

It carries configuration that belongs to a different system. A sink is mostly a description of cloud
storage and the IAM wiring that reaches it: a bucket, a region, an assumable role or an impersonated
service account, optionally a KMS key. That changes on the cadence of the storage account and its
security review, not on the cadence of retention days and search attributes. Folding it in would tie
every export change to a namespace module release and every namespace change to a review of the export
surface.

It also has prerequisites the namespace does not. A namespace is created from Temporal Cloud alone; a
sink cannot be created until a bucket and a role exist in another cloud account, provisioned by a
different configuration and often a different team. Keeping the module separate keeps that dependency
visible at the module boundary rather than buried in a variable.

Each repository in this family has its own tag stream, so this split also means an export change ships
without waiting on the namespace module, and vice versa.

## The gate

```bash
pre-commit run -a
```

This is what CI runs: `terraform fmt`, `terraform-docs`, `tflint`, `terraform validate`, plus two local
checks described below. Expect the first run after a change to *modify* files — terraform-docs rewrites
the README tables. Re-run until clean; it should pass twice in a row.

## Test layers

| Path | Runs on | Credentials | Proves |
| --- | --- | --- | --- |
| `examples/*` | every PR | no | The documented usage still type-checks against this code |
| `tests/local/` | every PR | no | Every input and output is still valid |
| `tests/*.tftest.hcl` | on demand, weekly | **yes** | Temporal Cloud accepts the payloads this module sends |

`terraform validate` is not a test: it never executes anything and never contacts the API. Only the
apply layer can catch the API rejecting a configuration that looks valid.

`terraform plan` is not a usable middle ground, because the provider authenticates when it initialises
and so needs a real key even for a plan that would create nothing.

**The apply layer is thin here, deliberately.** Creating a sink requires a bucket and an assumable role
or service account in a cloud account, which CI does not have, and Temporal Cloud validates the
destination during creation so there is no way to fake one.
[`tests/README.md`](tests/README.md) records exactly what a maintainer would need to provision and what
the test would look like. An honest documented gap is preferable to a test that is always red.

### Why `terraform validate` proves so little here

`terraform validate` does not run the provider's own validators when a value arrives through a module
input. `ConflictsWith`, `OneOf`, `ExactlyOneOf` and the custom set validators all defer until every
attribute they compare is *known*, and a module input is unknown during the validate walk. Verified
both directions: a bad literal written straight onto the resource errors at validate, the same value
behind a variable does not, and `count` is not the cause.

Module-level `variable ... validation` blocks are the exception — they run at validate regardless,
which is why the rules this module enforces itself do surface there.

The consequence for the layering above: `validate` is a lint over types and the variable surface, not
evidence that a configuration is complete or correct. Resource `precondition` blocks are likewise
plan-time only. Only applying proves behaviour, which is what `tests/*.tftest.hcl` is for.
### Why examples are validated indirectly

`examples/*` source the **published** module so consumers can copy them verbatim from the Terraform
Registry. Validating them as written would check the last release rather than the working tree, which
would mean a module change and its example update could never land in the same pull request.

[`scripts/validate-examples.sh`](scripts/validate-examples.sh) resolves this: it copies each example to
a temporary directory, rewrites the registry source to a path to the repository root, and validates the
copy. Tracked files are never modified. `terraform_validate` excludes `examples/`, and the
`examples-validate` hook covers them instead.

This module's copy of the script differs from its siblings' in one way: the rewrite is **anchored to
this module's registry name** rather than matching any `terraform-temporalcloud-modules/` address. The
examples also call the published namespace module, so the namespace ID is wired from its output instead
of typed by hand — the single most common mistake with this resource. That call must keep resolving
from the registry, so a blanket rewrite would point it at this module and break validation. Both the
regex and the guard that follows it carry the module name; update `MODULE_NAME` at the top of the
script if the repository is ever renamed.

One consequence: examples are validated only on the maximum supported Terraform version, because the
exclusion also removes them from the minimum-version matrix jobs. The root module and `tests/local/`
are still checked against the minimum, which is what `required_version` asserts.

A second consequence: validating the examples downloads the published namespace module. That needs
network access to the registry, which CI has.

### Why `wrappers/` is hand-maintained

The upstream `terraform_wrapper_module_for_each` pre-commit hook is not enabled. It hardcodes
`terraform-aws-modules` and `aws` in the source addresses it generates, and it overwrites
`wrappers/README.md` on every run with an Amazon S3 example whose inputs do not exist in this module.
It offers no way to skip that file, so restoring a correct one leaves the gate permanently dirty.

[`scripts/check-wrapper-sync.sh`](scripts/check-wrapper-sync.sh) replaces the one useful thing the hook
did: it fails if a root variable is not passed through `wrappers/main.tf`. When you add a variable to
the root module, add the matching line to the wrapper in the same change.

## Where the validation lives, and why

Most input checks are `validation` blocks on the variable they guard, each wrapped as
`try(<check>, true)` — the functions used inside raise on a null argument, so a null object or an
omitted optional attribute has to fall through rather than be guarded operand by operand. Verify a new
one against all four cases: variable null, attribute omitted, attribute valid, attribute invalid.

The exactly-one-destination rule cannot go there. It spans `s3` and `gcs`, and a `validation` block
could not reference another variable until Terraform 1.9 — above this module's `required_version` floor
of 1.5.7, which exists to keep consumers on older Terraform working. It is a `precondition` on the
resource in `main.tf` instead. That placement has a second benefit: preconditions on a `count`-gated
resource are skipped when the count is zero, so `create_namespace_export_sink = false` does not have to
satisfy it.

The provider enforces the same rule with an `ExactlyOneOf` validator, so the precondition is not the
only line of defence — it exists to fail with a message that names this module's variables.

## API behaviours worth knowing

These pass `terraform validate` and fail only later. They are what the apply layer would exist to
guard, and what to expect the first time a sink test runs.

1. **`namespace` is the fully qualified ID `<namespace>.<account_id>`**, not the namespace name. The
   module rejects a bare name during plan, because the API's own rejection does not say what the
   correct form is.
2. **The bucket must be in the same region as the namespace**, written in two different formats —
   `aws-us-east-1` for the namespace, `us-east-1` for the bucket. A GCS bucket must also be
   single-region.
3. **The destination has to be reachable, and Terraform cannot tell you whether it is.** Temporal
   documents pre-creating the IAM role for the Terraform path, and the only reachability check it
   offers — the Cloud UI's **Verify** button — has no provider equivalent; neither resource calls the
   `ValidateNamespaceExportSink` RPC. A trust policy that does not admit Temporal Cloud's export
   principals therefore shows up as a failed apply or as a sink that never delivers, and either way
   the fix is in AWS or GCP, not in Terraform.
4. **`sink_name` is immutable.** Changing it replaces the sink.

When writing assertions, note that outputs wrapped in `try(x, [])` evaluate to a *tuple*, so
`output.x == tolist([])` is false even against an empty result. Compare with `length()` and index
elementwise instead.

## Running the apply tests

```bash
export TEMPORAL_CLOUD_API_KEY="<key for a scratch account>"
terraform init
terraform test -verbose
```

Without a key every run block is skipped, which is a cheap way to check that the test files parse:

```text
Failure! 0 passed, 0 failed, 1 skipped.
```

In CI they run from the **Apply Tests** workflow. Its first step is
[`scripts/check-api.sh`](scripts/check-api.sh), a liveness check that confirms the API answers and the
key is accepted, so a credentials problem fails immediately rather than surfacing minutes later.

Apply Tests is chained after Pre-Commit, and Release after Apply Tests, so a merge to main runs:

```text
push to main -> Pre-Commit -> Apply Tests -> Release
```

A release is therefore only cut from code that passed both the static gate and the tests that apply
against a real account. Any failure in the chain stops it.

Apply Tests never runs on pull requests: forks cannot read secrets and, once a sink test exists, every
run costs money. It also runs weekly, and on demand. Runs are serialized with
`cancel-in-progress: false`, because cancelling mid-apply would abandon a real resource with no
destroy.

The workflow's final step, `scripts/check-orphans.sh`, is a **no-op in this module**: no data source
enumerates export sinks, so nothing can be read back to compare against. It is kept so the gap is
printed in the job log and so there is an obvious place to implement the check if such a data source
appears. [`tests/README.md`](tests/README.md) covers how to look for leftovers by hand.

## Pull requests

Titles must be [conventional commits](https://www.conventionalcommits.org/) — `feat:`, `fix:`, `docs:`,
`ci:`, `chore:` — with a capitalised subject. Squash-merge makes the title the commit message, and
semantic-release derives the next version from it, so an invalid title silently breaks versioning. A
workflow enforces this.

`CHANGELOG.md` and tags are generated on merge. Never bump versions by hand.

If CI reports fewer checks than usual, check whether the pull request has merge conflicts: GitHub skips
`pull_request` workflows when it cannot compute a merge ref, with no failed check to show for it.
