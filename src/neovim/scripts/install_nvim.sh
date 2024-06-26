# shellcheck disable=SC2148
# This is only a snippet to a bigger script and shall not be called directly.
# Its macros are defined elsewhere.
LOCAL_BIN="/usr/local/bin"
NVIM_CONF_FOLDER="$CONTAINER_USER_HOME/.config/nvim"
NVIM_CONF_HOST="/media/nvim_host"
NVIM_CONF_REPO="$CONTAINER_USER_HOME/.config/nvim_repo"
NVIM_CONF_BASE="$WORKSPACE_FOLDER/.config/nvim_base"
OPT_SW_NEOVIM="/opt/neovim"

function notify {
    RED='\033[0;31m[ERROR] '
    YELLOW='\033[1;33m[WARNING] '
    GREEN='\e[1;32m[INFO] '
    BLUE='\e[1;34m[TASK] '
    NC='\033[0m' # No Color

    if [ "$1" = "TASK" ]; then
        printf "${BLUE}%s\n${NC}" "${*:2}"
    fi
    if [ "$1" = "INFO" ]; then
        printf "${GREEN}%s\n${NC}" "${*:2}"
    fi
    if [ "$1" = "WARNING" ]; then
        printf "${YELLOW}%s\n${NC}" "${*:2}"
    fi
    if [ "$1" = "ERROR" ]; then
        printf "${RED}%s\n${NC}" "${*:2}"
    fi
}

if [[ -z ${CONTAINER_USER} || \
      -z ${CONTAINER_USER_HOME} || \
      -z ${VERSION} || \
      -z ${BUILD_TYPE} || \
      -z ${NVIM_CONFIG} ]] ;then

    notify "ERROR" "Not all macros were set:"
    notify "ERROR" "CONTAINER_USER      = ${CONTAINER_USER}"
    notify "ERROR" "CONTAINER_USER_HOME = ${CONTAINER_USER_HOME}"
    notify "ERROR" "VERSION             = ${VERSION}"
    notify "ERROR" "BUILD_TYPE          = ${BUILD_TYPE}"
    notify "ERROR" "NVIM_CONFIG         = ${NVIM_CONFIG}"

    exit 1
fi

function set_default_editor {
    notify "INFO" "Configuring neovim as default editor . . ."
    sudo ln -s ${LOCAL_BIN}/nvim /usr/bin/nvim
    sudo update-alternatives --install /usr/bin/editor editor "$(command -v nvim)" 100
    sudo update-alternatives --set editor ${LOCAL_BIN}/nvim

    sudo update-alternatives --install /usr/bin/vi vi "$(command -v nvim)" 60
    sudo update-alternatives --set vi ${LOCAL_BIN}/nvim

    sudo update-alternatives --install /usr/bin/vim vim "$(command -v nvim)" 60
    sudo update-alternatives --set vim ${LOCAL_BIN}/nvim
}

function install_dependency {
    (sudo apt-get update && sudo apt-get -y install "$@") &> /dev/null
    ret_value=$?

    [[ $ret_value != 0 ]] && notify "ERROR" "Failed to install " "$@"
    return $ret_value
}

function install_npm_dependency {
    notify "INFO" "Installing npm package(s):" "$@"
    sudo npm i -g  "$@" &> /dev/null || \
        (notify "ERROR" "Failed to install " "$@" && return 1)
}

function install_pip_dependency {
    notify "INFO" "Installing python package(s):" "$@"
    pip3 install "$@" &> /dev/null || \
        (notify "ERROR" "Failed to install %s" "$@" && return 1)
}

function install_neovim_dependencies {
    notify "INFO" "Installing neovim dependencies . . ."
    (install_dependency pkg-config automake libtool libtool-bin gettext xsel fonts-powerline global npm python3-pip && \
    install_npm_dependency neovim && install_pip_dependency pynvim)
    ret_value=$?
    [[ $ret_value != 0 ]] && notify "ERROR" "Failed to install dependencies"
    return $ret_value
}

