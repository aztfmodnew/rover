#!/usr/bin/env bash
#
# update_versions.sh - Automatic Version Updater for Rover
# 
# This script checks the latest versions of all tools and updates:
# 1. docker-bake.override.hcl (version variables)
# 2. README.md (version table)
#
# Usage: ./update_versions.sh [--dry-run] [--auto-commit]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_BAKE_FILE="${SCRIPT_DIR}/docker-bake.override.hcl"
README_FILE="${SCRIPT_DIR}/README.md"

# Flags
DRY_RUN=false
AUTO_COMMIT=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --auto-commit)
            AUTO_COMMIT=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--auto-commit]"
            echo ""
            echo "Options:"
            echo "  --dry-run       Show what would be changed without modifying files"
            echo "  --auto-commit   Automatically commit changes to git"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
    esac
done

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get latest GitHub release version
get_github_version() {
    local repo=$1
    local version
    version=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | grep -oP '"tag_name": "\K(.*)(?=")' | head -1)
    
    if [ -z "$version" ]; then
        print_warning "Could not fetch version for ${repo}"
        return 1
    fi
    
    # Remove 'v' prefix if present
    version="${version#v}"
    echo "$version"
}

# Function to get latest PyPI package version
get_pypi_version() {
    local package=$1
    local version
    version=$(curl -s "https://pypi.org/pypi/${package}/json" | python3 -c "import sys, json; print(json.load(sys.stdin)['info']['version'])" 2>/dev/null)
    
    if [ -z "$version" ]; then
        print_warning "Could not fetch version for ${package}"
        return 1
    fi
    
    echo "$version"
}

# Function to get latest Go version
get_go_version() {
    local version
    version=$(curl -s "https://go.dev/VERSION?m=text" | head -1 | sed 's/go//')
    
    if [ -z "$version" ]; then
        print_warning "Could not fetch Go version"
        return 1
    fi
    
    echo "$version"
}

# Function to get current version from docker-bake.override.hcl
get_current_version() {
    local var_name=$1
    grep "^${var_name}=" "$DOCKER_BAKE_FILE" | sed 's/.*="\(.*\)"/\1/'
}

# Declare associative arrays for versions
declare -A CURRENT_VERSIONS
declare -A NEW_VERSIONS
declare -A UPDATED_TOOLS

print_info "Starting version check..."
echo ""

# Check all tool versions
print_info "Fetching latest versions from official sources..."

# Kubernetes/kubectl
print_info "Checking kubectl..."
CURRENT_VERSIONS[kubectl]=$(get_current_version "versionKubectl")
NEW_VERSIONS[kubectl]=$(get_github_version "kubernetes/kubernetes")
echo "  Current: ${CURRENT_VERSIONS[kubectl]} → Latest: ${NEW_VERSIONS[kubectl]}"

# Docker Compose
print_info "Checking docker-compose..."
CURRENT_VERSIONS[docker_compose]=$(get_current_version "versionDockerCompose")
NEW_VERSIONS[docker_compose]=$(get_github_version "docker/compose")
echo "  Current: ${CURRENT_VERSIONS[docker_compose]} → Latest: ${NEW_VERSIONS[docker_compose]}"

# Terraform
print_info "Checking Terraform..."
NEW_VERSIONS[terraform]=$(get_github_version "hashicorp/terraform")
echo "  Latest: ${NEW_VERSIONS[terraform]}"

# Packer
print_info "Checking Packer..."
CURRENT_VERSIONS[packer]=$(get_current_version "versionPacker")
NEW_VERSIONS[packer]=$(get_github_version "hashicorp/packer")
echo "  Current: ${CURRENT_VERSIONS[packer]} → Latest: ${NEW_VERSIONS[packer]}"

# Vault
print_info "Checking Vault..."
CURRENT_VERSIONS[vault]=$(get_current_version "versionVault")
NEW_VERSIONS[vault]=$(get_github_version "hashicorp/vault")
echo "  Current: ${CURRENT_VERSIONS[vault]} → Latest: ${NEW_VERSIONS[vault]}"

# Go
print_info "Checking Go..."
CURRENT_VERSIONS[golang]=$(get_current_version "versionGolang")
NEW_VERSIONS[golang]=$(get_go_version)
echo "  Current: ${CURRENT_VERSIONS[golang]} → Latest: ${NEW_VERSIONS[golang]}"

