#!/bin/bash
DEV_COMPOSER_FILE="docker-compose-development.yaml"
PREVIEW_COMPOSER_FILE="docker-compose-preview.yaml"
PROD_COMPOSER_FILE="docker-compose.yaml"
LETS_ENCRYPT_FOLDER="/etc/letsencrypt/live/projetoumportodostodosporum.org"
BACKUP_DOCKER_FOLDER="/tmp/backup"

DOMAINS=(
    "projetoumportodostodosporum.org"
    "api.projetoumportodostodosporum.org"
    "cms.projetoumportodostodosporum.org"
    "assets.projetoumportodostodosporum.org"
    "files.projetoumportodostodosporum.org"
)
CERTBOT_DOMAINS=()
for server in "${DOMAINS[@]}" 
do
    CERTBOT_DOMAINS+=("-d $server")
done

HELP_MESSAGE="Available commands are:
-- OUTSIDE CONTAINER --
start:dev           - start server in development mode
stop:dev            - stop server in development mode
start:preview       - start project in preview mode 
stop:preview        - stop project in preview mode
start:prod          - start project in production mode
stop:prod           - stop project in production mode

build:preview       - build preview server image
build:prod          - build production server image and push to registry

openssl:certificate - generate certificate
openssl:trust       - trust localhost.crt systemwide (root)

backup:run          - create .tar.gz files from volumes in ${BACKUP_DOCKER_FOLDER}
backup:restore      - restores volume data from backup file
backup:delete-old   - removes old backup files (30 days old)

-- INSIDE CONTAINER --
certbot:renew       - Cerbot renew process
certbot:renew-dry   - Cerbot renew test process
certbot:get         - obtain SSL certificates
certbot:get-staging - certbot:get staging

nginx:http          - change server conf to http only (pre SSL certificates)
nginx:https         - change server conf to https (post SSL certificates)"

command=$1
if [ -z $command ]; then
    echo "$HELP_MESSAGE"
fi

function echoCommand() {
    local color='\033[0;32m' # green
    local noColor='\033[0m'
    local string=$1
    if [ -z "$string" ]; then
        echo "You must pass one string. Exiting..."
        exit 1
    fi

    echo -e "$color$string$noColor"

}

function readEnvFile() {
    local fileName=$1
    if [ -z $fileName ]; then
        echo "You must pass the filename. Exiting..."
        exit 1
    fi

    set -a # automatically export all variables
    source $fileName
    set +a
}

function isRoot() {
    if [ $EUID -ne 0 ]; then
	    echo "You need to run this script as root. Exiting..."
	    exit 1
    fi
}

# OpenSSL
function openSSL() {
    echoCommand "openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 365 -keyout localhost.key -out localhost.crt -config localhost.cert.conf"
    openssl req -x509 -newkey rsa:2048 -nodes -sha256 -keyout localhost.key -out localhost.crt -config localhost.cert.conf
}

function trustCertificateSystemWide() {
    isRoot
    echoCommand "trust anchor localhost.crt"
    trust anchor localhost.crt

    # fallback for p11-kit: no configured writable location to store anchors
    # https://wiki.archlinux.org/title/User:Grawity/Adding_a_trusted_CA_certificate 3
    echoCommand "mkdir -p /usr/local/share/ca-certificates && cp localhost.crt /usr/local/share/ca-certificates/"
    mkdir -p /usr/local/share/ca-certificates && cp localhost.crt /usr/local/share/ca-certificates/
    echoCommand "sudo update-ca-certificates"
    sudo update-ca-certificates
}

# Development
function dockerDevDown() {
    readEnvFile ".env.dev"
    echoCommand "docker compose -f $DEV_COMPOSER_FILE down --remove-orphans -v"
    docker compose -f "$DEV_COMPOSER_FILE" down --remove-orphans -v
}

function dockerDevUp() {
    readEnvFile ".env.dev"
    echoCommand "docker compose -f $DEV_COMPOSER_FILE up --build dev-server -d"
    docker compose -f "$DEV_COMPOSER_FILE" up --build dev-server -d
}

function dockerDevRestart() {
    dockerDevDown && dockerDevUp
}

# Preview
function dockerPreviewDown() {
    readEnvFile ".env.preview"
    echoCommand "docker compose -f $PREVIEW_COMPOSER_FILE down --remove-orphans"
    docker compose -f "$PREVIEW_COMPOSER_FILE" down --remove-orphans
}

function dockerPreviewUp() {
    readEnvFile ".env.preview"
    echoCommand "docker compose -f $PREVIEW_COMPOSER_FILE up -d"
    docker compose -f "$PREVIEW_COMPOSER_FILE" up -d
}

function dockerPreviewRestart() {
    dockerPreviewDown && dockerPreviewUp
}

