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

## Build the site from committed sources only

The build reads the working tree, including uncommitted changes and untracked
files. If the working tree contains source changes that don't belong to the
commit, such as the changes of another session, the generated output includes
them. Before committing, review the differences in `docs/` to confirm that they
only reflect the sources in the same commit.

To build the site from the sources of a commit only, build it in a temporary
worktree. A copy of the files is not enough because the build script needs a Git
repository.

1. Create the worktree outside the repository:

    ```shell
    git worktree add --detach <worktree directory> <commit>
    ```

2. Build the site from the worktree directory:

    ```shell
    scripts/run-mkdocs.sh build home-lab-docs ./websites-src/home-lab-docs ./docs
    ```

3. Compare the output in the worktree with the output to commit. For example,
   `git status` in the worktree lists the generated files that differ from the
   ones in the commit.

    The lint script runs from the worktree as well, so the check-mode lint run
    can cover the same sources as the build; the
    [operational scripts guide](./operational-scripts.md) describes how it
    mounts the main repository's metadata.

4. Remove the worktree:

    ```shell
    git worktree remove --force <worktree directory>
    ```
