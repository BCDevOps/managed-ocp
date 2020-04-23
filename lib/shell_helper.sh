CURRENT_SHELL=$(echo $0);
PROFILE_FILE=$(echo ~/.bash_profile);
RC_FILE=$(echo ~/.bashrc);
if [[ "${CURRENT_SHELL}" == "zsh" ]]; then
    PROFILE_FILE=$(~/.zprofile);
    RC_FILE=$(~/.zshrc);
fi
