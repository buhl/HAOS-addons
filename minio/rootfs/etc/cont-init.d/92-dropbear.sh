#!/usr/bin/with-contenv bashio
if ! bashio::config.has_value "authorized_keys"; then
    bashio::log.info "No authorized keys in config"
    bashio::log.info "SSH will not be available"
    s6-svc -O /var/run/s6/services/dropbear
    bashio::exit.ok
fi

bashio::log.info "Configuring Dropbear"
declare PORT
PORT=$(bashio::addon.port 9022)

if ! bashio::var.has_value "${PORT}"; then
    bashio::log.fatal
    bashio::log.fatal "No port configured"
    bashio::log.fatal
    #bashio::exit.nok
    PORT=9022
fi
source "${__BASHIO_LIB_DIR}/extra.sh"

MINIO_USERNAME=$(bashio::config.get "owner.user" "minio")
MINIO_GROUPNAME=$(bashio::config.get "owner.group" "minio")
HOME_DIR=$(getent passwd ${MINIO_USERNAME} | cut -d: -f6)

# Creates initial MinIO dirs in case it is non-existing
if ! bashio::fs.directory_exists '/addons/minio/dropbear'; then
    mkdir -p /addons/minio/dropbear
fi

chmod -R u=Xrw,g=,o= "/addons/minio/dropbear"
(cd /etc && ln -s /addons/minio/dropbear)

if ! bashio::fs.directory_exists "${HOME_DIR}/.ssh"; then
    mkdir -p "${HOME_DIR}/.ssh"
fi

echo -n > "${HOME_DIR}/.ssh/authorized_keys"
echo $(bashio::config "authorized_keys") | while read key ; do
    echo "command=\"/usr/local/bin/mcjail\" $key" >> "${HOME_DIR}/.ssh/authorized_keys"
done

chmod -R u=Xrw,g=,o= "${HOME_DIR}/.ssh"
chown -R minio: "${HOME_DIR}/.ssh"

echo -n > /addons/minio/dropbear/.dropbear.env
echo "MINIO_GROUPNAME=${MINIO_GROUPNAME}" >> /addons/minio/dropbear/.dropbear.env
echo "PORT=${PORT}" >> /addons/minio/dropbear/.dropbear.env

bashio::log.info "Configuration of Dropbear complete"
