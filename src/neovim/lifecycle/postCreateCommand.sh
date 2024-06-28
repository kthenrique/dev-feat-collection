# shellcheck disable=SC2148
# This is only a snippet to a bigger script and shall not be called directly.
# Its macros are defined elsewhere.

echo "Running as whoami: $(whoami)"
echo "Running as user: $USER with home: $HOME"
echo "Running as container user: $USER with home: $HOME"

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

# Handle BUILD_TYPE
case "${BUILD_TYPE}" in
    source)
        notify "TASK" "Complete build from source"
        cd /opt/neovim && build_neovim && cd - || exit 1
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