# Production
function dockerProductionDown() {
    echoCommand "docker compose -f $PROD_COMPOSER_FILE down --remove-orphans"
    docker compose -f "$PROD_COMPOSER_FILE" down --remove-orphans
}

function dockerProductionUp() {
    echoCommand "docker compose -f $PROD_COMPOSER_FILE up -d"
    docker compose -f "$PROD_COMPOSER_FILE" up -d
}

function dockerProductionRestart() {
    dockerProductionDown && dockerProductionUp
}

# Build Preview
function dockerBuildPreview() {
    echoCommand "docker build --no-cache --target preview-image -t project/server:preview ."
    docker build --no-cache --target preview-image -t project/server:preview .
}

# Build Production
function postDockerBuildProduction() {
    echoCommand "docker push --all-tags renangalvao/project"
    docker push --all-tags renangalvao/project
}

function dockerBuildProduction() {
    readEnvFile ".server-version"
    echoCommand "docker build --target prod-image -t renangalvao/project:server-$SERVER_VERSION -t renangalvao/project:server-latest ."
    docker build --target prod-image -t renangalvao/project:server-"$SERVER_VERSION" -t renangalvao/project:server-latest .
    postDockerBuildProduction
}

# Certbot Renew
function certbotRenew() {
    echoCommand "certbot renew"
    certbot renew
}

function certbotRenewDry() {
    echoCommand "certbot renew --dry-run"
    certbot renew --dry-run
}

# Certbot Get
function certbotGet() {
    echoCommand "$(echo "certbot certonly --nginx -d www.projetoumportodostodosporum.org ${CERTBOT_DOMAINS[@]}")"
    #certbot certonly --nginx -d www.projetoumportodostodosporum.org "${CERTBOT_DOMAINS[@]}"
}

function certbotGetStaging() {
    echoCommand "$(echo "certbot certonly --nginx -d www.projetoumportodostodosporum.org ${CERTBOT_DOMAINS[@]} --staging")"
    #certbot certonly --nginx -d www.projetoumportodostodosporum.org "${CERTBOT_DOMAINS[@]}" --staging
}

# Nginx
function nginxHttp() {
    for server in "${DOMAINS[@]}" 
    do
        echoCommand "ln -sf /etc/nginx/sites-available/pre.$server /etc/nginx/sites-enabled/$server"
        ln -sf /etc/nginx/sites-available/pre."$server" /etc/nginx/sites-enabled/"$server"
    done
    echoCommand "nginx -s reload"
    nginx -s reload
}

function nginxHttps() {
    if [ ! -d $LETS_ENCRYPT_FOLDER ]; then
        echo "SSL certificates doesn't exist, running Nginx in HTTP only."
        return 1
    fi

    for server in "${DOMAINS[@]}" 
    do
        echoCommand "ln -sf /etc/nginx/sites-available/post.$server /etc/nginx/sites-enabled/$server"
        ln -sf /etc/nginx/sites-available/post."$server" /etc/nginx/sites-enabled/"$server"
    done
    echoCommand "nginx -s reload"
    nginx -s reload
}

# Backup Docker Volumes
function _backupDockerVolumes() {
    local volume=$1
    local service=$2
    local dir=$3

    if [ -z "$volume" ]; then
        echo "You must pass the volume name. Exiting..."
        exit 1
    fi
    
    if [ -z "$service" ]; then
        echo "You must pass the service name. Exiting..."
        exit 1
    fi

    if [ -z "$dir" ]; then
        echo "You must pass the directory inside the container that you want to backup. Exiting..."
        exit 1
    fi

    # create backup directory
    mkdir -p ${BACKUP_DOCKER_FOLDER}

    echoCommand "docker run --rm -it \
--volumes-from $service \
-v $BACKUP_DOCKER_FOLDER/$volume/:/backup/ \
alpine:3.19 \
tar czfv /backup/$volume-$(date +%F).tar.gz $dir"
    #docker run --rm -it \
    #    --volumes-from "$service" \
    #    -v "${BACKUP_DOCKER_FOLDER}/${volume}/:/backup/" \
    #    alpine:3.19 \
    #    tar czfv "/backup/${volume}-$(date +%F).tar.gz" "${dir}"
}

function backupDockerVolumes() {
    # for volume names see docker-compose.yaml
    # (volume serviceName)
    FILES=("files" "server-api-1")
    DB=("db" "server-db-1")
    REDIS=("redis" "server-redis-1")
    LETS_ENCRYPT=("lets_encrypt" "server")

    _backupDockerVolumes ${FILES[0]} ${FILES[1]} "/usr/src/app/files" 
    _backupDockerVolumes ${DB[0]} ${DB[1]} "/var/lib/postgresql/data"
    _backupDockerVolumes ${REDIS[0]} ${REDIS[1]} "/data"
    _backupDockerVolumes ${LETS_ENCRYPT[0]} ${LETS_ENCRYPT[1]} "/etc/letsencrypt"
}

