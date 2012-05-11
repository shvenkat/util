#!/bin/bash

RSYNC=/home/shvenkat/bin/rsync
SSH="ssh -o IdentityFile=/home/shvenkat/.ssh/id_rsa_alternate"
SRC=/scratch/shvenkat/system.tgz.gpg
DST_DIR=/scratch/shvenkat
DST_BASE=system.tgz.gpg
TMP_BASE=system.tgz.gpg.inProgress

usage() {
    echo "Usage: `basename $0` hostname [check]"
    echo "    Atomically updates (or checks) a backup of $SRC in $DST_DIR on hostname"
    exit 1
}

if [ $# -ne 1 -a $# -ne 2 ]; then
    usage
fi
host=$1
check=$2

case "$check" in
check)
    echo "Checking backup ${DST_DIR}/${DST_BASE} on $host ... "
    if $($SSH $host test -f ${DST_DIR}/${DST_BASE} -a ! -e ${DST_DIR}/${TMP_BASE}); then
        echo "Check PASSED"
        retval=0
    else
        echo "Check FAILED"
        retval=1
    fi
    ;;
'')
    echo "Backing up $SRC to $DST_DIR on $host ..."
    $SSH $host rm -rf ${DST_DIR}/${TMP_BASE} \
        && $RSYNC -aHSz --delete \
            --rsh="$SSH" \
            --rsync-path=${RSYNC} \
            --verbose --human-readable --log-file=${HOME}/tmp/$(basename $0).${host}.rsync.log \
            ${SRC} \
            ${host}:${DST_DIR}/${TMP_BASE} > /dev/null \
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
