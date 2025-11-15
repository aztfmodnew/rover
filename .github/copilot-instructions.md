# Azure CAF Rover – AI Guide

## Big Picture
- Rover couples a **versioned Docker toolchain** (`Dockerfile`, `docker-bake*.hcl`) with a **Terraform wrapper** (`scripts/rover.sh`) that orchestrates Azure CAF landing zones. Keep runtime logic in `scripts/**` and build logic in the Docker/bake files—never mix the layers.
- `scripts/rover.sh` is the single entry point: it sources helpers (`scripts/clone.sh`, `scripts/lib/*.sh`, `scripts/tfstate.sh`, etc.), exports defaults (`TF_VAR_environment`, `gitops_terraform_backend_type`, `TF_PLUGIN_CACHE_DIR`), then routes commands via `process_actions` in `scripts/functions.sh`. Any new action must hook into that flow rather than calling Terraform directly.
- State handling, backend selection, and Terraform invocation live in `scripts/tfstate.sh` + `scripts/lib/terraform.sh`. To add a backend or tweak init/plan/apply you must update those helpers and reuse `tfstate_configure` / `terraform_init_*` so logging and cleanup remain consistent.

## Key Directories & Patterns
- `scripts/lib/*` are concern-specific helpers (logger, bootstrap, init, parse_parameters, Azure AD, terraform, CI). Add new helpers here and source them from `scripts/rover.sh`—do not scatter ad‑hoc functions inside consumer scripts.
- `scripts/ci_tasks/**` contains YAML descriptors + runners consumed by `scripts/ci.sh`/`symphony_yaml.sh`. Symphony validation assumes every stack folder has `.tf` files and every config folder has `.tfvars`; update the validator if you change that contract.
- `tfcloud/*` and `remote.sh` encapsulate Terraform Cloud workflows. Keep credentials in `~/.terraform.d/credentials.tfrc.json` and pass organization/hostname through `TF_VAR_tf_cloud_*`.
- `spec/unit/**` holds ShellSpec suites that stub helper functions; when editing shared libs, mirror new behavior with specs (e.g., `spec/unit/logger/logger_spec.sh`).

## Critical Workflows
- **Build images**: use `make local` (or `make github/dev/ci/alpha`) which wraps `scripts/build_image.sh`. The script iterates over every Terraform version listed in `.env.terraform`, so bumping supported versions requires updating that file plus `docker-bake.override.hcl`/README.
- **Run rover locally**: start a container from the built image and execute `/tf/rover/rover.sh -lz <path> -a plan ...`. The wrapper expects `az login` (or managed identity) before it calls `verify_azure_session`; otherwise it fails fast.
- **Initialize launchpad**: `rover.sh -lz caf_launchpad -a init --clean` leverages `scripts/lib/init.sh` to create the storage account, container, and Key Vault tagged with `caf_environment`/`caf_tfstate`. Do not bypass these helpers as they also assign RBAC.
- **CI/CD & symphony**: `scripts/ci.sh` parses `symphony.yaml` via `yq`, validates every level/stack, and drives tasks defined under `scripts/ci_tasks`. When adding stacks, ensure `get_landingzone_path_for_stack` and `get_config_path_for_stack` resolve real folders so `validate_symphony` passes.
- **Terraform actions**: command parsing happens in `scripts/lib/parse_parameters.sh`; `purge_command` sanitizes plan/apply/destroy parameters. Always extend parsing there so automation (logs, plan files) stays aligned.

## Testing & Validation
- **Unit tests**: run `shellspec spec/unit` (or target a subfolder) to exercise logger/CI/task helpers with mocked functions. Add specs whenever you change shared libraries.
- **Docker regression**: run `scripts/build_image.sh local` followed by `docker run ... terraform version` to validate the image; the health check in `Dockerfile` already calls `terraform`, `az`, and `kubectl`.
- **Integration tests**: `scripts/test_runner.sh` downloads the relevant tfstate, runs Go tests tagged with the current level/stack, and emits JUnit via `go-junit-report`. Requires `az login`, `go`, and access to the storage account where tfstate resides.

## Contribution Tips
- Follow the sourcing order in `scripts/rover.sh`. If a new helper needs earlier initialization (e.g., logging), place the `source` statement before consumers to avoid undefined functions.
- Keep backend artifacts (`backend.azurerm.tf`, `backend.hcl.tf`, `caf.auto.tfvars`) under `scripts/`; wrapper code copies them into landing-zone folders at runtime. Never commit generated backend files inside landing-zone repos.
- Version bumps or new tooling must update both the Docker build stages and the docs (`README.md`, `VERSION_UPDATES_*.md`). Use `scripts/update_versions.sh` to regenerate the pinned versions table before opening a PR.
- Most functions rely on exported env vars rather than positional args; when introducing new inputs prefer `export VAR=${VAR:=default}` in `scripts/rover.sh` so CI, dev containers, and walkthroughs stay in sync.
