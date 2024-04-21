#!/bin/bash
DEV_COMPOSER_FILE="docker-compose-development.yaml"
PREVIEW_COMPOSER_FILE="docker-compose-preview.yaml"
PROD_COMPOSER_FILE="docker-compose.yaml"

DOMAINS=(
    "projetoumportodostodosporum.org"
    "api.projetoumportodostodosporum.org"
    "cms.projetoumportodostodosporum.org"
    "assets.projetoumportodostodosporum.org"
    "files.projetoumportodostodosporum.org"
    "mail.projetoumportodostodosporum.org"
)
CERTBOT_DOMAINS=()
for server in "${DOMAINS[@]}" 
do
    CERTBOT_DOMAINS+=("-d $server" "-d www.$server")
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
    echoCommand "$(echo "certbot certonly --nginx ${CERTBOT_DOMAINS[@]}")"
    certbot certonly --nginx "${CERTBOT_DOMAINS[@]}"
}

function certbotGetStaging() {
    echoCommand "$(echo "certbot certonly --nginx ${CERTBOT_DOMAINS[@]} --staging")"
    certbot certonly --nginx "${CERTBOT_DOMAINS[@]}" --staging
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
    for server in "${DOMAINS[@]}" 
    do
        echoCommand "ln -sf /etc/nginx/sites-available/post.$server /etc/nginx/sites-enabled/$server"
        ln -sf /etc/nginx/sites-available/post."$server" /etc/nginx/sites-enabled/"$server"
    done
    echoCommand "nginx -s reload"
    nginx -s reload
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
    --help)
        echo "$HELP_MESSAGE";;
    *)
        echo "\"$command\" not available. Use $(basename $0) --help to see available commands.";;
esac
    