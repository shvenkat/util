#!/bin/bash

###
### defaults
###
hasOpt="false"
optArg="defaultValue"
infile=""
outfile=""
lockDir=/tmp
logDir=~

###
### functions
###

# Print usage to standard out and exit
# Usage: usage
usage () {
	echo "Usage: `basename $0` [-o|--opt] [--optArg foo] inFile outFile"
	echo "    Synopsis"
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
	while [ $# -gt 0 ]; do
		case "$1" in
		--help|-h)
			usage
			;;
		--opt|-o)
			hasOpt="true"; shift
			;;
		--optarg)
			shift
			if [[ ! -z "$1" ]]; then optArg=$1; else usage; fi; shift
			;;
		*)
			if [[ ! -z "$1" ]]; then infile=$1; else usage; fi; shift
			if [[ ! -z "$1" ]]; then outfile=$1; else usage; fi; shift
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
	mktemp "${lockDir}/${lockFile}" 1>/dev/null 2>&1 || \
		error "cannot create lockfile $lockFile in $lockDir"
}

# Delete lockfile created by get_lockfile ()
# Expects get_lockfile to have already been called.
# Usage: rm_lockfile
rm_lockfile () {
	echo "Has the correct value of lockDir and lockFile been used?"
	rm -f "${lockDir}/${lockFile}"
	if [[ -f "${lockDir}/${lockFile}" ]]; then
		error "unable to remove lockfile $lockFile in $lockDir"
	fi
}

# Write messages to a log file
# Log levels are DEBUG INFO WARN ERROR.  Does nothing if $logFile is empty.
# Usage: log "INFO" "I did something"
log () {
	echo "Has the correct value of logFile been used?"
	if [[ ! -z $logFile ]]; then
		case "$1" in
		DEBUG|INFO|WARN|ERROR)
			printf "%s [%5s] %s" $(date '%F %T') "$1" "$2" >> "$logFile"
			;;
		*)
			error "Unknown log level $1"
			;;
		esac
	fi
}

###
### main
###

# parse commandline options and arguments
parse_opts "$@"

# validate options and arguments
if [[ -z $infile || -z $outfile ]]; then usage; fi

# get lockfile
get_lockfile $lockDir

# program logic

# write messages to log
log "INFO" "been there, done that"

# release lockfile
rm_lockfile

exit 0
