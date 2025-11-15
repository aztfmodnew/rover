# Project Architecture Blueprint – rover

Generated: 2025-11-15 14:25:00 UTC

## 1. Architecture Detection and Analysis

- **Technology stack**: Multi-stage Docker build (`Dockerfile`, `Dockerfile.optimized`) producing a Ubuntu 24.04 toolchain image with Terraform, Azure CLI, kubectl, Ansible (ansible-core 2.20.0), Python, Go, PowerShell, and supporting CLIs. Runtime automation is implemented almost entirely in Bash (`scripts/**`) with selective use of jq, az CLI, curl, and Terraform CLI executed by the wrapper.
- **Detected frameworks & tooling**: ShellSpec (`spec/**`) for unit tests, BuildKit/`docker buildx bake` (`scripts/build_image.sh`, `docker-bake*.hcl`) for container assembly, Azure CLI/Graph REST for identity bootstrap (`scripts/lib/azure_ad.sh`), GitHub/Terraform Cloud integration helpers (`scripts/lib/bootstrap.sh`, `scripts/tfcloud/*.sh`), and Symphony YAML driven CI tasks (`scripts/ci.sh`, `scripts/ci_tasks/**`).
- **Architectural pattern**: A layered orchestration model that separates (1) containerized execution environment, (2) Terraform wrapper + orchestration services, (3) GitOps/CI integrations, and (4) developer experience workflows (walkthroughs, tests). Dependencies flow downward through environment variables and helper libraries while Terraform state/data propagates upward through well-defined functions in `tfstate.sh`.
- **Dependency flow observations**: `scripts/rover.sh` is the single entry point that sources all other modules, establishes environment defaults, and coordinates command routing. Build artifacts supply the runtime binary set but have no knowledge of specific landing zones; configuration flows from command-line flags (`parse_parameters.sh`) into locals, then down to Terraform invocations (`terraform.sh`). External services (Azure, GitHub, Terraform Cloud) are accessed through thin abstractions under `scripts/lib/*` or `scripts/tfcloud/*`.

## 2. Architectural Overview

- The solution deliberately splits responsibilities between an immutable **execution appliance** (the Docker image) and a highly stateful **Terraform orchestration wrapper**. Developers and pipelines always interact with the wrapper inside the container, ensuring identical tooling across environments.
- **Guiding principles** visible in the code base:
  - *Reproducibility*: exact tool versions are pinned in `docker-bake.override.hcl`, while `scripts/update_versions.sh` automates drift detection.
  - *Convention over configuration*: environment defaults (`scripts/rover.sh`) and standardized directory structures (`/tf/caf`, `/tf/rover`) minimize per-project setup.
  - *Operational safety*: logging (`scripts/lib/logger.sh`), retry helpers (`execute_with_backoff` in `scripts/functions.sh`), and health checks in the Dockerfile ensure failures are reported quickly.
  - *Enterprise landing-zone alignment*: TF state management (`scripts/tfstate.sh`) enforces level/workspace naming consistent with CAF best practices and supports Azure Storage + Terraform Cloud backends.
- **Architectural boundaries**: Docker artifacts never reach into user configurations; conversely, Terraform wrapper logic avoids embedding build knowledge. Libraries under `scripts/lib/*` are pure helpers with no direct CLI parsing, preserving clear dependency directions.
- **Hybrid adaptations**: The architecture blends classic layered scripting with GitOps patterns (CI tasks, secret registration) and guided onboarding flows (`scripts/walkthrough.sh`).

## 3. Architecture Visualization

