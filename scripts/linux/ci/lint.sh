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
