#!/usr/bin/env sh

set -o nounset
set -o errexit

mkdir -p "$(pwd)"/rendered-templates

consul-template \
    -template "in.tpl:out.txt" \
    -once
