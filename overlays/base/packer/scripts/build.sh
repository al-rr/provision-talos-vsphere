#!/bin/bash


var_files=("vsphere_vars" "build_vars" "ansible_vars" "proxy_vars" "common_vars" "network_vars" "BUILD_VARS")
validate_linux_username "$config_path/build.pkrvars.hcl"
printf "Starting the build of %s %s...\n\n" "$dist" "$version"
command="packer build -force -on-error=ask $debug_option"

for var_file in "${var_files[@]}"; do
    command+=" -var-file=\"$config_path/${!var_file}\""
done

command+=" \"$INPUT_PATH\""

if [ $show_command -eq 1 ]; then
    printf "\n"
    printf "\n\033[32mThe following command is ran for this build:\033[0m\n"
    printf "\n\e[34m%s\e[0m\n" "$command"
fi
