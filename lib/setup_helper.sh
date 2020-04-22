source ./shell_helper.sh;

findTagValueInFile(){
    local _tag=$1;
    local _file=$2;

    local _tag_find="sed -n -e 's/^.*${_tag}//p' ${_file}";
    local _tag_value=$(eval $_tag_find);
    if [ ! -z "${_tag_value}" ]; then
      _tag_value=${_tag_value//[\"\,]/""};
      _tag_value=$(echo $_tag_value | sed -e 's/^[[:space:]]*//');
      echo "$_tag_value";
    else
      echo "";
    fi
}

findTagValueInCommandOutput(){
    local _tag=$1;
    local _command_string=$2;
    local _no_label_in_command=$3;

    local _tag_for_sed=${_tag//[\/]/"\\/"};

    local _tag_find="${_command_string}";
    if [ ! -z "${_no_label_in_command}" ]; then
      _tag_find="${_command_string} | sed -n -e 's/^.*${_tag_for_sed}//p'";
    fi

    local _tag_value=$(eval $_tag_find);
    _tag_value=$(echo $_tag_value | cut -d $'\t' -f 1);
    _tag_value=$(echo $_tag_value | cut -d ' ' -f 1);
    _tag_value=${_tag_value//[\"\,]/""};
    _tag_value=$(echo $_tag_value | sed -e 's/^[[:space:]]*//');
    echo "$_tag_value";
}

# Examples:
# installNpmModuleIfNeeded "@angular/cli" "package.json" "ng -v";
# installNpmModuleIfNeeded "typescript" "package.json" "ng -v";
# installNpmModuleIfNeeded "tslint" "package.json" "tslint -v" "true";
installNpmModuleIfNeeded(){
    local _module_label=$1;
    local _file_containing_targets=$2;
    local _command_listing_current=$3;
    local _no_label_in_command=$4;

    _module_label_for_tag=${_module_label//[\/]/"\\/"};

    local _tag="\"${_module_label_for_tag}\": \"";
    local _target_version=$(findTagValueInFile "$_tag" "$_file_containing_targets");
    local _current_version=$(findTagValueInCommandOutput "$_module_label" "$_command_listing_current" "$_no_label_in_command");

    local _target_compare="${_target_version}";
    local _current_compare="${_current_version}";
    if [[ $_target_version =~ ^\^.* ]]; then
      _target_version="${_target_version:1}";
      _target_compare=$(echo $_target_version | cut -d '.' -f 1);
      _current_compare=$(echo $_current_version | cut -d '.' -f 1);
    elif [[ $_target_version =~ ^\~.* ]]; then
      _target_version="${_target_version:1}";
      _target_compare=$(echo $_target_version | cut -d '.' -f 1,2);
      _current_compare=$(echo $_current_version | cut -d '.' -f 1,2);
    fi

    if [[ "$_current_compare" != "$_target_compare" ]]; then
      eval "npm i -g ${_module_label_for_tag}@'${_target_compare}';";
    fi
}

javaProfileWriter(){
    local _profile_file=$1;
    if [[ -z "$_profile_file" ]]; then
      echo -e "No profile file set";
      return;
    fi
    if [[ ! -e "$_profile_file" ]]
    then
        touch "$_profile_file";
    fi
    if ! grep "asdf current java" "$_profile_file"; then
        echo "asdf current java 2>&1 > /dev/null;" >> "$_profile_file";
        echo "if [[ "\$?" -eq 0 ]]" >> "$_profile_file";
        echo "then" >> "$_profile_file";
        echo "    export JAVA_HOME=$(asdf where java);" >> "$_profile_file";
        echo "fi" >> "$_profile_file";
    fi
    source "$_profile_file";
}

installNodeIfNeeded(){
  NODEJS_TAG="nodejs ";
  NODEJS_TARGET_VERSION=$(findTagValueInFile "$NODEJS_TAG" ".tool-versions");

  if [[ ! -z "$NODEJS_TARGET_VERSION" ]]; then
    NODEJS_CURRENT_VERSION=$(findTagValueInCommandOutput "v" "node -v");
    if [[ "$NODEJS_CURRENT_VERSION" != "$NODEJS_TARGET_VERSION" ]]; then
      echo "handling node version '${NODEJS_TARGET_VERSION}'";
      source "$_profile_file";
      asdf install nodejs $NODEJS_TARGET_VERSION;
      asdf reshim nodejs;
    fi
  fi
}

installJavaIfNeeded(){
  JAVA_TAG="java ";
  JAVA_PACKAGE_TAG="openjdk-";
  JAVA_TARGET_VERSION=$(findTagValueInFile "$JAVA_TAG" ".tool-versions");  # this will output adopt-openjdk-11.0.4+11.4
  
  if [[ ! -z "$JAVA_TARGET_VERSION" ]]; then
    JAVA_CURRENT_VERSION=$(findTagValueInCommandOutput "$JAVA_PACKAGE_TAG" "asdf current java");  # this will output a number 11.0.4
    JAVA_CURRENT_MAJOR_VERSION=$(echo $JAVA_TARGET_VERSION | cut -d '.' -f 1,2);   # 11.0
    
    if [[ "$JAVA_CURRENT_VERSION" != "$JAVA_TARGET_VERSION" ]]; then
      JAVA_TARGET_MAJOR_VERSION=$(echo $JAVA_TARGET_VERSION | cut -d '.' -f 1,2 | rev | cut -d '-' -f 1 | rev);  # 11.0
      
      if [[ ! -z "$JAVA_TARGET_MAJOR_VERSION" ]]; then
        JAVA_TARGET_NAME=$(asdf list-all java | grep -v "_openj" | grep "$JAVA_PACKAGE_TAG$JAVA_TARGET_MAJOR_VERSION" | tail -1);  # possible multiline output, get last line
        
        if [[ ! -z "$JAVA_TARGET_NAME" ]]; then
          echo "handling java version '${JAVA_TARGET_NAME}'";
          #brew cask uninstall java;
          #brew uninstall jenv;  # then restart your machine
          asdf install java "$JAVA_TARGET_NAME";
          asdf reshim java;
        fi
      fi
    fi
    javaProfileWriter "${PROFILE_FILE}";
    javaProfileWriter "${RC_FILE}";
  fi
}

installGradleIfNeeded(){
  GRADLE_TAG="gradle ";
  GRADLE_TARGET_VERSION=$(findTagValueInFile "$GRADLE_TAG" ".tool-versions");

  if [[ ! -z "$GRADLE_TARGET_VERSION" ]]; then
    GRADLE_CURRENT_VERSION=$(findTagValueInCommandOutput "Gradle" "gradle -v");
    if [[ "$GRADLE_CURRENT_VERSION" != "$GRADLE_TARGET_VERSION" ]]; then
      echo "handling gradle version '${GRADLE_TARGET_VERSION}'";
      asdf install gradle $GRADLE_TARGET_VERSION;
      asdf reshim gradle;
    fi
  fi
}

installTerraformIfNeeded(){
  TERRAFORM_TAG="terraform ";
  TERRAFORM_TARGET_VERSION=$(findTagValueInFile "$TERRAFORM_TAG" ".tool-versions");

  if [[ ! -z "$TERRAFORM_TARGET_VERSION" ]]; then
    TERRAFORM_CURRENT_VERSION=$(findTagValueInCommandOutput "Usage: terraform" "terraform");
    if [[ "$TERRAFORM_CURRENT_VERSION" != "$TERRAFORM_TARGET_VERSION" ]]; then
      echo "handling terraform version '${TERRAFORM_TARGET_VERSION}'";
      asdf install terraform $TERRAFORM_TARGET_VERSION;
      asdf reshim terraform;
    fi
  fi
}

checkDependencies(){
  if [[ ! -d ~/.asdf ]]
  then
      echo -e \\n"Prerequisites not installed.\\nPlease run the prerequisites script here: https://github.com/bcgov/eagle-dev-guides/blob/master/dev_guides/node_npm_requirements.md\\n"\\n;
      exit 1;
  fi

  if [[ ! -e .tool-versions ]]
  then
      echo -e \\n".tool-versions file not present.\\nPlease run this script in the root folder of the project.\\n"\\n;
      exit 1;
  fi
}

cleanModules(){
  if [[ -e ./node_modules ]]; then rm -Rf ./node_modules; fi
  if [[ -e ./*.lock ]]; then rm ./*.lock; fi
  mkdir node_modules;
}