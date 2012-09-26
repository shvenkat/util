#!/bin/bash

###
### DEFAULTS
###
declare -a src
dst=""
filterFile=""
gzBackupFile=""
doChecksum=false
lockDir=/tmp
logDir=~/tmp
doDryRun=false

###
### FUNCTIONS
###

# Print usage to standard out and exit
# Usage: usage
usage () {
	echo "Usage: `basename $0` src [src2 ...] dst"
	echo "    Backs up src (and src2 ...) to dst using rsync"
	echo "Options:" 
	echo "    --filter file    paths to exclude (rsync filter format file)"
	echo "    --gz-backup file files to be compressed (rsync exclude format file)"
	echo "    --checksum       update based on checksum, not mod-time and size"
	echo "    --lockdir dir    location of lock file [${lockDir}]"
	echo "    --logdir dir     location of log file [${logDir}]"
	echo "    --dry-run        show what would be backed up"
	exit 1
}

# Print error message to standard error and exit
# Usage: error "there is no hope"
error () {
	echo "$(basename $0): $1" 1>&2
	exit 1
}

# Parse options and arguments, setting appropriate variables
# Expects default values to have already been set.  Does not validate usage.
# Usage: parse_opts "$@"
parse_opts () {
	#echo "parse_opts: $# args, $@"
	while [ $# -gt 0 ]; do
		#echo "parse_opts: parsing $1 ..."
		case "$1" in
		--help)
			usage
			;;
		--filter)
			shift
			if [[ ! -z "$1" ]]; then filterFile=$1; else usage; fi; shift
			;;
		--gz-backup)
			shift
			if [[ ! -z "$1" ]]; then gzBackupFile=$1; else usage; fi; shift
			;;
		--checksum)
			shift
			doChecksum="true"
			;;
		--lockdir)
			shift
			if [[ ! -z "$1" ]]; then lockDir=$1; else usage; fi; shift
			;;
		--logDir)
			shift
			if [[ ! -z "$1" ]]; then logDir=$1; else usage; fi; shift
			;;
		--dry-run)
			shift
			doDryRun="true"
			;;
		--*)
			error "unknown option $1"
			;;
		*)
			push_src () {
    			src=("${src[@]}" "$1")
			}
			while [[ $# -gt 1 ]]; do
				if [[ ! -z "$1" ]]; then push_src "$1"; else usage; fi; shift
			done
			if [[ ! -z "$1" ]]; then dst=$1; else usage; fi
			break
			;;
		esac
	done
}

# Create lockfile or exit
# Usage: get_lockfile lockDir [lockFile]
get_lockfile () {
	lockDir=$1
	if [[ ! -z $2 ]]; then
		lockFile=$2
	else
		lockFile="$(basename $0).lock"
	fi
	#echo "get_lockfile: creating lock file ${lockDir}/${lockFile} ..."
	#mktemp "${lockDir}/${lockFile}"
	if [[ ! -f "${lockDir}/${lockFile}" ]]; then
		:
	else
		# Check that the lock file has not been abandoned
		pid=$(cat "${lockDir}/${lockFile}")
		if ps -p $pid | grep -q $pid; then
			error "$lockFile already in use by another instance of this program"
		else
			:
		fi
	fi
	echo $$ > "${lockDir}/${lockFile}"
	retval=$?
	if [[ $retval -ne 0 ]]; then
		error "cannot create lockfile $lockFile in $lockDir"
	fi
}

# Delete lockfile created by get_lockfile ()
# Expects get_lockfile to have already been called.
# Usage: rm_lockfile
rm_lockfile () {
	#echo "rm_lockfile: removing lockfile ${lockDir}/${lockFile} ..."
	rm -f "${lockDir}/${lockFile}"
	if [[ -f "${lockDir}/${lockFile}" ]]; then
		error "unable to remove lockfile $lockFile in $lockDir"
	fi
}

# Write messages to a log file
# Log levels are DEBUG INFO WARN ERROR.  Does nothing if $logFile is empty.
# Usage: log "INFO" "I did something"
log () {
	#echo "log: logging to $logFile ..."
	if [[ ! -z $logFile ]]; then
		case "$1" in
		DEBUG|INFO|WARN|ERROR)
			printf "%s [%5i] %s: %s\n" "$(date '+%F %T')" $$ "$1" "$2" >> "$logFile"
			;;
		*)
			error "Unknown log level $1"
			;;
		esac
	fi
}

###
### MAIN
###

