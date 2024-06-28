#!/bin/bash

set -euo pipefail
source ./lifecycle/functions.sh

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname -- "${SCRIPT_PATH}")

if [[ "${_CONTAINER_USER}" == "root" ]]; then
    notify "ERROR" "Define containerUser in devcontainer.json"
    notify "WARNING" "Possibly one of these users:"
    POSSIBLE_USERS=$(ls -1 /home/)
    notify "INFO" "${POSSIBLE_USERS}"
    exit 1
fi

echo "CONTAINER USER = ${_CONTAINER_USER}"
sleep 5;

reset_dir_as "/opt/neovim" "${_CONTAINER_USER}" || exit 1

# Handle BUILD_TYPE
case "${BUILD_TYPE}" in
    source)
        notify "TASK" "Build Neovim from source"
        install_build_dependencies
        # placeholder for post scripts
        from_link_to "/opt/neovim/neovim/build/bin/nvim" "/usr/local/bin/nvim"

        notify "INFO" "Proceeding as ${_CONTAINER_USER}..."
        su "${_CONTAINER_USER}" -c "source ./lifecycle/functions.sh; cd /opt/neovim; build_neovim" || exit 1
        ;;
    appimage)
        notify "TASK" "Use nvim.appimage:${VERSION}"
        install_appimage_dependencies
        APPIMAGE_WRAPPER_SCRIPT="/opt/neovim/nvim"
        # placeholder for post scripts
        from_link_to ${APPIMAGE_WRAPPER_SCRIPT} "/usr/local/bin/nvim"
        su "${_CONTAINER_USER}" -c "source ./lifecycle/functions.sh; cd /opt/neovim; fetch_nvim_appimage ${APPIMAGE_WRAPPER_SCRIPT}" || exit 1
        ;;
    prebuilt)
        notify "TASK" "Use nvim-linux64:${VERSION}"
        install_prebuilt_dependencies
        PREBUILT_BIN="/opt/neovim/nvim-linux64/bin/nvim"
        # placeholder for post scripts
        from_link_to ${PREBUILT_BIN} "/usr/local/bin/nvim"
        su "${_CONTAINER_USER}" -c "source ./lifecycle/functions.sh; cd /opt/neovim; fetch_nvim_prebuilt ${PREBUILT_BIN}" || exit 1
        ;;
    apt)
        use_apt_ppa || exit 1
        ;;
    *)
        notify "ERROR" "Build type not recognized" && exit 1
esac

# Handle NVIM_CONFIG
NVIM_CONF_FOLDER="$_CONTAINER_USER_HOME/.config/nvim"
su "${_CONTAINER_USER}" -c "rm -rf ${NVIM_CONF_FOLDER}"

case "${NVIM_CONFIG}" in
    host)
        notify "TASK" "Set up configuration to mirror host's"
        install_common_config_packages
        NVIM_CONF_HOST="/media/nvim_host"
        su "${_CONTAINER_USER}" -c "source ./lifecycle/functions.sh; setup_config_host ${NVIM_CONF_HOST} ${NVIM_CONF_FOLDER}" || exit 1
        ;;
    base)
        notify "TASK" "Set up configuration to mirror feature's config folder"
        notify "ERROR" "CONFIG BASED ON FEATURE'S FOLDER IS NOT IMPLEMENTED..." && exit 1
        ;;
    *)
        setup_config_repo || exit 1
        ;;
esac

