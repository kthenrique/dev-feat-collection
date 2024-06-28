#!/bin/bash

LOCAL_BIN="/usr/local/bin"

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
    sleep 2
}

function am_i_root {
 [ "$EUID" -ne "0" ] && return 1
 return 0
}

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
    (export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get -y install "$@") > /dev/null
    ret_value=$?

    [[ $ret_value != 0 ]] && notify "ERROR" "Failed to install " "$@"
    return $ret_value
}

function install_npm_dependency {
    notify "INFO" "Installing npm package(s):" "$@"
    ! am_i_root && notify "ERROR" "<PC>: Not running as root!" && return 1

    npm i -g  "$@" > /dev/null || \
        (notify "ERROR" "Failed to install " "$@" && return 1)
}

function install_pip_dependency {
    USERNAME=$1
    notify "INFO" "Installing python package(s):" "$@"
    ! am_i_root && notify "ERROR" "<PC>: Not running as root!" && return 1

    pip3 install --break-system-packages "${@:2}" > /dev/null || \
        (notify "ERROR" "Failed to install %s" "$@" && return 1)
}

function install_build_dependencies {
    notify "INFO" "Installing neovim dependencies..."
    ! am_i_root && notify "ERROR" "<PC>: Not running as root!" && return 1

    install_dependency git make cmake pkg-config automake libtool libtool-bin gettext xsel fonts-powerline global npm python3-pip || return 1
    return 0
}

function install_appimage_dependencies {
    notify "INFO" "Installing neovim dependencies..."
    ! am_i_root && notify "ERROR" "<PC>: Not running as root!" && return 1

    install_dependency wget || return 1
    install_dependency fuse libfuse2 || return 1
    return 0
}

function build_neovim {
    notify "INFO" "Cloning neovim ${VERSION} . . ."
    am_i_root && notify "ERROR" "<PC>: Running as root!" && return 1

    ( (git clone -q --depth 1 --branch "${VERSION}" https://github.com/neovim/neovim ) || \
        (notify "ERROR" "Failed to clone neovim" && return 1) ) && \

    notify "INFO" "Building neovim from sources. . ."
    ( (cd neovim && make -j 12 CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$PWD/build/install" install) > /dev/null || \
    (notify "ERROR" "Failed to build neovim" && (rm -rf ./neovim || exit 0) && return 1) )
}

function reset_dir_as {
    DIRECTORY=$1
    USERNAME=$2
    notify "INFO" "Reset ${DIRECTORY} as ${USERNAME}"
    ! am_i_root && notify "ERROR" "<PC>: Not running as root!" && return 1

    rm -rf "${DIRECTORY}" || return 1
    (mkdir -p "${DIRECTORY}" && chown "${USERNAME}":"${USERNAME}" "${DIRECTORY}") || return 1
}

function from_link_to {
    SRC_LINK=$1
    DST_LINK=$2
    ln -s "${SRC_LINK}" "${DST_LINK}"
    return 0
}

function fetch_nvim_appimage {
    notify "INFO" "Fetching nvim.appimage:${VERSION} . . ."
    APPIMAGE_WRAPPER_SCRIPT=$1
    ( (wget "https://github.com/neovim/neovim/releases/download/${VERSION}/nvim.appimage" &> /dev/null && \
    chmod +x nvim.appimage) || \
    (notify "ERROR" "Failed to fetch nvim.appimage" && rm -rf nvim.appimage && return 1 ) )
    # shellcheck disable=SC2181 # simpler than if statements
    [[ $? != 0 ]] && return 1

    notify "INFO" "Creating wrapper script for AppImage..."
    tee "$APPIMAGE_WRAPPER_SCRIPT" > /dev/null << EOF
 #!/bin/bash

function full_support {
        echo "TRYING FULL SUPPORT..."
        ${PWD}/nvim.appimage \$@ 2>/dev/null
}

function partial_support {
        echo "TRYING PARTIAL SUPPORT..."
        ${PWD}/nvim.appimage --appimage-extract-and-run \$@ 2>/dev/null
}

function fallback {
        echo "TRYING FALLBACK..."
        ${PWD}/nvim.appimage --appimage-extract &> /dev/null && ./squashfs-root/AppRun 2>/dev/null \$@ && rm -rf ./squashfs-root
}

full_support \$@ || partial_support \$@ || fallback \$@ || echo "NO SUPPORT FOR APPIMAGES"

EOF

    ( chmod +x "${APPIMAGE_WRAPPER_SCRIPT}" || \
    (notify "ERROR" "Failed to set up wrapper for Appimage" && rm -rf nvim.appimage && return 1) )

    return $?
}

function use_prebuilt_release {
    notify "INFO" "Fetching nvim-linux64:${VERSION} . . ."

    ( (wget "https://github.com/neovim/neovim/releases/download/${VERSION}/nvim-linux64.tar.gz" && \
    sudo tar -C /opt -xzf nvim-linux64.tar.gz && sudo mv /opt/nvim-linux64 ${OPT_SW_NEOVIM} && sudo ln -s ${OPT_SW_NEOVIM}/bin/nvim ${LOCAL_BIN}/nvim) &> /dev/null || \
    (notify "ERROR" "Failed to install prebuilt nvim" && rm -rf nvim.appimage && return 1 ) )
    # shellcheck disable=SC2181 # simpler than if statements
    [[ $? != 0 ]] && return 1

    ( chmod +x "${OPT_SW_NEOVIM}/bin/nvim" || \
    (notify "ERROR" "Failed to set up prebuilt nvim-linux64" && rm -rf ${OPT_SW_NEOVIM}  && return 1) )

    return $?
}

function use_apt_ppa {
    notify "INFO" "Using neovim-ppa . . ."

    install_dependency software-properties-common || return 1
    add-apt-repository ppa:neovim-ppa/stable --yes &> /dev/null || return 1
    install_dependency neovim || return 1
}

# No hard dependencies
function install_common_config_packages {
    notify "INFO" "Installing common packages..."
    install_dependency npm
    install_dependency luarocks
    install_dependency ripgrep
    install_dependency python3-pynvim
    install_npm_dependency neovim
    return 0
}

function setup_config_host {
    NVIM_CONF_HOST=$1
    NVIM_CONF_FOLDER=$2
    notify "INFO" "Linking configuration..."
    am_i_root && notify "ERROR" "<PC>: Running as root!" && return 1

    mkdir -p "${HOME}/.config"
    ln -s "${NVIM_CONF_HOST}" "${NVIM_CONF_FOLDER}" || return 1
}

# TODO
function setup_config_base {
    NVIM_CONF_BASE=$1
    NVIM_CONF_FOLDER=$2
    notify "ERROR" "NOT IMPLEMENTED..."
    return 1

    notify "INFO" "Setting up base configuration..."
    notify "INFO" "Linking configuration..."
    ln -s "${NVIM_CONF_BASE}" "${NVIM_CONF_FOLDER}" || return 1

    # TODO headless commands to prep for first use. Eg.:
}

function setup_config_repo {
    NVIM_CONF_REPO=$1
    NVIM_CONF_FOLDER=$2
    notify "INFO" "Setting up base configuration..."
    git clone "${NVIM_CONFIG}" "${NVIM_CONF_REPO}" || return 1
    notify "INFO" "Linking configuration..."
    ln -s "${NVIM_CONF_REPO}" "${NVIM_CONF_FOLDER}" || return 1
}

