#!/usr/bin/env bash

# shellcheck source=/dev/null
source "./.github/workflows/scripts/e2e-verify.common.sh"

# Script Inputs
GITHUB_REF=${GITHUB_REF:-}
GITHUB_REF_NAME=${GITHUB_REF_NAME:-}
GITHUB_REF_TYPE=${GITHUB_REF_TYPE:-}
RUNNER_DEBUG=${RUNNER_DEBUG:-}
if [[ -n "${RUNNER_DEBUG}" ]]; then
    set -x
fi

go env -w GOFLAGS=-mod=mod

# verify_provenance_content verifies provenance content generated by the container generator.
verify_provenance_content() {
    # Script Inputs
    local attestation
    local binary=${BINARY:-}
    local checkout_sha1=${CHECKOUT_SHA1:-}
    local checkout_message=${CHECKOUT_MESSAGE:-}
    local full_builder_id=${BUILDER_ID:-}
    local provenance=${PROVENANCE:-}

    attestation=$(jq -r '.dsseEnvelope.payload' <"${provenance}" | base64 -d)

    echo "  **** Provenance content verification *****"

    # Verify all common provenance fields.
    e2e_verify_common_all_v1 "${attestation}"

    e2e_verify_predicate_subject_name "${attestation}" "${binary}"
    # NOTE: the ref must be a tag. The builder uses the delegator at head.
    # The tag is provided as "vx.y.z", so we re-construct the git ref.
    local builder_id builder_tag
    builder_id=$(echo "${full_builder_id}" | cut -d@ -f1)
    builder_tag=$(echo "${full_builder_id}" | cut -d@ -f2)
    e2e_verify_predicate_v1_runDetails_builder_id "${attestation}" "${builder_id}@refs/tags/${builder_tag}"
    e2e_verify_predicate_v1_buildDefinition_buildType "${attestation}" "https://github.com/slsa-framework/slsa-github-generator/delegator-generic@v0"

    # Verify the artifact contains the expected value.
    if [[ -n ${checkout_sha1} ]]; then
        cat <"${binary}" | grep "${checkout_message}" || exit 1
    fi
}

this_file=$(e2e_this_file)
this_branch=$(e2e_this_branch)
echo "branch is ${this_branch}"
echo "GITHUB_REF_NAME: ${GITHUB_REF_NAME}"
echo "GITHUB_REF_TYPE: ${GITHUB_REF_TYPE}"
echo "GITHUB_REF: ${GITHUB_REF}"
echo "DEBUG: file is ${this_file}"

export SLSA_VERIFIER_TESTING="true"

# Verify provenance authenticity.
# TODO(233): Update to v1.8.0 tag.
e2e_run_verifier_all_releases "HEAD"

# Verify provenance content.
verify_provenance_content
