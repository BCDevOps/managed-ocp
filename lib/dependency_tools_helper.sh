DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd );
source "$DIR/shell_helper.sh";

asdfProfileWriterBrew(){
    local _profile_file=$1;
    if [[ ! -e "$_profile_file" ]]; then
        touch "$_profile_file";
    fi
    if ! grep "/asdf.sh" "$_profile_file"; then
        echo -e "\\n. $(brew --prefix asdf)/asdf.sh" >> "$_profile_file";
    fi
    if ! grep "/asdf.bash" "$_profile_file"; then
        echo -e "\\n. $(brew --prefix asdf)/etc/bash_completion.d/asdf.bash" >> "$_profile_file";
    fi
}

asdfProfileWriterNonBrew(){
    local _profile_file=$1;
    if [[ ! -e "$_profile_file" ]]; then
        touch "$_profile_file";
    fi
    if ! grep "/asdf.sh" "$_profile_file"; then
        echo -e "\\n. $HOME/.asdf/asdf.sh" >> "$_profile_file";
    fi
    if ! grep "/asdf.bash" "$_profile_file"; then
        echo -e "\\n. $HOME/.asdf/completions/asdf.bash" >> "$_profile_file";
    fi
    source "$_profile_file";
}

asdfProfileSettings(){
    local _profile_file=$1;
    local _profile_file_before=$(date -r "$_profile_file" "+%m-%d-%Y %H:%M:%S");
    if [[ "$PACKAGE_MANAGER" == "brew" ]]; then
        asdfProfileWriterBrew "$_profile_file";
    else
        asdfProfileWriterNonBrew "$_profile_file";
    fi
    if ! grep "/.asdf/shims" "$_profile_file"; then
        echo '[[ ":$PATH:" != *"$HOME/.asdf/shims:"* ]] && export PATH="$HOME/.asdf/shims:$PATH"' >> "$_profile_file";
    fi
    local _profile_file_after=$(date -r "$_profile_file" "+%m-%d-%Y %H:%M:%S");
    if [[ "$_profile_file_before" != "$_profile_file_after" ]]; then source "$_profile_file"; fi
}

envProfileSettings(){
    local _profile_file=$1;
    if [[ ! -e "$_profile_file" ]]; then
        touch "$_profile_file";
    fi
    local _profile_file_before=$(date -r "$_profile_file" "+%m-%d-%Y %H:%M:%S");
    if ! grep "export SOME_TERRAFORM_SETTING=" "$_profile_file"; then
        echo "export SOME_TERRAFORM_SETTING=\"some_value\"" >> "$_profile_file";
    fi

    local _profile_file_after=$(date -r "$_profile_file" "+%m-%d-%Y %H:%M:%S");
    if [[ "$_profile_file_before" != "$_profile_file_after" ]]; then source "$_profile_file"; fi
}