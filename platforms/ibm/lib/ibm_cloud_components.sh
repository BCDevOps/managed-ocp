#!/bin/bash
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
source "$DIR/../../../lib/setup_helper.sh";

IBM_API_KEY_NAME="IbmCloudApi";
IBM_API_KEY_FILENAME="$IBM_API_KEY_NAME.json";
IBM_ACCOUNT_UNSET_VAL="UNSET";
IBM_ACCOUNT_FOLDER_FULL_PATH="$IBM_ACCOUNT_UNSET_VAL";

installIbmTerraformPluginsIfNeeded(){
    # install IBM specific terraform plugins
    TERRAFORM_PLUGIN_DIR=$HOME/.terraform.d/plugins;
    mkdir -p $TERRAFORM_PLUGIN_DIR;
    TERRAFORM_INSTALLER=unset;

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OSX
        TERRAFORM_INSTALLER=darwin_amd64.zip;
    # Will be using the subsystem for now
    elif [[ "$OSTYPE" == "cygwin"* || "$OSTYPE" == "msys"* || "$OSTYPE" == "win"* ]]; then
        # POSIX compatibility layer and Linux environment emulation for Windows
        # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
        TERRAFORM_INSTALLER=windows_amd64.zip;
    elif [[ "$OSTYPE" == "bsd"* || "$OSTYPE" == "solaris"* ]]; then
        # not supported
        echo -e \\n"OS not supported. Supported OS:\\nMac OSX\\nDebian\\nFedora\\n"\\n;
        exit 1;
    else
        IDLIKE="$(grep ID_LIKE /etc/os-release | awk -F '=' '{print $2}')";
        if [[ "$IDLIKE" == *"debian"* ]]; then
            # Debian base like Ubuntu
            TERRAFORM_INSTALLER=linux_amd64.zip;
        elif [[ "$IDLIKE" == *"fedora"* ]]; then
            # Fedora base like CentOS or RHEL
            TERRAFORM_INSTALLER=linux_amd64.zip;
        else
            echo -e \\n"OS not detected. Supported OS:\\nMac OSX\\nDebian\\nFedora\\n"\\n;
            exit 1;
        fi
    fi
    rm -f $TERRAFORM_INSTALLER*;
    TARGET_IBM_CLOUD_TF_PLUGIN_VERSION="1.4.0";
    IBM_CLOUD_TF_ALREADY_INSTALLED=$(find $TERRAFORM_PLUGIN_DIR -maxdepth 1 -name "*$TARGET_IBM_CLOUD_TF_PLUGIN_VERSION*" -print);
    if [[ -z "$IBM_CLOUD_TF_ALREADY_INSTALLED" ]]; then
        wget https://github.com/IBM-Cloud/terraform-provider-ibm/releases/download/v$TARGET_IBM_CLOUD_TF_PLUGIN_VERSION/$TERRAFORM_INSTALLER;
        echo "n" | unzip $TERRAFORM_INSTALLER -d $TERRAFORM_PLUGIN_DIR;
        printf "\n";
        rm -f ./$TERRAFORM_INSTALLER;

        CURRENT_IBM_CLOUD_TF_PLUGIN_VERSION=$(findTagValueInCommandOutput "IBM Cloud Provider version" "$TERRAFORM_PLUGIN_DIR/terraform-provider-ibm_* 2>&1 >/dev/null" "true");
        if [[ "$CURRENT_IBM_CLOUD_TF_PLUGIN_VERSION" != "$TARGET_IBM_CLOUD_TF_PLUGIN_VERSION" ]]; then
            local _install_problem="Looks like the IBM Cloud Terraform Plugin didn't respond correctly after installing.";
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo -e \\n"$_install_problem\\nOn Mac OS Catalina and above, your first time installing will likely fail with a security warning.\\nGo to your Mac's System Preferences, Security & Privacy, General and allow terraform-provider-ibm*\\n"
            else
                echo -e \\n"$_install_problem\\n"
            fi
        fi
    fi
}

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

createIbmTerraformSettingsIfNeeded(){
    local _current_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
    ensureAccountFolder;
    local _cluster_fullpath="$IBM_ACCOUNT_FOLDER_FULL_PATH/cluster";
    local _tfvars_filename="ibm.auto.tfvars";
    local _tfvars_full_path="$_cluster_fullpath/$_tfvars_filename";

    if [[ ! -e "$_tfvars_full_path" ]]; then
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
    fi
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
    installIbmTerraformPluginsIfNeeded;
    ensureLoggedIn;
    createIbmAccountStructureIfNeeded;
    createIbmApiKeyIfNeeded;
    createIbmTerraformSettingsIfNeeded;
    initializeOpenshiftTfVlansIfNeeded;
    installPythonIfNeeded;
    installAnsibleIfNeeded;
}