# show usage
if [[ $# -eq 0 ]]; then usage; fi

# parse commandline options and arguments
parse_opts "$@"

# validate options and arguments
if [[ ${#src[@]} -lt 1 || -z $dst ]]; then usage; fi
if [[ ! -z $filterFile && ! -f $filterFile ]]; then
	error "$filterFile does not exist"
fi
if [[ ! -z $gzBackupFile && ! -f $gzBackupFile ]]; then
	error "$gzBackupFile does not exist"
fi
logFile="${logDir}/$(basename $0).log"

# get lockfile
get_lockfile "$lockDir"

if [[ $doDryRun == 'true' ]]; then
	log "INFO" "$(basename $0) started - DRY RUN"
else
	log "INFO" "$(basename $0) started"
fi

# compress large sparse files e.g. disk images
if [[ ! -z $gzBackupFile ]]; then
	while read path ; do
		for srcDir in "${src[@]}"; do
			file="${srcDir}/${path}"
			if [ -f "$file" -a \( ! -f "${file}.gz" -o "$file" -nt "${file}.gz" \) ]; then 
				log "INFO" "gzip-ing ${path}"
				if [[ $doDryRun != "true" ]]; then
					gzip -c "$file" > "${file}.gz" || { \
						log "ERROR" "gzip-ing $path failed"
						error "gzip-ing $path failed"
					}
				fi
				break
			fi
		done
	done < "$gzBackupFile"
fi

# run rsync to backup
# other useful rsync options -R -W -O -c -T -s --stats -h -i -v
declare -a rsyncOpts
push_rsyncOpts () {
    rsyncOpts=("${rsyncOpts[@]}" "$1")
}
if [[ $doDryRun == "true" ]]; then
	push_rsyncOpts '--dry-run'
fi
# basic options
#rsyncOpts='-rltO --delete --protect-args'
push_rsyncOpts '-rtlO'
push_rsyncOpts '--delete'
push_rsyncOpts '--protect-args'
if [[ $doChecksum == "true" ]]; then
	#rsyncOpts="$rsyncOpts --checksum"
	push_rsyncOpts '--checksum'
fi
# keep the previously backed up version of each file
#rsyncOpts="$rsyncOpts --backup --backup-dir=.preTrash --filter=P_/.preTrash/***"
push_rsyncOpts '--backup'
push_rsyncOpts '--backup-dir=.preTrash/'
push_rsyncOpts '--filter=P /.preTrash/***'
# make updates somewhat atomic
#rsyncOpts="$rsyncOpts --delete-delay --delay-updates"
push_rsyncOpts '--delete-delay'
push_rsyncOpts '--delay-updates'
# keep partially transferred files to speed up the next backup
#rsyncOpts="$rsyncOpts --partial --partial-dir=.rsync-partial --filter=R_.rsync-partial/"
push_rsyncOpts '--partial'
push_rsyncOpts '--partial-dir=.rsync-partial'
push_rsyncOpts '--filter=R .rsync-partial'
# exclude specific paths
if [[ ! -z $gzBackupFile ]]; then
	#rsyncOpts="$rsyncOpts --exclude-from=${gzBackupFile}"
	push_rsyncOpts "--exclude-from=${gzBackupFile}"
fi
if [[ ! -z $filterFile ]]; then
	#rsyncOpts="$rsyncOpts --filter=._${filterFile}"
	push_rsyncOpts "--filter=. $filterFile"
fi
# report what is being backed up
#rsyncOpts="$rsyncOpts --log-file=$logFile --itemize-changes -v"
push_rsyncOpts '--itemize-changes'
push_rsyncOpts '--out-format=%t [%5p] %i %n%L'
#push_rsyncOpts '--verbose'
#push_rsyncOpts '--human-readable'
#push_rsyncOpts "--log-file=${logFile}"
log "INFO" "backing up ${src[@]} to $dst using rsync"
#echo "rsync ${rsyncOpts[@]} ${src[@]} $dst"
rsync "${rsyncOpts[@]}" "${src[@]}" "$dst" >> "$logFile"
retval=$?

# release lockfile
rm_lockfile

if [[ $retval -eq 0 ]]; then
	if [[ $doDryRun == 'true' ]]; then
		log "INFO" "$(basename $0) done - DRY RUN"
	else
		log "INFO" "$(basename $0) done"
	fi
else
	log "ERROR" "rsync exited with status $retval"
	error "rsync exited with status $retval"
fi
exit $retval
