# 🤖 Available Agents - rover

This document lists practical AI agents for the `rover` repository (container/tooling/orchestration).

## 🚀 Core Agents

### **Rover Image Maintainer**
**Purpose:** Maintain Docker image toolchain, pinned versions, and build reliability.

**When to use:**
- "Update Terraform/Azure CLI/kubectl versions"
- "Fix Docker build failure"
- "Harden image and reduce CVEs"

### **Rover Wrapper Engineer**
**Purpose:** Improve wrapper scripts and execution UX for landing zones.

**When to use:**
- "Fix rover command flags/arg parsing"
- "Improve state wiring behavior"
- "Add diagnostics and better error messages"

### **CI Pipeline Maintainer**
**Purpose:** Keep CI workflows green and reproducible.

**When to use:**
- "Fix failing workflow"
- "Add matrix for image variants"
- "Improve cache/build times"

### **Documentation Sync**
**Purpose:** Keep README/docs aligned with image behavior and scripts.

**When to use:**
- "Document new tool versions"
- "Update quick start commands"

## ✅ Validation Checklist

- Docker build passes locally/CI
- Wrapper smoke test succeeds
- Version pins documented
- README updated for user-facing changes

**Last Updated:** March 2026
**Namespace:** aztfmodnew/rover
