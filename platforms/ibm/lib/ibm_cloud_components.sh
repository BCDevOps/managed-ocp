#!/bin/bash
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
source "$DIR/../../../lib/setup_helper.sh";

IBM_API_KEY_NAME="IbmCloudApi";
IBM_API_KEY_FILENAME="$IBM_API_KEY_NAME.json";
IBM_ACCOUNT_UNSET_VAL="UNSET";
IBM_ACCOUNT_FOLDER_FULL_PATH="$IBM_ACCOUNT_UNSET_VAL";

installIbmCloudCliIfNeeded(){
    # install IBM specific openshift plugins
    IBM_CLOUD_CLI_VERSION=$(findTagValueInCommandOutput "ibmcloud version" "ibmcloud -v" "true");
    if [[ -z "$IBM_CLOUD_CLI_VERSION" ]]; then
        curl -sL https://ibm.biz/idt-installer | bash;
    fi
}

ensureLoggedIn(){
    echo "You are about to log in to IBM Cloud.";
    echo "If you do not have an IBM Cloud account yet, you will need to acquire one for the next step.";
    echo "[CTRL]-[C] to exit."
    echo "As a BC Gov cluster admin, you will be given 2 account selection options; your personal account (dev) and the BC Gov account (prod).";
    echo "Whichever account you choose to use, your terraform configs will be different due to different cloud resources being assigned to each account, so make sure you choose carefully which account you use."
    ibmcloud login;
}

ensureAccountFolder(){
    if [[ "$IBM_ACCOUNT_FOLDER_FULL_PATH" == "$IBM_ACCOUNT_UNSET_VAL" ]]; then
        local _current_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
        local _account_id=`ibmcloud account show --output json | jq -r .account_id`;
        local _account_folder_name=`echo -n "$_account_id" | openssl whirlpool | cut -c-32`;
        local _account_subpath="../account";
        IBM_ACCOUNT_FOLDER_FULL_PATH="$_current_dir/$_account_subpath/$_account_folder_name";
    fi
}

createIbmAccountStructureIfNeeded(){
    # IBM Cloud provisions by account, so depending on which account a user is 
    # logged into, the available infrastructure will be different, requiring 
    # different Terraform scripts.  We need to separate those by account.
    local _current_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
    ensureAccountFolder;
    if [[ ! -e "$IBM_ACCOUNT_FOLDER_FULL_PATH" ]]; then
        mkdir -p "$IBM_ACCOUNT_FOLDER_FULL_PATH/cluster";
        cp "$_current_dir/openshift.tf.template" "$IBM_ACCOUNT_FOLDER_FULL_PATH/cluster/openshift.tf";
    fi
}

createIbmApiKeyIfNeeded(){
    ensureAccountFolder;
    local _ibmcloud_settings_filename="$IBM_API_KEY_FILENAME";
    local _ibmcloud_settings_full_path="$IBM_ACCOUNT_FOLDER_FULL_PATH/$_ibmcloud_settings_filename";

    if [[ ! -e "$_ibmcloud_settings_full_path" ]]; then
        ibmcloud iam api-key-create IbmCloudApi -d "API key for passwordless application access" --file $_ibmcloud_settings_full_path;
    fi
}