function _restoreBackupDockerVolumes() {
    if [ $# -ne 4 ]; then
        echo "You must pass service containerDir fileFolder file. Exiting..."
        exit 1
    fi

    local service=$1
    local containerDir=$2
    local fileFolder=$3
    local file=$4

    echoCommand "docker run --rm \
--volume-from $service \
-v $fileFolder:$containerDir \
alpine:3.19 \
cd $containerDir && tar xvf $file"

    #docker run --rm \
    #    --volume-from "$service" \
    #    "-v $fileFolder:$containerDir" \
    #    alpine:3.19 \
    #    cd "$containerDir" && tar xvf "$file"
}

function _restoreBackupDockerVolumesUsage() {
     local servicesInfo=(
        "server:            restore lets_encrypt volume"
        "server-api-1:      restore files volume"
        "server-db-1:       restore db volume"
        "server-redis-1:    restore redis volume"
    )

    echo -e "Usage:
    backup:restore service
    backup:restore service file\n"
    echoCommand "Services available:"
    for service in "${servicesInfo[@]}"; do
        echo -e "$service"
    done
}

function restoreBackupDockerVolumes() {
    local services=(
        "server" "server-api-1" "server-db-1" "server-redis-1"
    )
    # (volume, container directory)
    declare -rA SERVICES=(
        [server, 0]="lets_encrypt"
        [server, 1]="/etc/letsencrypt"
        [server-api-1, 0]="files"
        [server-api-1, 1]="/user/src/app/files"
        [server-db-1, 0]="db"
        [server-db-1, 1]="/var/lib/postgresql/data"
        [server-redis-1, 0]="redis"
        [server-redis-1, 1]="/data"
    )

    local service=$2
    local fileName=$3

    # +1 since backup:restore counts as argument
    # backup:restore service case
    if [ $# -eq "$((1+1))" ]; then
        local match=0
        for srv in ${services[@]}; do
            if [ $service == $srv ]; then
                match=1
                break
            fi
        done

        if [ $match -eq 1 ]; then
            local volume=${SERVICES[$service, 0]}
            local volumeFolder="$BACKUP_DOCKER_FOLDER/$volume/"
            
            echoCommand "Available Dates:"
            ls -lah $volumeFolder 
        else
            _restoreBackupDockerVolumesUsage
            exit 1
        fi

    # fallback case
    elif [ $# -ne "$((2+1))" ]; then
        _restoreBackupDockerVolumesUsage
        exit 1
    fi

    
    local volume=${SERVICES[$service, 0]}
    local file="$BACKUP_DOCKER_FOLDER/$volume/$fileName"

    if [ ! -f "$file" ]; then
        echo "File $file doesn't exist. Exiting..."
        exit 1
    fi

    local fileFolder="$BACKUP_DOCKER_FOLDER/$volume/"
    local containerDir=${SERVICES[$service, 1]}

    _restoreBackupDockerVolumes $service $containerDir $fileFolder $file
}

function deleteOldBackupVolumes() {
    # delete backups older than 30 days
    echoCommand "find ${BACKUP_DOCKER_FOLDER}/ -type f -mtime +30 -delete"
    find "${BACKUP_DOCKER_FOLDER}/" -type f -mtime +30 -delete
}

case $command in
    start:dev)
        dockerDevRestart;;
    stop:dev)
        dockerDevDown;;
    start:preview)
        dockerPreviewRestart;;
    stop:preview)
        dockerPreviewDown;;
    start:prod)
        dockerProductionRestart;;
    stop:prod)
        dockerProductionDown;;

    build:preview)
        dockerBuildPreview;;
    build:prod)
        dockerBuildProduction;;

    openssl:certificate)
        openSSL;;
    openssl:trust)
        trustCertificateSystemWide;;

    certbot:renew)
        certbotRenew;;
    certbot:renew-dry)
        certbotRenewDry;;
    certbot:get)
        certbotGet;;
    certbot:get-staging)
        certbotGetStaging;;

    nginx:http)
        nginxHttp;;
    nginx:https)
        nginxHttps;;

    backup:run)
        backupDockerVolumes;;
    backup:list-files)
        backupListFiles;;
    backup:restore)
        restoreBackupDockerVolumes "$@";;
    backup:delete-old)
        deleteOldBackupVolumes;;

    --help)
        echo "$HELP_MESSAGE";;
    *)
        echo "\"$command\" not available. Use $(basename $0) --help to see available commands.";;
esac
    