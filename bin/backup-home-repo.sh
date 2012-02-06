#!/bin/bash

GIT=/home/shvenkat/opt/git-1.7.8.4/bin/git
RSYNC=/home/shvenkat/bin/rsync
SSH="ssh -o IdentityFile=/home/shvenkat/.ssh/id_rsa_alternate"
SRC=/user-snapshots/shvenkat.git
DST_DIR=/scratch/shvenkat
DST_BASE=shvenkat.git
TMP_BASE=shvenkat.git.inProgress

usage() {
    echo "Usage: `basename $0` hostname [check]"
    echo "    Atomically updates (or checks) a backup of the git repo $SRC in $DST_DIR on hostname"
    exit 1
}

if [ $# -ne 1 -a $# -ne 2 ]; then
    usage
fi
host=$1
check=$2

case "$check" in
check)
    echo "Checking backup git repo ${DST_DIR}/${DST_BASE} on $host ... "
    if [ $($SSH $host $GIT --git-dir ${DST_DIR}/${DST_BASE} --bare log --oneline 2>/dev/null | wc -l) -lt 10 ]; then
    	echo "Check FAILED"
        retval=1
    else
        echo "Check PASSED"
        retval=0
    fi
    ;;
'')
    echo "Checking source git repo $SRC ... "
    if [ $($GIT --git-dir $SRC --bare log --oneline 2>/dev/null | wc -l) -lt 10 ]; then
        echo "Check FAILED: git repo too small or not valid; backup skipped" 1>&2
        exit 1
    fi
    echo "Check PASSED"
    
    echo "Backing up git repo $SRC to $DST_DIR on $host ..."
    $SSH $host rm -rf ${DST_DIR}/${TMP_BASE} \
        && $RSYNC -aHScz --delete \
            --rsh="$SSH" \
            --rsync-path=${RSYNC} \
            --link-dest=../${DST_BASE}/ \
            --verbose --human-readable --log-file=${HOME}/tmp/$(basename $0).${host}.rsync.log \
            ${SRC}/ \
            ${host}:${DST_DIR}/${TMP_BASE}/ > /dev/null \
        && $SSH $host rm -rf ${DST_DIR}/${DST_BASE} \
        && $SSH $host mv ${DST_DIR}/${TMP_BASE} ${DST_DIR}/${DST_BASE} \
        && $SSH $host sync
    retval=$?
    if [ $retval -eq 0 ]; then
    	echo "Backup DONE"
    else
        echo "Backup FAILED"
    fi
    ;;
*)
    usage
    exit 1
    ;;
esac

exit $retval
