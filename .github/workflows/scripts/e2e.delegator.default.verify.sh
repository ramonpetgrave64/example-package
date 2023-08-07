#!/usr/bin/env bash

# shellcheck source=/dev/null
source "./.github/workflows/scripts/e2e-verify.common.sh"

RUNNER_DEBUG=${RUNNER_DEBUG:-}
if [[ -n "${RUNNER_DEBUG}" ]]; then
    set -x
fi

go env -w GOFLAGS=-mod=mod

# verify_provenance_content verifies provenance content generated by the container generator.
verify_provenance_content() {
    ATTESTATION=$(jq -r '.dsseEnvelope.payload' <"$PROVENANCE" | base64 -d)

    echo "  **** Provenance content verification *****"

    # Verify all common provenance fields.
    e2e_verify_common_all_v1 "$ATTESTATION"

    e2e_verify_predicate_subject_name "$ATTESTATION" "$BINARY"
    # NOTE: the ref must be a tag. The builder uses the delegator at head.
    e2e_verify_predicate_v1_runDetails_builder_id "$ATTESTATION" "${BUILDER_ID}"
    e2e_verify_predicate_v1_buildDefinition_buildType "$ATTESTATION" "https://github.com/slsa-framework/slsa-github-generator/delegator-generic@v0"

    # Verify the artifact contains the expected value.
    if [[ -n ${CHECKOUT_SHA1:-} ]]; then
        cat < "${BINARY}" | grep "${CHECKOUT_MESSAGE}" || exit 1
    fi
}

THIS_FILE=$(e2e_this_file)
BRANCH=$(echo "$THIS_FILE" | cut -d '.' -f4)
echo "branch is $BRANCH"
echo "GITHUB_REF_NAME: $GITHUB_REF_NAME"
echo "GITHUB_REF_TYPE: $GITHUB_REF_TYPE"
echo "GITHUB_REF: $GITHUB_REF"
echo "DEBUG: file is $THIS_FILE"

export SLSA_VERIFIER_TESTING="true"

# Verify provenance authenticity.
# TODO(233): Update to v1.8.0 tag.
e2e_run_verifier_all_releases "HEAD"

# Verify provenance content.
verify_provenance_content