function build_neovim {
    notify "INFO" "Cloning neovim ${VERSION} . . ."
    ( (git clone -q --depth 1 --branch "${VERSION}" https://github.com/neovim/neovim &>/dev/null) || \
        (notify "ERROR" "Failed to clone neovim" && return 1) ) && \

    notify "INFO" "Building neovim from sources. . ."
    ( (cd neovim && make -j 12 CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$PWD/build/install" install) &> /dev/null || \
    (notify "ERROR" "Failed to build neovim" && (rm -rf ./neovim || exit 0) && return 1) )
}

function build_from_source {
    notify "INFO" "Building Neovim from source..."
    sudo rm -rf ${OPT_SW_NEOVIM}
    sudo mkdir -p ${OPT_SW_NEOVIM} && sudo chown "${CONTAINER_USER}":"${CONTAINER_USER}" ${OPT_SW_NEOVIM}

    RETURN=$PWD
    cd ${OPT_SW_NEOVIM} || return 1
    (install_neovim_dependencies && build_neovim)
    ret_value=$?
    cd "${RETURN}" || return 1
    [[ $ret_value != 0 ]] && return 1

    notify "INFO" "Linking nvim in $LOCAL_BIN . . ."
    sudo ln -s $OPT_SW_NEOVIM/neovim/build/bin/nvim $LOCAL_BIN || return $?
}

function use_appimage_release {
    notify "INFO" "Fetching nvim.appimage:${VERSION} . . ."

    ( (wget "https://github.com/neovim/neovim/releases/download/${VERSION}/nvim.appimage" && \
    chmod +x nvim.appimage && sudo mv nvim.appimage ${LOCAL_BIN}) &> /dev/null || \
    (notify "ERROR" "Failed to fetch nvim.appimage" && rm -rf nvim.appimage && return 1 ) )
    # shellcheck disable=SC2181 # simpler than if statements
    [[ $? != 0 ]] && return 1

    NVIM_APP_IMAGE_WRAPPER="${LOCAL_BIN}/nvim"
    notify "INFO" "Creating wrapper script for AppImage..."
    sudo tee "$NVIM_APP_IMAGE_WRAPPER" > /dev/null << EOF
 #!/bin/bash

function full_support {
        nvim.appimage \$@ &>/dev/null
}

function partial_support {
        nvim.appimage --appimage-extract-and-run \$@ 2>/dev/null
}

function fallback {
        nvim.appimage --appimage-extract &> /dev/null && ./squashfs-root/AppRun \$@ && rm -rf ./squashfs-root
}

full_support \$@ || partial_support \$@ || fallback \$@

EOF

    ( (sudo chmod +x ${NVIM_APP_IMAGE_WRAPPER} && sudo chown "${CONTAINER_USER}":"${CONTAINER_USER}" ${NVIM_APP_IMAGE_WRAPPER}) || \
    (notify "ERROR" "Failed to set up wrapper for Appimage" && rm -rf nvim.appimage  && return 1) )

    return $?
}

function use_prebuilt_release {
    notify "INFO" "Fetching nvim-linux64:${VERSION} . . ."

    sudo rm -rf ${OPT_SW_NEOVIM}
    ( (wget "https://github.com/neovim/neovim/releases/download/${VERSION}/nvim-linux64.tar.gz" && \
    sudo tar -C /opt -xzf nvim-linux64.tar.gz && sudo mv /opt/nvim-linux64 ${OPT_SW_NEOVIM} && sudo ln -s ${OPT_SW_NEOVIM}/bin/nvim ${LOCAL_BIN}/nvim) &> /dev/null || \
    (notify "ERROR" "Failed to install prebuilt nvim" && rm -rf nvim.appimage && return 1 ) )
    # shellcheck disable=SC2181 # simpler than if statements
    [[ $? != 0 ]] && return 1

    ( (sudo chmod +x ${OPT_SW_NEOVIM}/bin/nvim && sudo chown "${CONTAINER_USER}":"${CONTAINER_USER}" ${OPT_SW_NEOVIM}/bin/nvim) || \
    (notify "ERROR" "Failed to set up prebuilt nvim-linux64" && rm -rf ${OPT_SW_NEOVIM}  && return 1) )

    return $?
}

function use_apt_ppa {
    notify "INFO" "Using neovim-ppa . . ."

    install_dependency software-properties-common || return 1
    sudo add-apt-repository ppa:neovim-ppa/stable --yes &> /dev/null || return 1
    install_dependency neovim || return 1
}

function install_common_config_dependencies {
    notify "INFO" "Installing common dependencies..."
    (install_dependency npm luarocks ripgrep && \
     install_npm_dependency neovim && \
     install_pip_dependency pynvim) || return 1
}

function setup_config_host {
    notify "INFO" "Setting up configuration to mirror host's..."
    install_common_config_dependencies || return 1
    notify "INFO" "Linking configuration..."
    ln -s "${NVIM_CONF_HOST}" "${NVIM_CONF_FOLDER}" || return 1
}

function setup_config_base {
    notify "ERROR" "NOT IMPLEMENTED..."
    return 1

    notify "INFO" "Setting up base configuration..."
    install_common_config_dependencies || return 1
    notify "INFO" "Linking configuration..."
    ln -s "${NVIM_CONF_BASE}" "${NVIM_CONF_FOLDER}" || return 1

    # TODO headless commands to prep for first use. Eg.:
}

function setup_config_repo {
    notify "INFO" "Setting up base configuration..."
    git clone "${NVIM_CONFIG}" "${NVIM_CONF_REPO}" || return 1
    notify "INFO" "Linking configuration..."
    ln -s "${NVIM_CONF_REPO}" "${NVIM_CONF_FOLDER}" || return 1
}

# Handle BUILD_TYPE
case "${BUILD_TYPE}" in
    source)
        build_from_source || exit 1
        ;;
    appimage)
        use_appimage_release || exit 1
        ;;
    prebuilt)
        use_prebuilt_release || exit 1
        ;;
    apt)
        use_apt_ppa || exit 1
        ;;
    *)
        notify "ERROR" "Build type not recognized" && exit 1
esac

set_default_editor || exit 1

# Handle NVIM_CONFIG
rm -rf "${NVIM_CONF_FOLDER}"

case "${NVIM_CONFIG}" in
    host)
        setup_config_host || exit 1
        ;;
    base)
        setup_config_base || exit 1
        ;;
    *)
        setup_config_repo || exit 1
        ;;
esac