# PowerShell
print_info "Checking PowerShell..."
CURRENT_VERSIONS[powershell]=$(get_current_version "versionPowershell")
NEW_VERSIONS[powershell]=$(get_github_version "PowerShell/PowerShell")
echo "  Current: ${CURRENT_VERSIONS[powershell]} → Latest: ${NEW_VERSIONS[powershell]}"

# tflint
print_info "Checking tflint..."
NEW_VERSIONS[tflint]=$(get_github_version "terraform-linters/tflint")
echo "  Latest: ${NEW_VERSIONS[tflint]}"

# tfsec
print_info "Checking tfsec..."
NEW_VERSIONS[tfsec]=$(get_github_version "aquasecurity/tfsec")
echo "  Latest: ${NEW_VERSIONS[tfsec]}"

# terrascan
print_info "Checking terrascan..."
CURRENT_VERSIONS[terrascan]=$(get_current_version "versionTerrascan")
NEW_VERSIONS[terrascan]=$(get_github_version "tenable/terrascan")
echo "  Current: ${CURRENT_VERSIONS[terrascan]} → Latest: ${NEW_VERSIONS[terrascan]}"

# terraform-docs
print_info "Checking terraform-docs..."
CURRENT_VERSIONS[terraform_docs]=$(get_current_version "versionTerraformDocs")
NEW_VERSIONS[terraform_docs]=$(get_github_version "terraform-docs/terraform-docs")
echo "  Current: ${CURRENT_VERSIONS[terraform_docs]} → Latest: ${NEW_VERSIONS[terraform_docs]}"

# tfupdate
print_info "Checking tfupdate..."
CURRENT_VERSIONS[tfupdate]=$(get_current_version "versionTfupdate")
NEW_VERSIONS[tfupdate]=$(get_github_version "minamijoyo/tfupdate")
echo "  Current: ${CURRENT_VERSIONS[tfupdate]} → Latest: ${NEW_VERSIONS[tfupdate]}"

# kubelogin
print_info "Checking kubelogin..."
CURRENT_VERSIONS[kubelogin]=$(get_current_version "versionKubelogin")
NEW_VERSIONS[kubelogin]=$(get_github_version "Azure/kubelogin")
echo "  Current: ${CURRENT_VERSIONS[kubelogin]} → Latest: ${NEW_VERSIONS[kubelogin]}"

# Helm
print_info "Checking Helm..."
NEW_VERSIONS[helm]=$(get_github_version "helm/helm")
echo "  Latest: ${NEW_VERSIONS[helm]}"

# GitHub CLI
print_info "Checking GitHub CLI..."
NEW_VERSIONS[gh]=$(get_github_version "cli/cli")
echo "  Latest: ${NEW_VERSIONS[gh]}"

# Ansible (ansible-core)
print_info "Checking Ansible (ansible-core)..."
CURRENT_VERSIONS[ansible]=$(get_current_version "versionAnsible")
NEW_VERSIONS[ansible]=$(get_pypi_version "ansible-core")
echo "  Current: ${CURRENT_VERSIONS[ansible]} → Latest: ${NEW_VERSIONS[ansible]}"

# Checkov
print_info "Checking Checkov..."
NEW_VERSIONS[checkov]=$(get_pypi_version "checkov")
echo "  Latest: ${NEW_VERSIONS[checkov]}"

# pre-commit
print_info "Checking pre-commit..."
NEW_VERSIONS[precommit]=$(get_pypi_version "pre-commit")
echo "  Latest: ${NEW_VERSIONS[precommit]}"

echo ""
print_success "Version check complete!"
echo ""

# Compare versions and identify updates
print_info "Analyzing version differences..."
echo ""

for tool in "${!CURRENT_VERSIONS[@]}"; do
    current="${CURRENT_VERSIONS[$tool]}"
    new="${NEW_VERSIONS[$tool]}"
    
    if [ "$current" != "$new" ]; then
        UPDATED_TOOLS[$tool]="$current → $new"
        print_warning "UPDATE AVAILABLE: $tool: $current → $new"
    fi
done

