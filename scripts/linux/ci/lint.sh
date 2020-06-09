#!/bin/bash

set -e
set -o pipefail

INITIAL_PWD="$(pwd)"
echo "Current working directory: $INITIAL_PWD"

git diff-tree --check "$(git hash-object -t tree /dev/null)" HEAD

find "$(pwd)" -type f -not -path "*/\.git/*" -not -path "*/\node_modules/*" >tmp
while IFS= read -r file; do
    case "$(git diff --no-index --numstat /dev/null "$file")" in
    "$(printf '%s\t-\t' -)"*)
        echo "skipping newline check for $file because it's a binary"
        continue
        ;;
    *)
        echo "Checking if $file ends with a newline"
        [ -z "$(tail -c1 "$file")" ] || echo "ERROR: $file doesn't end with a newline" || exit 1
        ;;
    esac
done <tmp
rm tmp

while IFS= read -r -d '' file; do
    echo "Linting $file"
    docker run --rm -i hadolint/hadolint:v1.17.5-8-gc8bf307-alpine <"$file" || exit 1
done < <(find "$(pwd)" -type f -not -path "*/\.git/*" -not -name "*.md" -not -path "*/\node_modules/*" -name "Dockerfile" -print0)

while IFS= read -r -d '' file; do
    f="${file#$(pwd)}"
    f="${f/\//}"
    echo "Linting $f"
    if [ ! -x "$f" ]; then
        echo "Error: $f is not executable!"
        exit 1
    fi
    docker run -v "$(pwd)":/mnt:ro --rm -t koalaman/shellcheck:v0.7.1 "$f" || exit 1
done < <(find "$(pwd)" -type f -not -path "*/\.git/*" -not -name "*.md" -not -path "*/\node_modules/*" -exec grep -Eq '^#!(.*/|.*env +)(sh|bash|ksh)' {} \; -print0)

find . -type f \( -iname \*.yml -o -iname \*.yaml \) -not -path "*/\\.git/*" -not -path "*/\node_modules/*" | sort -u | while read -r f; do
    if yamllint --strict "$f"; then
        echo "[OK]: sucessfully linted $f"
    else
        echo "[FAIL]: found errors/warnings while linting $f"
        exit 1
    fi
done

find "$(pwd)" -name "*.md" -type f -not -path "*/\.git/*" -not -path "*/\node_modules/*" >tmp
while IFS= read -r file; do
    echo "Checking $file with markdownlint"
    markdownlint "$file" || exit 1
done <tmp
rm tmp

shfmt -d . || exit 1

cd configuration/ansible || exit 1
ansible-lint -v bootstrap-managed-nodes.yml || exit 1
echo "Setting the working directory back to $INITIAL_PWD"
cd "$INITIAL_PWD" || exit 1
