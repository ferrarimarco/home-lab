#!/bin/bash

set -o pipefail

echo "This script has been invoked with: $0 $*"

if ! TEMP="$(getopt -o ho --long help,host \
    -n 'diagnostics' -- "$@")"; then
    echo "Terminating..." >&2
    exit 1
fi
eval set -- "$TEMP"

cmd=

while true; do
    echo "Decoding parameter $1"
    case "$1" in
    -h | --help)
        echo "Found help parameter"
        cmd="help"
        shift
        ;;
    -o | --host)
        echo "Found host parameter"
        cmd="host"
        shift
        ;;
    --)
        shift
        break
        ;;
    *) break ;;
    esac
done

declare -A file_content_exclusions=(
    ["/var/log/auth.log"]="debug1|debug2"
)

directories_to_print=(
    "$TRAVIS_BUILD_DIR"
    "$TRAVIS_BUILD_DIR"/esp-idf
)

files_to_print=(
    /etc/hosts
)

print_directory_contents() {
    directory_path="${1}"
    echo "-------- START $directory_path DIRECTORY CONTENTS --------"

    if [ -d "$directory_path" ]; then
        ls -al "$directory_path"
    else
        echo "WARNING: $directory_path not found or it's not a directory"
    fi

    echo "-------- END $directory_path DIRECTORY CONTENTS --------"

    unset directory_path
}

print_file_contents() {
    file_path="${1}"
    grep_pattern_to_exclude="${file_content_exclusions[$file_path]}"
    echo "-------- START $file_path FILE CONTENTS --------"

    if [ -f "$file_path" ]; then
        if [ -z "$grep_pattern_to_exclude" ]; then
            echo "No exclusions configured for $file_path. Showing the full contents."
            cat "$file_path"
        else
            echo "Excluding $grep_pattern_to_exclude from the output of the contents of this file."
            grep -Ev "$grep_pattern_to_exclude" "$file_path"
        fi

    else
        echo "WARNING: $file_path not found"
    fi

    echo "-------- END $file_path FILE CONTENTS --------"

    unset file_path
}

host_diagnostics() {
    run_diagnostic_command "whoami" "whoami"
    run_diagnostic_command "hostname" "hostname --fqdn"
    run_diagnostic_command "ip" "ip addr"
    run_diagnostic_command "pwd" "pwd"

    if [ -f /var/run/docker.sock ]; then
        run_diagnostic_command "docker" "docker info --format '{{json .}}'"
        run_diagnostic_command "docker" "docker --version"
        run_diagnostic_command "docker" "docker -D info"
        run_diagnostic_command "docker" "docker images -a --filter='dangling=false' --format '{{.Repository}}:{{.Tag}} {{.ID}}'"
        run_diagnostic_command "docker" "docker info --format '{{json .}}'"
    else
        echo "WARNING: Docker socket not found"
    fi

    run_diagnostic_command "dpkg" "dpkg -l | sort"

    run_diagnostic_command "env" "env | sort"

    run_diagnostic_command "bundle" "bundle list"
    run_diagnostic_command "cmake" "cmake --version"
    run_diagnostic_command "gem" "gem environment"
    run_diagnostic_command "gem" "gem query --local"

    run_diagnostic_command "gimme" "gimme --version"

    run_diagnostic_command "git" "git status"
    run_diagnostic_command "git" "git branch"
    run_diagnostic_command "git" "git log --oneline --graph --all | tail -n 10"
    run_diagnostic_command "git" "git --no-pager diff"

    run_diagnostic_command "go" "go version"

    run_diagnostic_command "journalctl" "journalctl -xb -p warning --no-pager"
    run_diagnostic_command "journalctl" "journalctl -xb --no-pager -u sshd.service"

    run_diagnostic_command "lsmod" "lsmod | sort"

    if [ -s "$NVM_DIR"/nvm.sh ]; then
        echo "Found nvm. Switching to the default node version (see .nvmrc)"
        [ -f .nvmrc ] && echo ".nvmrc contents: $(cat .nvmrc)"
        # shellcheck source=/dev/null
        NVM_DIR="${HOME}/.nvm" && [ -s "$NVM_DIR"/nvm.sh ] && . "$NVM_DIR/nvm.sh"
        echo "nvm command: $(command -v nvm)"
        echo "nvm version: $(nvm --version)"
        nvm use
    fi

    run_diagnostic_command "npm" "command -v npm"
    run_diagnostic_command "npm" "npm --version"

    run_diagnostic_command "npm" "npm list -g --depth=0"

    run_diagnostic_command "pip" "command -v pip"
    run_diagnostic_command "pip" "pip --version"

    run_diagnostic_command "pip3" "command -v pip3"
    run_diagnostic_command "pip3" "pip3 --version"

    run_diagnostic_command "python" "command -v python"
    run_diagnostic_command "python" "python --version"

    run_diagnostic_command "python3" "command -v python3"
    run_diagnostic_command "python3" "python3 --version"

    run_diagnostic_command "showmount" "timeout 15s showmount -e localhost"

    run_diagnostic_command "sshd" "sshd -T"

    run_diagnostic_command "systemctl" "systemctl --version"
    run_diagnostic_command "systemctl" "systemctl list-unit-files | sort"
    run_diagnostic_command "systemctl" "systemctl -l status sshd.service"
    run_diagnostic_command "systemctl" "systemctl --failed"

    for i in "${directories_to_print[@]}"; do
        print_directory_contents "$i"
    done

    for i in "${files_to_print[@]}"; do
        print_file_contents "$i"
    done
}

run_diagnostic_command() {
    command_name="${1}"
    command_function_name="${2}"

    echo "-------- START $command_function_name, pwd: $(pwd) --------"

    if command -v "$command_name" >/dev/null 2>&1; then
        eval "$command_function_name"
    else
        echo "WARNING: $command_name command not found"
    fi

    echo "-------- END $command_function_name, pwd: $(pwd) --------"

    unset command_name
    unset command_function_name
}

usage() {
    echo "Usage:"
    echo "  -h, --help                                        - show this help."
    echo "  -o, --host                                        - run diagnostics against the host system."
}

main() {
    local cmd=$1

    if [[ -z "$cmd" ]]; then
        echo "ERROR: no command selected. Exiting..."
        usage
        exit 1
    fi

    echo "Selected command: $cmd"

    if [[ $cmd == "host" ]]; then
        host_diagnostics
    elif [[ $cmd == "help" ]]; then
        usage
    else
        usage
    fi
}

main "$cmd"