if [ ${#UPDATED_TOOLS[@]} -eq 0 ]; then
    print_success "All versions are up to date!"
    exit 0
fi

echo ""
print_info "Found ${#UPDATED_TOOLS[@]} tools with updates available"
echo ""

# Exit if dry-run
if [ "$DRY_RUN" = true ]; then
    print_info "Dry-run mode: No files will be modified"
    exit 0
fi

# Backup files
print_info "Creating backups..."
cp "$DOCKER_BAKE_FILE" "${DOCKER_BAKE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$README_FILE" "${README_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
print_success "Backups created"

# Update docker-bake.override.hcl
print_info "Updating docker-bake.override.hcl..."

for tool in "${!UPDATED_TOOLS[@]}"; do
    case $tool in
        kubectl)
            sed -i "s/versionKubectl=\".*\"/versionKubectl=\"${NEW_VERSIONS[$tool]}\"/" "$DOCKER_BAKE_FILE"
            ;;
        docker_compose)
            sed -i "s/versionDockerCompose=\".*\"/versionDockerCompose=\"${NEW_VERSIONS[$tool]}\"/" "$DOCKER_BAKE_FILE"
            ;;
        packer)
            sed -i "s/versionPacker=\".*\"/versionPacker=\"${NEW_VERSIONS[$tool]}\"/" "$DOCKER_BAKE_FILE"
            ;;
        vault)
            sed -i "s/versionVault=\".*\"/versionVault=\"${NEW_VERSIONS[$tool]}\"/" "$DOCKER_BAKE_FILE"
            ;;
        golang)
            sed -i "s/versionGolang=\".*\"/versionGolang=\"${NEW_VERSIONS[$tool]}\"/" "$DOCKER_BAKE_FILE"
            ;;
        powershell)
            sed -i "s/versionPowershell=\".*\"/versionPowershell=\"${NEW_VERSIONS[$tool]}\"/" "$DOCKER_BAKE_FILE"
            ;;
        terrascan)
            sed -i "s/versionTerrascan=\".*\"/versionTerrascan=\"${NEW_VERSIONS[$tool]}\"/" "$DOCKER_BAKE_FILE"
            ;;
        terraform_docs)
            sed -i "s/versionTerraformDocs=\".*\"/versionTerraformDocs=\"${NEW_VERSIONS[$tool]}\"/" "$DOCKER_BAKE_FILE"
            ;;
        tfupdate)
            sed -i "s/versionTfupdate=\".*\"/versionTfupdate=\"${NEW_VERSIONS[$tool]}\"/" "$DOCKER_BAKE_FILE"
            ;;
        kubelogin)
            sed -i "s/versionKubelogin=\".*\"/versionKubelogin=\"${NEW_VERSIONS[$tool]}\"/" "$DOCKER_BAKE_FILE"
            ;;
        ansible)
            sed -i "s/versionAnsible=\".*\"/versionAnsible=\"${NEW_VERSIONS[$tool]}\"/" "$DOCKER_BAKE_FILE"
            ;;
    esac
done

print_success "docker-bake.override.hcl updated"

# Update README.md
print_info "Updating README.md..."

# Update kubectl
if [ -n "${NEW_VERSIONS[kubectl]}" ]; then
    sed -i "s/| \*\*kubectl\*\* | [0-9.]\+ /| **kubectl** | ${NEW_VERSIONS[kubectl]} /" "$README_FILE"
fi

# Update Docker Compose
if [ -n "${NEW_VERSIONS[docker_compose]}" ]; then
    sed -i "s/| \*\*Docker Compose\*\* | [0-9.]\+ /| **Docker Compose** | ${NEW_VERSIONS[docker_compose]} /" "$README_FILE"
fi

# Update Packer
if [ -n "${NEW_VERSIONS[packer]}" ]; then
    sed -i "s/| \*\*Packer\*\* | [0-9.]\+ /| **Packer** | ${NEW_VERSIONS[packer]} /" "$README_FILE"
fi

# Update Vault
if [ -n "${NEW_VERSIONS[vault]}" ]; then
    sed -i "s/| \*\*Vault\*\* | [0-9.]\+ /| **Vault** | ${NEW_VERSIONS[vault]} /" "$README_FILE"
fi

# Update terrascan
if [ -n "${NEW_VERSIONS[terrascan]}" ]; then
    sed -i "s/| \*\*terrascan\*\* | [0-9.]\+ /| **terrascan** | ${NEW_VERSIONS[terrascan]} /" "$README_FILE"