installIbmTerraformPluginsIfNeeded(){
    # install IBM specific terraform plugins
    local _current_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
    ensureAccountFolder;
    local _cluster_fullpath="$IBM_ACCOUNT_FOLDER_FULL_PATH/cluster";

    local _terraform_installer=unset;
    local _terraform_installer_file=unset;

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OSX
        _terraform_installer=darwin_amd64;
    # Will be using the subsystem for now
    elif [[ "$OSTYPE" == "cygwin"* || "$OSTYPE" == "msys"* || "$OSTYPE" == "win"* ]]; then
        # POSIX compatibility layer and Linux environment emulation for Windows
        # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
        _terraform_installer=windows_amd64;
    elif [[ "$OSTYPE" == "bsd"* || "$OSTYPE" == "solaris"* ]]; then
        # not supported
        echo -e \\n"OS not supported. Supported OS:\\nMac OSX\\nDebian\\nFedora\\n"\\n;
        exit 1;
    else
        local _idlike="$(grep 'ID_LIKE=\|ID=' /etc/os-release | awk -F '=' '{print $2}')";
        if [[ "$_idlike" == *"debian"* ]]; then
            # Debian base like Ubuntu
            _terraform_installer=linux_amd64;
        elif [[ "$_idlike" == *"fedora"* ]]; then
            # Fedora base like CentOS or RHEL
            _terraform_installer=linux_amd64;
        else
            echo -e \\n"OS not detected. Supported OS:\\nMac OSX\\nDebian\\nFedora\\n"\\n;
            exit 1;
        fi
    fi
    local _target_ibm_cloud_tf_plugin_version="1.5.3";

    local _terraform_plugin_dir=$_cluster_fullpath/.terraform/plugins/$_terraform_installer;
    mkdir -p $_terraform_plugin_dir;
    _terraform_installer_file="$_terraform_installer.zip";
    ensureTargetIbmTerraformPlugin "$OSTYPE" "$_terraform_plugin_dir" "$_target_ibm_cloud_tf_plugin_version" "$_terraform_installer_file" "check";
    # additionally to the local installation of the Terraform IBM plugin above
    # we are going to always ensure that the plugin for linux_amd64 is always installed
    # so that the plugin will be present for usage in Terraform Cloud.
    local _terraform_installer_for_tf_cloud=linux_amd64;
    local _terraform_plugin_dir_for_tf_cloud=$_cluster_fullpath/.terraform/plugins/$_terraform_installer_for_tf_cloud;
    mkdir -p $_terraform_plugin_dir_for_tf_cloud;
    local _terraform_installer_for_tf_cloud_file="$_terraform_installer_for_tf_cloud.zip";
    ensureTargetIbmTerraformPlugin "$OSTYPE" "$_terraform_plugin_dir_for_tf_cloud" "$_target_ibm_cloud_tf_plugin_version" "$_terraform_installer_for_tf_cloud_file" "skip";
}

