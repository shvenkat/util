#!/bin/bash

usage() {
    echo "Usage: `basename $0` file"
    echo "    Prints the age of the file in seconds"
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi
file=$1

if [[ ! -e "$file" ]]; then
	echo "File '${file}' does not exist"
	exit 1
fi

echo $(( $(date '+%s') - $(stat -c '%Y' "$file") ))
