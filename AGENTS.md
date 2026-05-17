# AI Agent Instructions & Guidelines

Welcome! This document outlines critical instructions and operational rules that
all AI coding agents must strictly follow when working in the `home-lab`
repository.

## 1. Living Specifications & Documentation Integrity

This repository relies on **living design specifications** to guide all
architectural, testing, and deployment choices before code is modified. These
specs are located in `websites-src/home-lab-docs/specs/`.

### 1.1 Specifications Index & Status Tracking

The specs folder entrypoint
[`websites-src/home-lab-docs/specs/README.md`](./websites-src/home-lab-docs/specs/README.md)
acts as a global index. It features an index table outlining the architectural
scope and overall **Current Implementation Status** of each specification.

### 1.2 Individual Spec Status Tables

Every specification file (e.g., `hl02-proxmox-vm.md`,
`home-lab-bootstrapping.md`) contains an **Implementation Status** table right
beneath the main title. This table tracks the status (`Fully Implemented`,
`Partially Implemented`, or `Missing`) of each component defined inside the
specification.

## 2. Agent Workflow Rules (Crucial)

When executing any task, feature addition, or refactoring inside this codebase,
agents **MUST** adhere to the following documentation workflow:

### Step 1: Discover & Align

Before writing any Nix, Terraform, or CI workflow code, read the relevant design
specifications to understand constraints, design splits, security rules (like
SSH key guards), and naming conventions.

### Step 2: Implement Code

Proceed with the code implementation (writing modules, configs, scripts, or CI
workflows) as approved.

### Step 3: Synchronize Living Status (Mandatory)

As soon as code changes are successfully tested and completed (or when a logical
sub-task is finished), you **MUST** immediately update the status tables in the
documentation to prevent configuration drift:

1.  **Update the Individual Spec Table:** Open the relevant specification file
    in `websites-src/home-lab-docs/specs/` and update the `Status` and `Details`
    fields for the modified features. For example, transition a component from
    `Missing` to `Fully Implemented`.
2.  **Update the Global Index:** Open the specs root
    [`README.md`](./websites-src/home-lab-docs/specs/README.md) and update the
    **Current Implementation Status** column for the target specification to
    reflect the latest state.

To do this, **use the `maintain-living-specs` skill** if available to
programmatically analyze repository changes and systematically synchronize the
individual specification status tables and the root `specs/README.md` index.

## 3. Markdown & Documentation Style Rules

To maintain a highly clean and consistent aesthetic across the documentation,
agents must strictly follow these style rules:

- **No Horizontal Separators:** Do not use `---` horizontal rules or separators
  in any Markdown files. Rely on standard paragraph breaks and clean Markdown
  headers (`##`, `###`) to organize layout.
- **Explicit File References:** Always format file references as Markdown links
  using relative paths (e.g., `[README.md](./README.md)`), ensuring they are
  fully navigable.
- **No Trailing Punctuation in Headings:** Do not place trailing punctuation
  (such as colons `:`, periods `.`, exclamation marks `!`, or question marks
  `?`) at the end of headings. Headings should remain descriptive, clean, and
  concise.

## 4. Design & Modularization Rules

When introducing new hosts, roles, or automation features, adhere to these
architectural patterns:

- **Decouple Architecture vs. Deployment:** Never combine global infrastructure
  logic (e.g., how integration testing or bootstrapping works in general) with
  host-specific configuration details. Design modular, reusable specs for the
  framework (under `websites-src/home-lab-docs/specs/`) and keep individual host
  specs focused exclusively on physical/logical declarations for that machine
  (e.g., specific VM core count, dedicated RAM, and MAC address).
