#!/usr/bin/env sh

set -e

if ! TEMP="$(getopt -o c:d:f:g:s: --long cloud-build-substitutions:,commit-sha:,destination-directory-path:,failure-file-path:,git-repository-path: \
  -n 'submit-cloud-build' -- "$@")"; then
  echo "Terminating..." >&2
  exit 1
fi
eval set -- "$TEMP"

CLOUD_BUILD_SUBSTITUTIONS=
COMMIT_SHA=
DESTINATION_DIRECTORY_PATH=
FAILURE_FILE_PATH=
GIT_REPOSITORY_PATH=

while true; do
  case "$1" in
  -c | --commit-sha)
    COMMIT_SHA="$2"
    shift 2
    ;;
  -d | --destination-directory-path)
    DESTINATION_DIRECTORY_PATH="$2"
    shift 2
    ;;
  -f | --failure-file-path)
    FAILURE_FILE_PATH="$2"
    shift 2
    ;;
  -g | --git-repository-path)
    GIT_REPOSITORY_PATH="$2"
    shift 2
    ;;
  -s | --cloud-build-substitutions)
    CLOUD_BUILD_SUBSTITUTIONS="$2"
    shift 2
    ;;
  --)
    shift
    break
    ;;
  *) break ;;
  esac
done

if [ -z "$FAILURE_FILE_PATH" ]; then
  echo "Specify a failure file path with the -f | --failure-file-path. Terminating..."
  exit 1
fi
touch "${FAILURE_FILE_PATH}"

if [ -z "$COMMIT_SHA" ]; then
  echo "Specify a Git commit SHA with the -c | --commit-sha option. Terminating..." | tee -a "${FAILURE_FILE_PATH}"
  exit 1
fi

if [ -z "$DESTINATION_DIRECTORY_PATH" ]; then
  echo "Specify a destination directory inside the Git repository with the -d | --destination-directory-path. Terminating..." | tee -a "${FAILURE_FILE_PATH}"
  exit 1
fi

if [ -z "$GIT_REPOSITORY_PATH" ]; then
  echo "Specify a Git repository path with the -g | --git-repository-path. Terminating..." | tee -a "${FAILURE_FILE_PATH}"
  exit 1
fi

echo "Copying the Git repo in a temporary location to avoid conflicts with other builds..."
TEMP_GIT_REPOSITORY_PATH="$(mktemp -d)"
cp -a "$GIT_REPOSITORY_PATH"/. "$TEMP_GIT_REPOSITORY_PATH"
GIT_REPOSITORY_PATH="$TEMP_GIT_REPOSITORY_PATH"

echo "$COMMIT_SHA contains the following modified files that match $DESTINATION_DIRECTORY_PATH:"
if ! git -C "$TEMP_GIT_REPOSITORY_PATH" diff-tree --name-only --no-commit-id -r "$COMMIT_SHA" | grep "$DESTINATION_DIRECTORY_PATH"; then
  echo "$COMMIT_SHA revision doesn't contain any modification to files that match $DESTINATION_DIRECTORY_PATH. Skipping the relevant build job..."
  exit 0
fi

echo "Checking out the $COMMIT_SHA Git revision..."
# Disable the "detached HEAD" warning before checking out the revision
git config --global advice.detachedHead false
git -C "$TEMP_GIT_REPOSITORY_PATH" checkout "$COMMIT_SHA"

CLOUD_BUILD_JOB_PATH="$TEMP_GIT_REPOSITORY_PATH"/"$DESTINATION_DIRECTORY_PATH"
config="${CLOUD_BUILD_JOB_PATH}/cloudbuild.yaml"
if [ ! -f "${config}" ]; then
  echo "${DESTINATION_DIRECTORY_PATH} failed: ${config} not found." | tee -a "${FAILURE_FILE_PATH}"
  exit 1
fi

echo "Building $DESTINATION_DIRECTORY_PATH... "
logfile="${CLOUD_BUILD_JOB_PATH}/cloudbuild.log"

# Add the substitution option only when needed. The subshell must not be quoted.
# shellcheck disable=SC2046
if ! gcloud builds submit "$CLOUD_BUILD_JOB_PATH" --config="${config}" $([ -n "$CLOUD_BUILD_SUBSTITUTIONS" ] && printf %s "--substitutions $CLOUD_BUILD_SUBSTITUTIONS") >"${logfile}" 2>&1; then
  echo "$DESTINATION_DIRECTORY_PATH failed" | tee -a "${FAILURE_FILE_PATH}"
  cat "${logfile}"
else
  echo "$DESTINATION_DIRECTORY_PATH build completed successfully"
fi

echo "Removing the Git repository copy..."
rm -rf "$TEMP_GIT_REPOSITORY_PATH"
