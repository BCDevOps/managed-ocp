#!/bin/bash
set -euo pipefail

CALLER_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
source "$CALLER_DIR/../../lib/dependency_tools_install.sh";
source "$CALLER_DIR/../../lib/setup_helper.sh";
source "$CALLER_DIR/lib/ibm_cloud_components.sh";

checkDependencies;
handleOrderDependentIbmCloudTerraformSetups;

source "${PROFILE_FILE}";
source "${RC_FILE}";

echo "This directory tree uses the following package version set:";
asdf current;
