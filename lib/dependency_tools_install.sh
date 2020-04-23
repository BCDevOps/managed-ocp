DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
source "$DIR/dependency_tools_helper.sh";

PACKAGE_MANAGER="";

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OSX
    PACKAGE_MANAGER="brew";
# Will be using the subsystem for now
elif [[ "$OSTYPE" == "cygwin"* || "$OSTYPE" == "msys"* || "$OSTYPE" == "win"* ]]; then
    # POSIX compatibility layer and Linux environment emulation for Windows
    # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
    PACKAGE_MANAGER="choco";
elif [[ "$OSTYPE" == "bsd"* || "$OSTYPE" == "solaris"* ]]; then
    # not supported
    echo -e \\n"OS not supported. Supported OS:\\nMac OSX\\nDebian\\nFedora\\n"\\n;
    exit 1;
else
    IDLIKE="$(grep ID_LIKE /etc/os-release | awk -F '=' '{print $2}')";
    if [[ "$IDLIKE" == *"debian"* ]]; then
        # Debian base like Ubuntu
        PACKAGE_MANAGER="apt";
    elif [[ "$IDLIKE" == *"fedora"* ]]; then
        # Fedora base like CentOS or RHEL
        PACKAGE_MANAGER="yum";
    else
        echo -e \\n"OS not detected. Supported OS:\\nMac OSX\\nDebian\\nFedora\\n"\\n;
        exit 1;
    fi
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
    brew cask install visual-studio-code;
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
    sudo yum -y install coreutils automake autoconf openssl libtool unixodbc make jq unzip curl git;
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
    sudo apt-get update;
    sudo apt-get -y install build-essential coreutils automake autoconf openssl libtool unixodbc unzip curl git make jq;
else
    echo -e \\n"Packages not installed.\\n"\\n
    exit 1;
fi

source "$DIR/vscodeextensions.txt";

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