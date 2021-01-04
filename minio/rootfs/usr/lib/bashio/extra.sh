# vim: filetype=sh

function bashio::config.get() {
    local key=${1}
    local default=${2}
    local value

    if bashio::config.exists "${key}"; then
        value=$(bashio::config "${key}")
    fi
    printf "%s" "${value:-$default}"
    return "${__BASHIO_EXIT_OK}"
}