ensureTargetIbmTerraformPlugin(){
    local _ostype=$1;
    local _terraform_plugin_dir=$2;
    local _target_ibm_cloud_tf_plugin_versions=$3;
    local _terraform_installer=$4;
    local _skip_check=$5; # "skip" to skip the check
    # install IBM specific terraform plugins
    rm -f $_terraform_installer*;
    local _ibm_cloud_tf_already_installed=$(find $_terraform_plugin_dir -maxdepth 1 -name "*$_target_ibm_cloud_tf_plugin_versions*" -print);
    if [[ -z "$_ibm_cloud_tf_already_installed" ]]; then
        wget https://github.com/IBM-Cloud/terraform-provider-ibm/releases/download/v$_target_ibm_cloud_tf_plugin_versions/$_terraform_installer;
        echo "n" | unzip $_terraform_installer -d $_terraform_plugin_dir;
        printf "\n";
        rm -f ./$_terraform_installer;
        rm -f $_terraform_plugin_dir/*.sig;
        ls $_terraform_plugin_dir | grep -v '\.pem$' | chmod +rx;
        if [[ "skip" != "$_skip_check" ]]; then
            local _current_ibm_cloud_tf_plugin_versions=$(findTagValueInCommandOutput "IBM Cloud Provider version" "$_terraform_plugin_dir/terraform-provider-ibm_* 2>&1 >/dev/null" "true");
            if [[ "$_current_ibm_cloud_tf_plugin_versions" != "$_target_ibm_cloud_tf_plugin_versions" ]]; then
                local _install_problem="Looks like the IBM Cloud Terraform Plugin didn't respond correctly after installing.";
                if [[ "$_ostype" == "darwin"* ]]; then
                    echo -e \\n"$_install_problem\\nOn Mac OS Catalina and above, your first time installing will likely fail with a security warning.\\nGo to your Mac's System Preferences, Security & Privacy, General and allow terraform-provider-ibm*\\n"
                else
                    echo -e \\n"$_install_problem\\n"
                fi
            fi
        fi
    fi
}

createIbmTerraformSettingsIfNeeded(){
    local _current_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
    ensureAccountFolder;
    local _cluster_fullpath="$IBM_ACCOUNT_FOLDER_FULL_PATH/cluster";
    local _tfvars_filename="ibm.auto.tfvars";
    local _tfvars_full_path="$_cluster_fullpath/$_tfvars_filename";

    cd $_cluster_fullpath;
    terraform init;
    local _tfvars_template_filename="ibm.auto.tfvars.template";
    local _tfvars_template_full_path="$_current_dir/$_tfvars_template_filename";
    cp "$_tfvars_template_full_path" "$_tfvars_full_path";
    local _api_key=`jq -r '.apikey' $IBM_ACCOUNT_FOLDER_FULL_PATH/$IBM_API_KEY_FILENAME`;
    local _tfvars_contents=$(<$_tfvars_full_path);
    local _api_key_placeholder="<ibmcloud_api_key>";
    local _tfvars_contents=${_tfvars_contents/$_api_key_placeholder/$_api_key};
    echo "$_tfvars_contents" > $_tfvars_full_path;
    cd $_current_dir;
}

initializeOpenshiftTfVlansIfNeeded(){
    local _current_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
    ensureAccountFolder;
    local _cluster_fullpath="$IBM_ACCOUNT_FOLDER_FULL_PATH/cluster";
    local _openshift_tf_filename="openshift.tf";
    local _openshift_tf_full_path="$_cluster_fullpath/$_openshift_tf_filename";
    local _public_vlan_placeholder="<public_vlan_ID>";
    local _private_vlan_placeholder="<private_vlan_ID>";
    local _openshift_tf_contents=$(<$_openshift_tf_full_path);
    local _start_tag='"cluster" {';
    local _end_tag="\n}";
    local _cluster_resource_block=${_openshift_tf_contents#*${_start_tag}};
    _cluster_resource_block=${_cluster_resource_block%%${_end_tag}*};
    local _datacenter=${_cluster_resource_block#*${_start_tag}};
    _datacenter=`echo "$_datacenter" | pcregrep -Mi -o1 "datacenter\h*=\h*\"(.*)\"\n"`;
    setVlanValueInOpenshiftTfFileIfNeeded "$_openshift_tf_full_path" "$_cluster_resource_block" "$_datacenter" "public" "public_vlan_id" "<public_vlan_ID>";
    setVlanValueInOpenshiftTfFileIfNeeded "$_openshift_tf_full_path" "$_cluster_resource_block" "$_datacenter" "private" "private_vlan_id" "<private_vlan_ID>";
}

setVlanValueInOpenshiftTfFileIfNeeded(){
    local _settings_tf_full_path=$1;
    local _cluster_resource_block=$2;
    local _zone=$3;
    local _type=$4;
    local _vlan_field_name=$5;
    local _vlan_placeholder=$6;
    local _vlan_replace_target="$_vlan_placeholder";
    local _settings_tf_contents=$(<$_settings_tf_full_path);
    local _vlan=`ibmcloud oc vlans -zone "$_zone" --json | jq -r -c ".[] | select( .type == \"$_type\" ) | .id"`;
    if ! grep -q "$_vlan_placeholder" "$_settings_tf_full_path"; then
        _vlan_replace_target=`echo "$_cluster_resource_block" | pcregrep -Mi -o1 "$_vlan_field_name\h*=\h*\"(.*)\"\n"`;
    fi
    _settings_tf_contents=${_settings_tf_contents/$_vlan_replace_target/$_vlan};
    echo "$_settings_tf_contents" > $_settings_tf_full_path;
}

installPythonIfNeeded(){
    local _current_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
    cd "$_current_dir/..";
    local _python_tag="python ";
    local _python_target_version=$(findTagValueInFile "$_python_tag" ".tool-versions");

    if [[ ! -z "$_python_target_version" ]]; then
        local _python_current_version=$(findTagValueInCommandOutput "Python" "python -V");
        if [[ "$_python_current_version" != "$_python_target_version" ]]; then
            echo "handling python version '${_python_target_version}'";
            source "${PROFILE_FILE}";
            asdf install python $_python_target_version;
            asdf reshim python;
        fi
    fi
    cd "$_current_dir";
}

installAnsibleIfNeeded(){
    local _current_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
    cd "$_current_dir/..";
    if [[ ! -e "get-pip.py" ]]; then
        curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py;
        python get-pip.py --user;
        python -m virtualenv ansible;
        source ansible/bin/activate;
        pip install ansible;
        pip install openshift;
    fi
    cd "$_current_dir";
}


handleOrderDependentIbmCloudTerraformSetups(){
    installIbmCloudCliIfNeeded;
    installTerraformIfNeeded;
    ensureLoggedIn;
    createIbmAccountStructureIfNeeded;
    createIbmApiKeyIfNeeded;
    installIbmTerraformPluginsIfNeeded;
    createIbmTerraformSettingsIfNeeded;
    initializeOpenshiftTfVlansIfNeeded;
    installPythonIfNeeded;
    installAnsibleIfNeeded;
}