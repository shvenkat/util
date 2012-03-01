#!/bin/bash

#
# set parameters
#
declare -a SRC EXCLUDE
RSYNC=/home/shvenkat/bin/rsync
SRC=(/ /boot)
DST_DIR=/system-snapshots/
DST_PREFIX=system-snapshot-
EXCLUDE=(/system-snapshots/ /user-snapshots/ lost+found/ '/tmp/*')
doDryRun="false"

#
# functions
#
usage () {
	echo "Usage: `basename $0`"
	echo "    Backs up the system using time-stamped snapshots. Unchanged files"
	echo "    are hardlinked from the previous snapshot, minimizing redundancy."
	echo "Options:" 
	echo "    --dry-run        show what would be backed up"
	exit 1
}

error () {
	echo "$(basename $0): $1" 1>&2
	exit 1
}

#
# parse options
#
while [ $# -gt 0 ]; do
	case "$1" in
	--help)
		usage
		;;
	--dry-run)
		shift
		doDryRun="true"
		;;
	*)
		error "unknown option $1"
		;;
	esac
done

#
# determine previous backup dir and this backup dir
#
prev_dir=$(find "$DST_DIR" -mindepth 1 -maxdepth 1 -type d -print | \
           sort -r | head -n1)
#prev_dir=$(basename "$prev_dir")
#prev_time=${prev_dir#"${DST_PREFIX}"}
#prev_time=$(echo "$prev_time" | grep -oP '\d{4}-\d{2}-\d{2}-\d{4}$')
if [[ -z $prev_dir ]]; then
	error "Unable to locate previous backup"
fi
this_time=$(date '+%F-%H%M')
dst="${DST_DIR}/${DST_PREFIX}${this_time}/"
log="${DST_DIR}/${DST_PREFIX}${this_time}.rsync.log"

#
# gather rsync options
#
declare -a rsyncOpts
push_rsyncOpts () {
    rsyncOpts=("${rsyncOpts[@]}" "$1")
}

if [[ $doDryRun == "true" ]]; then
	push_rsyncOpts '--dry-run'
fi
push_rsyncOpts '--archive'
push_rsyncOpts '--delete'
push_rsyncOpts '--hard-links'
push_rsyncOpts '--one-file-system'
push_rsyncOpts '--sparse'
push_rsyncOpts '--super'
for exclude in "${EXCLUDE[@]}"; do
	push_rsyncOpts "--exclude=${exclude}"
done
push_rsyncOpts '--delete-excluded'
push_rsyncOpts '--verbose'
push_rsyncOpts '--human-readable'
push_rsyncOpts '--itemize-changes'
push_rsyncOpts '--out-format=%t [%5p] %i %n%L'
#push_rsyncOpts "--log-file=${log}"
push_rsyncOpts "--link-dest=${prev_dir}/"

#
# perform backup
#
#echo "$RSYNC" "${rsyncOpts[@]}" "${SRC[@]}" "$dst" ">" "$log"
if [[ $doDryRun == "true" ]]; then
	"$RSYNC" "${rsyncOpts[@]}" "${SRC[@]}" "$dst"
else
	"$RSYNC" "${rsyncOpts[@]}" "${SRC[@]}" "$dst" > "$log"
fi
