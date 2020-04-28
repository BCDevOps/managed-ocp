#!/bin/bash
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
source "$DIR/../../../lib/setup_helper.sh";

IBM_API_KEY_NAME="IbmCloudApi";

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

createIbmApiKeyIfNeeded(){
    if [[ ! -e "$IBM_API_KEY_NAME.json" ]]; then
        echo "\\nYou are about to log in to IBM Cloud.\\nIf you do not have an IBM Cloud account yet, you will need to acquire one for the next step.\\n[CTRL]-[C] to exit."
        ibmcloud login;
        ibmcloud iam api-key-create IbmCloudApi -d "API key for passwordless application access" --file IbmCloudApi.json
    fi
}

createIbmTerraformSettingsIfNeeded(){
    local _current_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
    local _tfvars_filename="ibm.tfvars";
    local _tfvars_full_path="$_current_dir/../cluster/$_tfvars_filename";
    
    if [[ ! -e "$_tfvars_full_path" ]]; then
        local _tfvars_template_filename="ibm.tfvars.template";
        local _tfvars_template_full_path="$_current_dir/$_tfvars_template_filename";
        cp "$_tfvars_template_full_path" "$_tfvars_full_path";
        local _ibmcloud_settings_filename="IbmCloudApi.json";
        local _api_key=`jq -r '.id' $_current_dir/../$_ibmcloud_settings_filename`;
        local _tfvars_contents=$(<$_tfvars_full_path);
        local _api_key_placeholder="<ibmcloud_api_key>";
        echo "${_tfvars_contents/$_api_key_placeholder/$_api_key}" > $_tfvars_full_path;
    fi
}
