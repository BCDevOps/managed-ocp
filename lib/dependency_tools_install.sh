source ./dependency_tools_helper.sh;

PACKAGE_MANAGER="";
IDLIKE="$(grep ID_LIKE /etc/os-release | awk -F '=' '{print $2}')"

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OSX
    PACKAGE_MANAGER="brew";
# Will be using the subsystem for now
elif [[ "$OSTYPE" == "cygwin"* || "$OSTYPE" == "msys"* || "$OSTYPE" == "win"* ]]; then
    # POSIX compatibility layer and Linux environment emulation for Windows
    # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
    PACKAGE_MANAGER="choco";
elif [[ "$IDLIKE" == *"debian"* ]]; then
    # Debian base like Ubuntu
    PACKAGE_MANAGER="apt";
elif [[ "$IDLIKE" == *"fedora"* ]]; then
    # Fedora base like CentOS or RHEL
    PACKAGE_MANAGER="yum";
elif [[ "$OSTYPE" == "bsd"* || "$OSTYPE" == "solaris"* ]]; then
    # not supported
    echo -e \\n"OS not supported. Supported OS:\\nMac OSX\\nDebian\\nFedora\\n"\\n;
    exit 1;
else
    echo -e \\n"OS not detected. Supported OS:\\nMac OSX\\nDebian\\nFedora\\n"\\n;
    exit 1;
fi


if [[ "$PACKAGE_MANAGER" == "brew" ]]; then
    which -s brew;
    if [[ $? != 0 ]] ; then
        # Install Homebrew
        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)";
    fi
    brew update;
    brew install coreutils automake autoconf openssl \
    libyaml readline libxslt libtool unixodbc \
    unzip curl \
    git make;
    brew tap mongodb/brew;
    brew install mongodb-community@3.6;
    brew services start mongodb-community;
    brew cask install visual-studio-code;
    brew install openshift-cli@3.11.0;
elif [[ "$PACKAGE_MANAGER" == "choco" ]]; then
    sudo PowerShell -NoProfile -ExecutionPolicy remotesigned -Command ". 'install_choco.ps1;";
    choco upgrade chocolatey;
    choco install git vscode make -y;
elif [[ "$PACKAGE_MANAGER" == "yum" ]]; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc;
    sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo';
    yum check-update;
    sudo yum -y install code;
    sudo yum -y install epel-release;
    sudo yum -y install coreutils automake autoconf openssl libtool unixodbc make jq unzip curl git mongodb-server mongodb;
    # OpenShift client install
    curl -LO https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz
    tar zxvf openshift-origin-client-tools*
    sudo mv openshift-origin-client-tools*/oc /usr/local/bin/
    rm -rf openshift-origin-client-tools*
elif [[ "$PACKAGE_MANAGER" == "apt" ]]; then
    sudo apt-get update && sudo apt-get -y upgrade;
     # This here is for vscode
    sudo apt-get -y install software-properties-common apt-transport-https wget
    wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
    sudo apt-get update;
    sudo apt-get -y install code;
    sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/;
    sudo apt-get -y install apt-transport-https;
    #sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10;
    #echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list
    sudo apt-get update;
    sudo apt-get -y install build-essential coreutils automake autoconf openssl libtool unixodbc unzip curl git mongodb make jq;
    # OpenShift client install
    curl -LO https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz
    tar zxvf openshift-origin-client-tools*
    sudo mv openshift-origin-client-tools*/oc /usr/local/bin/
    rm -rf openshift-origin-client-tools*

else
    echo -e \\n"Packages not installed.\\n"\\n
    exit 1;
fi

source ../vscodeextensions.txt;

envProfileSettings "${PROFILE_FILE}";
envProfileSettings "${RC_FILE}";

if [[ ! -d ~/.asdf ]]; then
    if [[ "$PACKAGE_MANAGER" == "brew" ]]; then
        brew install asdf;
        asdfProfileSettings "${PROFILE_FILE}";
        asdfProfileSettings "${RC_FILE}";
        brew upgrade asdf;
        chmod +x /usr/local/opt/asdf/asdf.sh;
        chmod +x /usr/local/opt/asdf/etc/bash_completion.d/asdf.bash;
    else
        git clone https://github.com/asdf-vm/asdf.git ~/.asdf;
        cd ~/.asdf;
        git checkout "$(git describe --abbrev=0 --tags)";
        asdfProfileSettings "${PROFILE_FILE}";
        asdfProfileSettings "${RC_FILE}";
        asdf update;
    fi
else
    asdfProfileSettings "${PROFILE_FILE}";
    asdfProfileSettings "${RC_FILE}";
fi

asdf plugin-add terraform https://github.com/Banno/asdf-hashicorp.git;

echo "Finished installing developer prerequisites";