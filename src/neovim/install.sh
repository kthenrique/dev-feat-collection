#!/bin/bash

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname -- "${SCRIPT_PATH}")
TMP_FEAT_DIR="/tmp/dev-container/feat/nvim/"

function create_post_create_command {
    notify "INFO" "Creating postCreateCommand . . ."
    POST_CREATE_SH=${TMP_FEAT_DIR}/post_create_command.sh

    touch $POST_CREATE_SH && \
    echo "#!/bin/bash"                                 >> ${POST_CREATE_SH} && \
    echo "set -euo pipefail"                           >> ${POST_CREATE_SH} && \
    echo "WORKSPACE_FOLDER=${SCRIPT_DIR}"              >> ${POST_CREATE_SH} && \
    echo "CONTAINER_USER=${_CONTAINER_USER}"           >> ${POST_CREATE_SH} && \
    echo "CONTAINER_USER_HOME=${_CONTAINER_USER_HOME}" >> ${POST_CREATE_SH} && \
    echo "VERSION=${VERSION}"                          >> ${POST_CREATE_SH} && \
    echo "BUILD_TYPE=${BUILD_TYPE}"                    >> ${POST_CREATE_SH} && \
    echo "NVIM_CONFIG=${NVIM_CONFIG}"                  >> ${POST_CREATE_SH} && \
    cat "${SCRIPT_DIR}/scripts/install_nvim.sh"        >> ${POST_CREATE_SH}

    chown "${_CONTAINER_USER}":"${_CONTAINER_USER}" ${POST_CREATE_SH}
    chmod +x ${POST_CREATE_SH}
}

mkdir -p ${TMP_FEAT_DIR}
chown "${_CONTAINER_USER}":"${_CONTAINER_USER}" ${TMP_FEAT_DIR}

# Need to defer execution because of possible need for credentials depending on the OCI registry and
# its configs, which may be setup later. Otherwise we would need to define them in multiple places
create_post_create_command
