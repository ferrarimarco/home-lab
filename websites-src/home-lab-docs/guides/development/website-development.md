# Develop and build the Home Lab site

This document explains how to develop the Home Lab site and how to run it
locally for a preview.

## Build the site locally

1. Run the build script:

    ```shell
    scripts/run-mkdocs.sh serve home-lab-docs ./websites-src/home-lab-docs ./docs
    ```

## Documentation change workflow

After editing any file under `websites-src/`, run this pipeline before
committing:

1. Format the changed files:

    ```shell
    scripts/format.sh <changed file> [...]
    ```

2. Rebuild the site output:

    ```shell
    scripts/run-mkdocs.sh build home-lab-docs ./websites-src/home-lab-docs ./docs
    ```

3. Run the authoritative check-mode lint, capturing the full output to a log
   file:

    ```shell
    scripts/lint.sh > lint.log 2>&1
    ```

    Review `super-linter-output/super-linter-summary.md` for the per-linter
    verdict.

4. Commit the source changes together with the regenerated `docs/` output, so
   the published site never drifts from its sources.

New pages don't need navigation configuration: MkDocs generates the navigation
from the directory tree, which is why adding a page changes the rendered
navigation of every existing page in `docs/`.