````mermaid
flowchart LR
    subgraph Env[Containerized Execution Environment]
        Dockerfile-->Toolchain
        docker-bake.hcl-->BuildX
        BuildX-->DockerImage
    end
    subgraph Wrapper[Terraform Wrapper & Orchestration]
        Rover[r scripts/rover.sh]
        Libs[scripts/lib/*]
        TFState[scripts/tfstate.sh]
        TerraformOps[scripts/lib/terraform.sh]
    end
    subgraph Integrations[GitOps & CI]
        CI[scripts/ci.sh]
        Tasks[scripts/ci_tasks/**]
        Bootstrap[scripts/lib/bootstrap.sh]
        TFCloud[scripts/tfcloud/*.sh]
    end
    subgraph DX[Developer Experience]
        Walkthrough[scripts/walkthrough.sh]
        Tests[spec/**, test_dockerfile_improvements.sh]
    end

    DockerImage-->Rover
    Rover-->Libs
    Rover-->TFState
    Rover-->CI
    Rover-->Walkthrough
    Libs-->TerraformOps
    TFState-->TerraformOps
    CI-->Tasks
    Bootstrap-->Integrations
    Integrations-->TFCloud
````

*When diagrams are not available, treat the relationships above as a textual description of subsystem boundaries, dependencies, and data flow.*

## 4. Core Architectural Components

| Component | Purpose & Responsibility | Internal Structure & Patterns | Interaction & Evolution |
|-----------|--------------------------|-------------------------------|-------------------------|
| **Container Build System** (`Dockerfile`, `Dockerfile.optimized`, `docker-bake*.hcl`, `scripts/build_image.sh`) | Produce reproducible multi-arch toolchains with pinned versions and health checks. | Multi-stage Dockerfiles with stage-specific responsibilities (system packages, binary tools, Python tooling, user setup). Build orchestration handled by `docker buildx bake` via `scripts/build_image.sh`. | Consumed by developers/CI through `make local`/`make github`. Extend by adding stages or build args in `docker-bake.override.hcl`; automation script updates versions uniformly. |
| **Terraform Wrapper CLI** (`scripts/rover.sh` + sourced libs) | Parse commands, enforce CAF conventions, call Terraform consistently, manage logging. | Entry script sources helper modules, initializes env vars, and routes to `process_actions` (`scripts/functions.sh`). Parameter parsing is centralized in `scripts/lib/parse_parameters.sh`. | Communicates with Terraform CLI and Azure CLI. Extend by adding new actions in `process_actions` or new flags in parse scripts. |
| **State Management & Backend Abstraction** (`scripts/tfstate.sh`, `scripts/lib/terraform.sh`, backend templates) | Provision and access Terraform state in Azure Storage or Terraform Cloud, prepare backend files, execute init/plan/apply/destroy with consistent file layouts. | Explicit case handling for `azurerm` vs `remote` backends, auto-generated `backend.azurerm.tf`/`backend.hcl.tf`, workspace name derivation, log file wiring. | Called by wrapper before every Terraform command. Extend by implementing new backend handlers (e.g., S3) and updating `terraform_init` switch. |
| **GitOps / CI Integration** (`scripts/ci.sh`, `scripts/ci_tasks/**`, `scripts/lib/bootstrap.sh`, `scripts/lib/azure_ad.sh`) | Register secrets, set up agent pools, validate configurations, and execute CI tasks across levels defined in `symphony.yml`. | Uses a registry of CI tasks discovered at runtime, YAML-driven orchestration, Azure AD helpers for federated identities, and secret registration per pipeline type. | Interfaces with GitHub, Terraform Cloud, Azure AD. Extend by adding new pipeline providers or CI task definitions under `scripts/ci_tasks`. |
| **Developer Experience Tooling** (`scripts/walkthrough.sh`, `scripts/clone.sh`, docs/) | Onboard users through guided deployments, cloning needed repos/configurations, generating scripts. | Step-wise prompts with sanity checks, generation of `deploy.sh`/`destroy.sh` plus README, heavy reuse of clone helpers. | Interacts with Git, local FS, rover CLI. Extend by adding new walkthrough scenarios or enhancing automation prompts. |

## 5. Architectural Layers and Dependencies

1. **Environment Layer** – Docker images and build scripts ensure tool consistency. They expose binaries and pre-provisioned directories but do not depend on higher layers.
2. **Orchestration Layer** – `scripts/rover.sh` and supporting libraries perform command parsing, environment prep, and Terraform lifecycle management. Depends only on environment-provided tools.
3. **Integration Layer** – GitOps/CI, bootstrap, authentication modules that talk to Azure AD, Terraform Cloud, GitHub. Depend on orchestration for configuration and on environment for CLI tools.
4. **Experience Layer** – Walkthroughs, tests, documentation. Depend on orchestration APIs and integration services to model real workflows.

**Dependency rules**:
- Helper libraries never call the Docker build system; environment customizations flow through env vars instead.
- Terraform invocation helpers (`scripts/lib/terraform.sh`) receive fully processed parameters; they do not parse CLI arguments themselves.
- Integrations emit side effects (secret creation, agent pools) but cannot mutate orchestration logic; they work via exported functions.

No circular dependencies were detected; each script either sources helpers (one-way) or exposes functions consumed by the wrapper.

## 6. Data Architecture

- **Terraform State Artifacts**: Stored under `${TF_DATA_DIR}/tfstates/<level>/<workspace>/` inside the container and synchronized with remote backends via `tfstate.sh`. Backends supported: Azure Storage (SAS key retrieval via `az storage account keys list`) and Terraform Cloud (workspace auto-generation and `backend.hcl`).
- **Configuration Data**: Command-line inputs, config folders (`-var-folder`), Symphony YAML definitions, and landing-zone repositories are cloned beneath `/tf/caf`. Helper functions like `expand_tfvars_folder` consolidate `*.tfvars` into `caf.auto.tfvars` for remote workflows.
- **Logging and Diagnostics**: Structured logs in `~/.terraform.logs/<date>/` driven by `scripts/lib/logger.sh`, including Terraform raw logs (`TF_LOG_PATH`) and normalized text logs. Error handling writes status markers consumed by CI.
- **Secrets Management**: Azure AD credentials retrieved via az CLI, optionally persisted through GitOps secret registration. Encrypted storage is delegated to the underlying service (Azure Key Vault, GitHub secrets, Terraform Cloud workspace vars).
- **Caching**: Docker build caches stored at `/tmp/.buildx-cache`; Terraform plugin cache located under `/tf/cache` and `~/.terraform.cache` for CLI performance.

## 7. Cross-Cutting Concerns Implementation

| Concern | Implementation Highlights |
|---------|---------------------------|
| **Authentication & Authorization** | `scripts/lib/azure_ad.sh` retrieves the logged-in user object, provisions service principals, and assigns Azure AD roles using Microsoft Graph. Pipeline federated identities are created through `create_federated_identity` and `register_gitops_secret`. Terraform Cloud tokens and GitHub credentials are enforced via `assert_gitops_session`. |
| **Error Handling & Resilience** | `error()` in `scripts/functions.sh` centralizes exit handling, emits colored logs, cancels Terraform Cloud runs when needed, and cleans variables. `execute_with_backoff` retries transient commands with exponential backoff, protecting against Azure throttling. Docker build stages use `set -e` and explicit verification commands (e.g., `kubectl version`). |
| **Logging & Monitoring** | Logger initialization configures UTC timestamps, log severity mapping, TF log routing, and file rotation. Each major action prints contextual metadata (environment, level, workspace). Containers expose a health check (`terraform version && az version && kubectl version --client`). |
| **Validation** | Parameter parsing enforces required arguments; `verify_ci_parameters` ensures symphony configs exist. Backend selection guards unsupported types, and bootstrap scripts validate pipeline prerequisites before proceeding. |
| **Configuration Management** | Defaults centralized in `scripts/rover.sh` environment exports; overrides provided via CLI flags or env vars. Build-time configuration is isolated to `docker-bake.override.hcl`, while runtime config uses `.env.terraform` for supported Terraform versions. Secrets propagate through env vars or GitOps secret registries rather than hardcoded values. |

## 8. Service Communication Patterns

- **Azure APIs**: Azure CLI (`az`) is the primary client, invoking `az ad`, `az rest`, `az storage`, etc. Graph API requests rely on OIDC credentials and token exchange. Communication is synchronous with retry wrappers for throttling.
- **Terraform CLI**: Accessed locally but targets remote state; commands use `-chdir` to operate inside landing zone folders and utilize plan files stored in container-managed directories.
- **GitOps Providers**: GitHub secrets updated via REST (through helper scripts), Terraform Cloud via CLI/API wrappers under `scripts/tfcloud/*.sh`. Communication is synchronous; failure aborts the operation via shared `error()` handler.
- **Container Registry**: `docker buildx bake` pushes images to Docker Hub (`aztfmodnew/rover*`) or a temporary local registry for `make local`. Build caches transfer via local mounted directories.

## 9. Technology-Specific Architectural Patterns

#### .NET Architectural Patterns (not detected)
No .NET code paths exist in this repository; infrastructure is orchestrated entirely through Bash, Terraform, and CLI tooling.

#### Java Architectural Patterns (not detected)
There are no JVM components. Terraform interactions are command-line based, so Java-specific patterns do not apply.

#### React Architectural Patterns (not detected)
No front-end artifacts are present; UI interactions occur through CLI prompts (`walkthrough.sh`).

#### Angular Architectural Patterns (not detected)
N/A – the project does not ship SPA components.

#### Python Architectural Patterns (support tooling only)
Python 3.12 is bundled strictly for CLI dependencies (Azure CLI, ansible-core). There are no first-party Python modules in `scripts/`. Dependency installation is centralized in Dockerfile Stage 8 using `pip3 install --break-system-packages`. Packaging decisions prioritize entire-tool replacement over source-level reuse.

#### Bash/Shell Automation Patterns (observed)
- Source-order dependency injection: `scripts/rover.sh` sources clones/loggers/parsers before executing any logic, ensuring helpers are available globally.
- Namespaced helper libraries under `scripts/lib/*` avoid global functions collisions by grouping concerns (logger, terraform, bootstrap).
- Parameter parsing uses long-form flags, rehydrating values into global env vars consumed by subsequent modules.

## 10. Implementation Patterns

- **Interface Design**: Functions exposed by helper scripts follow narrow contracts (e.g., `terraform_plan`, `tfstate_configure`). Shared state is carried via exported env vars, acting as implicit interfaces between modules.
- **Service Implementation**: Internal services such as CI orchestration or bootstrap scripts treat Terraform actions as idempotent operations; they rely on explicit exit codes and logs to report success/failure.
- **Repository Pattern**: Terraform state repositories (Azure Storage containers or Terraform Cloud workspaces) are abstracted through `tfstate.sh`. The repository “interface” is the backend type; new implementations slot into the switch statement while reusing shared cleanup and workspace logic.
- **Controller/API Pattern**: `parse_command.sh` ensures Terraform commands executed by the wrapper omit incompatible flags (e.g., stripping `-var-file` for destroy with plan). This acts like an API adapter for Terraform CLI.
- **Domain Model**: Levels (`level0…level4`), environments, and workspaces form the domain vocabulary. They are modeled as env vars and directory hierarchies, ensuring state artifacts remain predictable.

## 11. Testing Architecture

- **ShellSpec Suites**: `spec/unit/**` contains ShellSpec-driven tests for logger, CI orchestration, and task helpers. `spec/spec_helper.sh` standardizes setup.
- **Docker Image Validation**: `scripts/test_dockerfile_improvements.sh` builds both original and optimized Dockerfiles, compares build time, size, and health checks.
- **CI Hooks**: `.pre-commit-config.yaml` (not shown above) enforces formatting, linting, and security scans before code merges.
- **Test doubles**: Where external services are required, tests rely on harness scripts under `spec/harness` to stub or mock CLI responses.

## 12. Deployment Architecture

- **Local Builds**: `make local` invokes `scripts/build_image.sh` with strategy `local`, starting an in-memory registry (`registry_rover_tmp`) so BuildKit can push/pull multi-arch manifests even without Docker Hub access.
- **Hosted Builds**: `make github` / `make dev` push images directly to Docker Hub namespaces (`aztfmodnew/rover`, `aztfmodnew/rover-preview`, etc.).
- **Runtime Usage**: The published image is intended to run interactively (VS Code dev containers, GitHub Codespaces) or in CI runners. Health checks ensure Terraform/Azure/Kubernetes CLIs remain functional inside orchestrators like Kubernetes or ACI.
- **Configuration Propagation**: `.env.terraform` enumerates supported Terraform versions; build scripts iterate through each version, tagging images accordingly.

## 13. Extension and Evolution Patterns

- **Feature Addition**:
  - Extend container tooling by editing `docker-bake.override.hcl` and Stage-specific logic, then update `scripts/update_versions.sh` so automated bumps remain consistent.
  - Add new rover actions by enhancing `process_actions` in `scripts/functions.sh` and providing corresponding helper scripts under `scripts/lib/`.
  - Integrate new CI tasks by placing YAML descriptors under `scripts/ci_tasks` and registering them via `register_ci_tasks`.
- **Modification Patterns**:
  - Maintain backward compatibility for CLI flags by adding new env vars with sensible defaults in `scripts/rover.sh` and referencing them via `try`/`:-` expansions.
  - When altering backend behavior, add new case arms inside `tfstate_configure` but preserve Azure/Terraform Cloud logic to avoid regressions.
- **Integration Patterns**:
  - Use adapter functions (e.g., `register_gitops_secret`) to talk to new GitOps providers while keeping the wrapper API stable.
  - Apply anti-corruption layers (ACLs) by isolating external REST calls inside dedicated helper scripts; avoid sprinkling `az rest` invocations throughout unrelated modules.

## 14. Architectural Pattern Examples

- **Layer Separation** (`scripts/rover.sh` sourcing order):

```bash
source ${script_path}/clone.sh
source ${script_path}/functions.sh
export TF_VAR_rover_version=$(get_rover_version)
source ${script_path}/banner.sh
...
source ${script_path}/tfstate.sh
source ${script_path}/walkthrough.sh
```
This demonstrates how the entry point wires dependencies before executing any logic, preventing circular references.

- **Backend Abstraction** (`scripts/tfstate.sh`):

```bash
case "${1}" in
    azurerm)
        cp -f ${script_path}/backend.azurerm.tf ${landingzone_name}/backend.azurerm.tf
        ;;
    remote)
        cp -f ${script_path}/backend.hcl.tf ${landingzone_name}/backend.hcl.tf
        export TF_VAR_workspace="${TF_VAR_environment}_${TF_VAR_level}_..."
        ;;
    *)
        error ${LINENO} "Error backend type not yet supported"
        ;;
esac
```
The switch cleanly separates backend-specific responsibilities and allows new implementations without touching Terraform callers.

- **Resilience Pattern** (`scripts/functions.sh`):

```bash
while [[ $attempt < $max_attempts ]]; do
    set +e
    "$@"
    exitCode=$?
    set -e
    ...
    sleep $timeout
    timeout=$((timeout * 2))
done
```
`execute_with_backoff` wraps any command to absorb transient Azure throttling, illustrating reusable resilience logic.

## 15. Architectural Decision Records

| Decision | Context & Rationale | Consequences |
|----------|---------------------|--------------|
| **Container-first delivery** | Ensures every engineer and pipeline shares identical Terraform/Azure toolchains regardless of host OS. | Requires ongoing maintenance of Dockerfiles and build cache management but dramatically reduces “works on my machine” drift. |
| **Azure Storage + Terraform Cloud backends** | Enterprise landing zones often span multiple subscriptions; dual backend support lets teams adopt either storage model without code changes. | Additional complexity in `tfstate.sh`, but provides gradual migration path and hybrid deployments. |
| **Centralized logging & severity mapping** | Needed actionable telemetry for both interactive and automated runs. | Slight overhead in log rotation and color stripping, but simplifies troubleshooting. |
| **Symphony YAML-driven CI tasks** | Aligns landing zone validation with configuration hierarchy. | Requires maintainer discipline to keep YAML definitions current; however, it decouples CI pipelines from hardcoded scripts. |

## 16. Architecture Governance

- **Automation Hooks**: `.pre-commit-config.yaml` runs formatting/lint/security scans, ensuring scripts remain compliant before merge.
- **Testing Gates**: ShellSpec suites and docker comparison tests provide fast regression checks; GitHub Actions status badges in `README.md` track branch health.
- **Documentation Practices**: DOCKERFILE_IMPROVEMENTS.md and DOCKERFILE_QUICK_REFERENCE.md capture build decisions, while version bump reports (e.g., `VERSION_UPDATES_2025-11-15.md`) document dependency updates.
- **Review Process**: PR workflow (referenced badges) enforces CI runs; architecture documentation (this blueprint) should be regenerated when major subsystems change.

## 17. Blueprint for New Development

- **Development Workflow**:
  1. Build/update the rover image locally via `make local` to ensure tooling matches expectations.
  2. Implement changes inside `scripts/**` or Dockerfiles, keeping helper libraries cohesive.
  3. Run ShellSpec suites (`shellspec`) and `scripts/test_dockerfile_improvements.sh --full` to validate both orchestration and container aspects.
  4. Update documentation (README, DOCKERFILE_* guides, version reports) and regenerate this blueprint if architectural boundaries shift.

- **Implementation Templates**:
  - New helper modules should live under `scripts/lib/<concern>.sh`, exposing functions that consume env vars rather than positional args.
  - CLI flags belong in `scripts/lib/parse_parameters.sh`; derive env defaults in `scripts/rover.sh` with sensible fallbacks.
  - CI tasks should include a YAML descriptor, a shell runner, and validation hooks referencing Symphony-level metadata.

- **Common Pitfalls**:
  - Mixing build-time and runtime concerns (e.g., referencing host paths inside scripts) breaks container portability.
  - Modifying Terraform commands outside the helper functions can bypass logging and error handling.
  - Forgetting to update `docker-bake.override.hcl` and README when bumping tool versions leads to documentation drift.
  - Running without `az login` or proper federated credentials will cause bootstrap failures; ensure authentication flows are followed.

*Keep this blueprint under version control and re-run the architecture analysis whenever significant subsystems are added or restructured to ensure ongoing alignment.*
