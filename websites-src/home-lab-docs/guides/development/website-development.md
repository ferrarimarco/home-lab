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

Build in the main checkout whenever the working tree holds only the changes of
the commit: the output then matches the sources, and nothing is left behind.
Only when the tree also holds changes that must stay out of the commit (another
session's, or those of a later commit) build the site from the sources of the
commit alone, in a temporary worktree. A copy of the files is not enough because
the build script needs a Git repository.

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

4. Put the output into the commit without touching the main working tree, which
   may hold another session's generated files: stage `docs/` in the worktree and
   amend the commit there, then, with the main checkout on the branch whose tip
   that commit is, move the branch to the amended commit with a mixed reset,
   which refreshes the index and leaves the working tree alone:

    ```shell
    git -C <worktree directory> add docs
    git -C <worktree directory> commit --amend --no-edit
    git reset "$(git -C <worktree directory> rev-parse HEAD)"
    ```

    The main working tree's generated files now predate the commit. When
    `git status docs` showed nothing before the build, nothing in them needs
    protecting: restore them from the commit right away, or the checkout keeps
    showing the commit's new pages as deleted and the changed ones as modified
    until its next build:

    ```shell
    git restore docs
    ```

    When `docs/` held another session's output, leave it, and say so: the next
    build reconciles it.

5. Remove the worktree. A lint run from the worktree leaves root-owned
   `super-linter-output/` and `super-linter.log` behind, which make the removal
   fail with a permission error. Delete those two lint outputs, and nothing
   else, through a container first:

    ```shell
    docker run --rm --volume <worktree directory>:/wt alpine:3 \
      sh -c 'rm -rf /wt/super-linter-output /wt/super-linter.log'
    git worktree remove --force <worktree directory>
    ```
