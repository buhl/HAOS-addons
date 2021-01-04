#!/usr/bin/with-contenv bashio
source "${__BASHIO_LIB_DIR}/extra.sh"
bashio::log.info "Configuring MinIO"

PORT=$(bashio::addon.port 9000)

if ! bashio:var.has_value "${PORT}"; then
    PORT=9000
fi



# Creates initial MinIO dirs in case it is non-existing
if ! bashio::fs.directory_exists '/addons/minio/server'; then
    mkdir -p /addons/minio/server
fi

echo -n > /addons/minio/.minio.env

echo "PORT=\"${PORT}\"" >> /addons/minio/.minio.env

# Checking and reading access and secret key
bashio::config.require.username "credentials.access_key"
bashio::config.require.password "credentials.secret_key"
bashio::config.suggest.safe_password "credentials.secret_key"
MINIO_ACCESS_KEY=$(bashio::config "credentials.access_key")
MINIO_SECRET_KEY=$(bashio::config "credentials.secret_key")
echo "MINIO_ACCESS_KEY=\"${MINIO_ACCESS_KEY}\"" >> /addons/minio/.minio.env
echo "MINIO_SECRET_KEY=\"${MINIO_SECRET_KEY}\"" >> /addons/minio/.minio.env

# Enableding change of credentials
if bashio::config.has_value "credentials.old_access_key" && bashio::config.has_value "credentials.old_secret_key"; then
    echo "OLD_MINIO_ACCESS_KEY=\"$(bashio::config "credentials.old_access_key")\"" >> /addons/minio/.minio.env
    echo "OLD_MINIO_SECRET_KEY=\"$(bashio::config "credentials.old_secret_key")\"" >> /addons/minio/.minio.env
fi

SIZE=$(bashio::config.get "size" "1")
DATA_DIRS=$(for n in $(seq 1 ${SIZE}); do echo /addons/minio/server/data$n; done)

mkdir -p $DATA_DIRS
echo "DATA_DIRS=\"${DATA_DIRS}\"" >> /addons/minio/.minio.env

MINIO_USERNAME=$(bashio::config.get "owner.user" "minio")
MINIO_GROUPNAME=$(bashio::config.get "owner.group" "minio")
MINIO_UID=$(bashio::config.get "owner.uid" "1000")
MINIO_GID=$(bashio::config.get "owner.gid" "1000")
if [ ! -z "${MINIO_USERNAME}" ] && [ ! -z "${MINIO_GROUPNAME}" ]; then
    if ! getent passwd ${MINIO_USERNAME} 2>&1 >/dev/null && ! getent group ${MINIO_GROUPNAME}  2>&1 >/dev/null; then
        if [ ! -z "${MINIO_UID}" ] && [ ! -z "${MINIO_GID}" ]; then
            addgroup -g "$MINIO_GID" "$MINIO_GROUPNAME" \
            && adduser -s /bin/ash -S -D -u "$MINIO_UID" -G "$MINIO_GROUPNAME" "$MINIO_USERNAME" \
            || bashio::exit.nok "Unable to add ${MINIO_USERNAME}:${MINIO_GROUPNAME}(${MINIO_UID}:${MINIO_GID} to the system"
        else
            addgroup "$MINIO_GROUPNAME" \
            && adduser -s /bin/ash -S -D -G "$MINIO_GROUPNAME" "$MINIO_USERNAME" \
            || bashio::exit.nok "Unable to add ${MINIO_USERNAME}:${MINIO_GROUPNAME} to the system"
        fi
    elif getent passwd ${MINIO_USERNAME} 2>&1 >/dev/null || getent group ${MINIO_GROUPNAME}  2>&1 >/dev/null; then
        bashio::exit.nok "Unable to add ${MINIO_USERNAME}:${MINIO_GROUPNAME} to the system. Running as root."
    fi
fi
chown -R ${MINIO_USERNAME}: /addons/minio || bashio.exit.nok "unable to set ownership of /addons/minio"
echo "MINIO_USERNAME=\"${MINIO_USERNAME}\"" >> /addons/minio/.minio.env

HOME_DIR=$(getent passwd ${MINIO_USERNAME} | cut -d: -f6)
set -x
su ${MINIO_USERNAME} -c "/usr/bin/mc alias set minio http://localhost:${PORT} ${MINIO_ACCESS_KEY} ${MINIO_SECRET_KEY} --api S3v4"
su ${MINIO_USERNAME} -c "jq '{version: .version, aliases: .aliases | with_entries(select(.key==\"minio\"))}'" \
        < ${HOME_DIR}/.mc/config.json > ${HOME_DIR}/.mc/config.json.new
su ${MINIO_USERNAME} -c " \
    mv ${HOME_DIR}/.mc/config.json ${HOME_DIR}/.mc/config.json.old \
    && mv ${HOME_DIR}/.mc/config.json.new ${HOME_DIR}/.mc/config.json"

bashio::log.info "Configuration of MinIO complete"
