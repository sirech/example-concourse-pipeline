#!/bin/bash

set -e
set -o nounset
set -o pipefail

# shellcheck source=./go.variables
source "${SCRIPT_DIR}/go.variables"

SCRIPT_DIR=$(cd "$(dirname "$0")" ; pwd -P)

goal_update-pipeline() {
  pushd "${SCRIPT_DIR}" > /dev/null
  fly --target "${CONCOURSE_TARGET}" login \
      --concourse-url "${CONCOURSE_URL}" \
      --username "${CONCOURSE_USER}" \
      --password "${CONCOURSE_PASSWORD}"
  fly --target "${CONCOURSE_TARGET}" sync
  fly --target "${CONCOURSE_TARGET}" set-pipeline \
      --non-interactive \
      --pipeline "${PIPELINE_NAME}" \
      --config pipeline.yml
  popd > /dev/null
}

TARGET=${1:-}
if [ -n "${TARGET}" ] && type -t "goal_$TARGET" &>/dev/null; then
  "goal_$TARGET" "${@:2}"
else
  echo "Target not recognized"
  exit 1
fi
