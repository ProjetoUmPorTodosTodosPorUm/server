#!/bin/bash
BACKUP_ROOT_FOLDER="/backup/projetoumportodostodosporum.org"
VOLUMES=(
    "db"
    "files"
    "lets_encrypt"
    "redis"
)

##
# Shared Functions
##
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

function getMostRecentBackup() {
    local folder=$1
    
    if [ -z "$folder" ]; then
        echo "You must pass the folder name. Exiting..."
        exit 1
    fi

    echo $(find "${BACKUP_ROOT_FOLDER}/${folder}" -type f -printf "%T@ %p\n" | sort -n | cut -d' ' -f 2 | tail -n 1)
}


##
# SETUP
##
function createFolders() {
    local periods=(
        "daily"
        "weekly"
        "monthly"
    )

    for period in "${periods[@]}" 
    do
        for volume in "${VOLUMES[@]}" 
        do
            echoCommand "mkdir -p ${BACKUP_ROOT_FOLDER}/${period}/${volume}"
            mkdir -p "$BACKUP_ROOT_FOLDER/$period/$volume"
        done
    done
}


##
# Daily
##
function removeOldBackupsDaily() {
    # 7 days
    echoCommand "find ${BACKUP_ROOT_FOLDER}/daily -type f -mtime +7 -delete"
    find "${BACKUP_ROOT_FOLDER}/daily" -type f -mtime +7 -delete
}


##
# Weekly
##
function _copyFromDailyToWeekly() {
    local volume=$1

    if [ -z "$volume" ]; then
        echo "You must pass the volume name. Exiting..."
        exit 1
    fi

    local mostRecentFile=$(getMostRecentBackup "daily/$volume")
    local from="$mostRecentFile"
    local to="$BACKUP_ROOT_FOLDER/weekly/$volume" 
    
    echoCommand "cp $from $to"
    cp "$from" "$to"
}

function copyFromDailyToWeekly() {
    for volume in "${VOLUMES[@]}" 
    do
        _copyFromDailyToWeekly "$volume"
    done
}

function removeOldBackupsWeekly() {
    # 30 days
    echoCommand "find ${BACKUP_ROOT_FOLDER}/weekly -type f -mtime +30 -delete"
    find "${BACKUP_ROOT_FOLDER}/weekly" -type f -mtime +30 -delete
}


##
# Monthly
##
function _copyFromWeeklyToMonthly() {
    local volume=$1

    if [ -z "$volume" ]; then
        echo "You must pass the volume name. Exiting..."
        exit 1
    fi

    local mostRecentFile=$(getMostRecentBackup "weekly/$volume")
    local from="$mostRecentFile"
    local to="$BACKUP_ROOT_FOLDER/monthly/$volume" 
    
    echoCommand "cp $from $to"
    cp "$from" "$to"
}

function copyFromWeeklyToMonthly() {
     for volume in "${VOLUMES[@]}" 
    do
        _copyFromWeeklyToMonthly "$volume"
    done
}

function  removeOldBackupsMonthly() {
    #365 days
    echoCommand "find ${BACKUP_ROOT_FOLDER}/monthly -type f -mtime +365 -delete"
    find "${BACKUP_ROOT_FOLDER}/monthly" -type f -mtime +365 -delete
}


##
# Help and Description
##
HELP_MESSAGE="Available commands are:
job:daily           - run daily job
job:weekly          - run weekly job
job:monthly         - run monthly job"

command=$1
if [ -z $command ]; then
    echo "$HELP_MESSAGE"
fi

case $command in
    job:daily)
        removeOldBackupsDaily;;
    job:weekly)
        copyFromDailyToWeekly
        removeOldBackupsWeekly;;
    job:monthly)
        copyFromWeeklyToMonthly
        removeOldBackupsMonthly;;

    setup)
        createFolders;;    

    --help)
        echo "$HELP_MESSAGE";;
    *)
        echo "\"$command\" not available. Use $(basename $0) --help to see available commands.";;
esac

##
# Cron Job Example
# m h dom mon dow
##
# 0     12  *   *   *                   ~/<this-file>.sh job:daily
# 15    12  *   *   6                   ~/<this-file>.sh job:weekly
# 30    12  30  4,6,9,11            *   ~/<this-file>.sh job:monthly
# 30    12  31  1,3,5,7,8,10,12     *   ~/<this-file>.sh job:monthly
# 30    12  28  2   *                   ~/<this-file>.sh job:monthly