fi

# Update terraform-docs
if [ -n "${NEW_VERSIONS[terraform_docs]}" ]; then
    sed -i "s/| \*\*terraform-docs\*\* | [0-9.]\+ /| **terraform-docs** | ${NEW_VERSIONS[terraform_docs]} /" "$README_FILE"
fi

# Update tfupdate
if [ -n "${NEW_VERSIONS[tfupdate]}" ]; then
    sed -i "s/| \*\*tfupdate\*\* | [0-9.]\+ /| **tfupdate** | ${NEW_VERSIONS[tfupdate]} /" "$README_FILE"
fi

# Update Go
if [ -n "${NEW_VERSIONS[golang]}" ]; then
    sed -i "s/| \*\*Go\*\* | [0-9.]\+ /| **Go** | ${NEW_VERSIONS[golang]} /" "$README_FILE"
fi

# Update PowerShell
if [ -n "${NEW_VERSIONS[powershell]}" ]; then
    sed -i "s/| \*\*PowerShell\*\* | [0-9.]\+ /| **PowerShell** | ${NEW_VERSIONS[powershell]} /" "$README_FILE"
fi

# Update Ansible
if [ -n "${NEW_VERSIONS[ansible]}" ]; then
    sed -i "s/| \*\*Ansible\*\* | [0-9.]\+ /| **Ansible** | ${NEW_VERSIONS[ansible]} /" "$README_FILE"
fi

# Update kubelogin
if [ -n "${NEW_VERSIONS[kubelogin]}" ]; then
    sed -i "s/| \*\*kubelogin\*\* | [0-9.]\+ /| **kubelogin** | ${NEW_VERSIONS[kubelogin]} /" "$README_FILE"
fi

print_success "README.md updated"

# Create update summary
SUMMARY_FILE="${SCRIPT_DIR}/VERSION_UPDATES_$(date +%Y-%m-%d).md"
print_info "Creating update summary: $SUMMARY_FILE"

cat > "$SUMMARY_FILE" << EOF
# Version Updates - $(date +"%B %d, %Y")

This document summarizes the version updates made by the automatic update script.

## Updated Tools (${#UPDATED_TOOLS[@]})

| Tool | Previous | New | Status |
|------|----------|-----|--------|
EOF

for tool in "${!UPDATED_TOOLS[@]}"; do
    echo "| $tool | ${CURRENT_VERSIONS[$tool]} | ${NEW_VERSIONS[$tool]} | ✅ Updated |" >> "$SUMMARY_FILE"
done

cat >> "$SUMMARY_FILE" << EOF

## Latest Versions (Reference Only)

| Tool | Version |
|------|---------|
| Terraform | ${NEW_VERSIONS[terraform]} |
| Helm | ${NEW_VERSIONS[helm]} |
| GitHub CLI | ${NEW_VERSIONS[gh]} |
| tflint | ${NEW_VERSIONS[tflint]} |
| tfsec | ${NEW_VERSIONS[tfsec]} |
| Checkov | ${NEW_VERSIONS[checkov]} |
| pre-commit | ${NEW_VERSIONS[precommit]} |

## Files Modified

1. ✅ docker-bake.override.hcl
2. ✅ README.md

## Testing Recommendations

\`\`\`bash
# Build with new versions
make local

# Verify tools
terraform version
kubectl version --client
ansible --version
\`\`\`

---

**Generated**: $(date +"%Y-%m-%d %H:%M:%S")
**Script**: update_versions.sh
EOF

print_success "Summary created: $SUMMARY_FILE"

# Auto-commit if requested
if [ "$AUTO_COMMIT" = true ]; then
    print_info "Auto-committing changes..."
    
    git add "$DOCKER_BAKE_FILE" "$README_FILE" "$SUMMARY_FILE"
    git commit -m "chore: update tool versions to latest releases

- Updated ${#UPDATED_TOOLS[@]} tools to their latest versions
- See $SUMMARY_FILE for details

Auto-generated by update_versions.sh"
    
    print_success "Changes committed"
fi

echo ""
print_success "Update complete!"
echo ""
print_info "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Test build: make local"
echo "  3. Commit changes: git commit -am 'chore: update tool versions'"
echo ""
