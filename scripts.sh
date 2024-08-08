#!/bin/bash
DEV_COMPOSER_FILE="docker-compose-development.yaml"
PREVIEW_COMPOSER_FILE="docker-compose-preview.yaml"
PROD_COMPOSER_FILE="docker-compose.yaml"
LETS_ENCRYPT_FOLDER="/etc/letsencrypt/live/projetoumportodostodosporum.org"

BACKUP_DOCKER_FOLDER="/tmp/backup"
DOCKER_VOLUMES_FOLDER="/var/lib/docker/volumes"

##
# Sends the daily backup to Backup Server
# Backup Server handles weekly, monthly and remove old ones
# Keep the 7 most recent locally
##
BACKUP_DEST_FOLDER="/backup/projetoumportodostodosporum.org/daily"
BACKUP_DEST_IP="142.93.245.106"

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

backup:run          - create .tar.gz files from volumes in ${BACKUP_DOCKER_FOLDER}
backup:external     - sends backup to external VPS
backup:restore      - restores volume data from backup file
backup:delete-old   - removes old backup files (7 day old)

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


##
# Development
##
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


##
# Preview
##
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


##
# Production
##
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


##
# Build Preview
##
function dockerBuildPreview() {
    echoCommand "docker build --no-cache --target preview-image -t project/server:preview ."
    docker build --no-cache --target preview-image -t project/server:preview .
}


##
# Build Production
##
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


##
# Certbot Renew
##
function certbotRenew() {
    echoCommand "certbot renew"
    certbot renew
}

function certbotRenewDry() {
    echoCommand "certbot renew --dry-run"
    certbot renew --dry-run
}

##
# Certbot Get
##
function certbotGet() {
    echoCommand "$(echo "certbot certonly --nginx -d www.projetoumportodostodosporum.org ${CERTBOT_DOMAINS[@]}")"
    #certbot certonly --nginx -d www.projetoumportodostodosporum.org "${CERTBOT_DOMAINS[@]}"
}

function certbotGetStaging() {
    echoCommand "$(echo "certbot certonly --nginx -d www.projetoumportodostodosporum.org ${CERTBOT_DOMAINS[@]} --staging")"
    #certbot certonly --nginx -d www.projetoumportodostodosporum.org "${CERTBOT_DOMAINS[@]}" --staging
}


##
# Nginx
##
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


##
# Backup Docker Volumes
##
function _backupDockerVolumes() {
    local volume=$1

    if [ -z "$volume" ]; then
        echo "You must pass the volume name. Exiting..."
        exit 1
    fi

    # create backup directory
    mkdir -p ${BACKUP_DOCKER_FOLDER}

    echoCommand "tar czfv $BACKUP_DOCKER_FOLDER/$volume/$volume-$(date +%F).tar.gz -C $DOCKER_VOLUMES_FOLDER/$volume ."
    tar czfv "${BACKUP_DOCKER_FOLDER}/${volume}/${volume}-$(date +%F).tar.gz" -C "${DOCKER_VOLUMES_FOLDER}/${volume}" .
}

function backupDockerVolumes() {
    # for volume names see docker-compose.yaml
    _backupDockerVolumes "files"
    _backupDockerVolumes "db"
    _backupDockerVolumes "redis"
    _backupDockerVolumes "lets_encrypt"
    backupExternal
}

function backupExternal() {
    echoCommand "rsync -avz $BACKUP_DOCKER_FOLDER root@$BACKUP_DEST_IP:$BACKUP_DEST_FOLDER"
    rsync -avz "$BACKUP_DOCKER_FOLDER" "root@${BACKUP_DEST_IP}:${BACKUP_DEST_FOLDER}"
}

function _restoreBackupDockerVolumes() {
    if [ $# -ne 3 ]; then
        echo "You must pass <container/service> <volume> <file_name>. Exiting..."
        exit 1
    fi

    # service names = container names, see docker-compose.yaml file
    local container=$1
    local volume=$2
    local fileName=$3

    echoCommand "docker container stop $container"
    docker container stop "$container"

    echoCommand "tar xzvf $BACKUP_DOCKER_FOLDER/$volume/$fileName -C $DOCKER_VOLUMES_FOLDER/$volume/"
    tar xzvf "${BACKUP_DOCKER_FOLDER}/${volume}/${fileName}" -C "${DOCKER_VOLUMES_FOLDER}/${volume}/"

    echoCommand "docker compose up -d --no-deps $container"
    docker compose up -d --no-deps "$container"
}

function _restoreBackupDockerVolumesUsage() {
     local containersInfo=(
        "server     - restore lets_encrypt volume"
        "api        - restore files volume"
        "db         - restore db volume"
        "redis      - restore redis volume"
    )

    echo -e "Usage:
    backup:restore <container>      - list available restore files
    backup:restore <container> file - restore container data with file\n"
    echoCommand "Services available:"
    for container in "${containersInfo[@]}"; do
        echo -e "$container"
    done
}

function restoreBackupDockerVolumes() {
    local containers=(
        "server" "api" "db" "redis"
    )
    # (volume)
    declare -rA CONTAINERS=(
        [server, 0]="lets_encrypt"
        [api, 0]="files"
        [db, 0]="db"
        [redis, 0]="redis"
    )

    local container=$2
    local fileName=$3

    # +1 since backup:restore counts as argument
    # backup:restore container case
    if [ $# -eq "$((1+1))" ]; then
        local match=0
        for ctnr in ${containers[@]}; do
            if [ $container == $ctnr ]; then
                match=1
                break
            fi
        done

        if [ $match -eq 1 ]; then
            local volume=${CONTAINERS[$container, 0]}
            local volumeFolder="$BACKUP_DOCKER_FOLDER/$volume/"
            
            echoCommand "Available Dates:"
            ls -lah $volumeFolder
            exit 0
        else
            _restoreBackupDockerVolumesUsage
            exit 1
        fi

    # fallback case
    elif [ $# -ne "$((2+1))" ]; then
        _restoreBackupDockerVolumesUsage
        exit 1
    fi

    
    local volume=${CONTAINERS[$container, 0]}
    local file="$BACKUP_DOCKER_FOLDER/$volume/$fileName"

    if [ ! -f "$file" ]; then
        echo "File $file doesn't exist. Exiting..."
        exit 1
    fi

    _restoreBackupDockerVolumes $container $volume $fileName
}

function deleteOldBackupVolumes() {
    # delete backups older than 7 days
    echoCommand "find ${BACKUP_DOCKER_FOLDER}/ -type f -mtime +7 -delete"
    find "${BACKUP_DOCKER_FOLDER}/" -type f -mtime +7 -delete
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
    backup:external)
        backupExternal;;
    backup:restore)
        restoreBackupDockerVolumes "$@";;
    backup:delete-old)
        deleteOldBackupVolumes;;

    --help)
        echo "$HELP_MESSAGE";;
    *)
        echo "\"$command\" not available. Use $(basename $0) --help to see available commands.";;
esac
    