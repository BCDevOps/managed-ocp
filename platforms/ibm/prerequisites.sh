#!/bin/bash
CALLER_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
source "$CALLER_DIR/../../lib/setup_helper.sh";
source "$CALLER_DIR/lib/ibm_cloud_components.sh";

checkDependencies;
installTerraformIfNeeded;
installIbmTerraformPluginsIfNeeded;
installIbmOpenshiftCliPluginsIfNeeded;

source "${PROFILE_FILE}";
source "${RC_FILE}";
