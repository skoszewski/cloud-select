#!/usr/bin/env bash
# test.sh - Automated tests for cloud-select.sh

set -euo pipefail

# Create isolated playground directories
TEST_DIR=$(mktemp -d -t cloud-select-test.XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT

# Mock HOME (resolved to physical path to handle macOS /var symlink)
export HOME="$(cd "$TEST_DIR" && pwd -P)"
# Unset any existing overrides to test defaults
unset CLOUD_CLI_PROFILE_DIR
unset GCLOUD_PROFILE_ROOT
unset AZURECLI_PROFILE_ROOT
unset CLOUDSDK_CONFIG
unset AZURE_CONFIG_DIR

# ---------------------------------------------------------
# Test Helper Functions
# ---------------------------------------------------------
echo_test() {
    printf "\n=== %s ===\n" "$1"
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-Assertion failed}"
    if [[ "$expected" != "$actual" ]]; then
        printf "ERROR: %s\nExpected: '%s'\nActual:   '%s'\n" "$msg" "$expected" "$actual" >&2
        exit 1
    fi
}

assert_dir_exists() {
    if [[ ! -d "$1" ]]; then
        printf "ERROR: Directory does not exist: %s\n" "$1" >&2
        exit 1
    fi
}

assert_empty() {
    if [[ -n "$1" ]]; then
        printf "ERROR: Expected empty value, got '%s'\n" "$1" >&2
        exit 1
    fi
}

# Source the main script
source ./cloud-select.sh

# ---------------------------------------------------------
# Test Case 1: Default GCP Profile Directory Creation & Selection
# ---------------------------------------------------------
echo_test "Test 1: Default GCP profile selection"
gcloud-select select my-gcp-profile
assert_eq "$HOME/.config/gcloud.d/my-gcp-profile" "$CLOUDSDK_CONFIG" "CLOUDSDK_CONFIG path is incorrect"
assert_dir_exists "$HOME/.config/gcloud.d/my-gcp-profile"

# ---------------------------------------------------------
# Test Case 2: Default Azure Profile Directory Creation & Selection
# ---------------------------------------------------------
echo_test "Test 2: Default Azure profile selection"
azurecli-select select my-azure-profile
assert_eq "$HOME/.config/azure.d/my-azure-profile" "$AZURE_CONFIG_DIR" "AZURE_CONFIG_DIR path is incorrect"
assert_dir_exists "$HOME/.config/azure.d/my-azure-profile"

# ---------------------------------------------------------
# Test Case 3: CLOUD_CLI_PROFILE_DIR Override behavior
# ---------------------------------------------------------
echo_test "Test 3: CLOUD_CLI_PROFILE_DIR Override"
export CLOUD_CLI_PROFILE_DIR="$HOME/custom-profiles"

# Sourcing again after setting the override to let setup recalculate globals
source ./cloud-select.sh

gcloud-select select custom-gcp
assert_eq "$HOME/custom-profiles/gcloud.d/custom-gcp" "$CLOUDSDK_CONFIG" "GCP path not overridden correctly"
assert_dir_exists "$HOME/custom-profiles/gcloud.d/custom-gcp"

azurecli-select select custom-azure
assert_eq "$HOME/custom-profiles/azure.d/custom-azure" "$AZURE_CONFIG_DIR" "Azure path not overridden correctly"
assert_dir_exists "$HOME/custom-profiles/azure.d/custom-azure"

# ---------------------------------------------------------
# Test Case 4: Individual Profile Root Overrides
# ---------------------------------------------------------
echo_test "Test 4: Individual Profile Root Overrides"
export GCLOUD_PROFILE_ROOT="$HOME/gcp-root-direct"
export AZURECLI_PROFILE_ROOT="$HOME/azure-root-direct"

# Sourcing to recalculate
source ./cloud-select.sh

gcloud-select select direct-gcp
assert_eq "$HOME/gcp-root-direct/direct-gcp" "$CLOUDSDK_CONFIG" "Individual GCLOUD_PROFILE_ROOT override failed"
assert_dir_exists "$HOME/gcp-root-direct/direct-gcp"

azurecli-select select direct-azure
assert_eq "$HOME/azure-root-direct/direct-azure" "$AZURE_CONFIG_DIR" "Individual AZURECLI_PROFILE_ROOT override failed"
assert_dir_exists "$HOME/azure-root-direct/direct-azure"

# ---------------------------------------------------------
# Test Case 5: Selecting default profile (no arguments)
# ---------------------------------------------------------
echo_test "Test 5: Selecting default profile with no arguments"

# Set up mock default candidate directory
mkdir -p "$HOME/.azure"
azurecli-select select
assert_eq "$HOME/.azure" "$AZURE_CONFIG_DIR" "Should fallback to default candidates when no profile is provided"

# Reset candidate directory and test unsetting when no candidate exists
rm -rf "$HOME/.azure"
azurecli-select select
assert_empty "${AZURE_CONFIG_DIR-}" "AZURE_CONFIG_DIR should be unset if no default candidates exist"

# ---------------------------------------------------------
# Test Case 6: Help and usage info
# ---------------------------------------------------------
echo_test "Test 6: Help and usage validation"
gcloud-select help | grep -q "usage: gcloud-select"
azurecli-select help | grep -q "usage: azurecli-select"

printf "\nALL TESTS PASSED SUCCESSFULLY!\n"
