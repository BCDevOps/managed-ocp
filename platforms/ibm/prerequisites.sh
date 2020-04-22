source ../../lib/setup_helper.sh;

checkDependencies;
cleanModules;
# installNodeIfNeeded;
# installJavaIfNeeded;
# installGradleIfNeeded;
installTerraformIfNeeded;

# install IBM specific openshift plugins

# install IBM specific terraform plugins


source "${PROFILE_FILE}";
source "${RC_FILE}";
