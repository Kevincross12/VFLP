#!/bin/bash
# ---------------------------------------------------------------------------
#
# Description: Automatically finds the joblines with jobline numbers between first/last_jobline_no which are not running and continues the jobline. 
#
# Option: quiet (optional)
#    Possible values: 
#        quiet: No information is displayed on the screen.
#
# Revision history:
# 2015-12-28  Import of file from JANINA version 2.2 and adaption to STELLAR version 6.1
# 2016-07-16  Various improvements
#
# ---------------------------------------------------------------------------

#Checking the input arguments
usage="Usage: vf_continue_jobline.sh first_jobline_no last_jobline_no job_template delay_time_in_seconds [quiet]"
if [ "${1}" == "-h" ]; then
    echo -e "\n${usage}\n\n"
    exit 0 
fi

if [[ "$#" -ne "4" ]] && [[ "$#" -ne "5" ]]; then
    echo -e "\nWrong number of arguments. Exiting.\n"
    echo -e "${usage}\n\n"
    exit 1
fi

# Displaying the banner
if [[ "$0" != "$BASH_SOURCE" ]]; then # test if the script was sourced or executed
    echo
    echo
    . slave/show_banner.sh
    echo
    echo
fi

# Standard error response 
error_response_nonstd() {
    echo "Error was trapped which is a nonstandard error."
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})"
    echo "Error on line $1"
    exit 1
}
trap 'error_response_nonstd $LINENO' ERR

# Variables
first_jobline_no=${1}
last_jobline_no=${2}
job_template=${3}
line=$(grep -m 1 "^job_letter" ../workflow/control/all.ctrl)
job_letter=${line/"job_letter="}
controlfile="../workflow/control/all.ctrl"

# Verbosity
VF_VERBOSITY_COMMANDS="$(grep -m 1 "^verbosity_commands=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export VF_VERBOSITY_COMMANDS
if [ "${VF_VERBOSITY_COMMANDS}" = "debug" ]; then
    set -x
fi

# Formatting screen output
echo "" 

# Removing old files if existens
if [ -f "tmp/jobs-to-continue" ]; then
    rm tmp/jobs-to-continue
fi
mkdir -p tmp

# Storing all the jobs which are currently running
touch tmp/jobs-all
bin/sqs > tmp/jobs-all 2>/dev/null || true

# Storing all joblines which have to be restarted
echo "Checking which joblines are already in the batchsystem"
for jobline_no in $(seq ${first_jobline_no} ${last_jobline_no}); do 
    if ! grep -q "${job_letter}\-${jobline_no}\."  tmp/jobs-all; then 
        echo "Adding jobline ${jobline_no} to the list of joblines to be continued."
        echo ${jobline_no} >> "tmp/jobs-to-continue"
    else
        echo "Omitting jobline ${jobline_no} because it was found in the batchsystem."
    fi
done

# Variables
k=0
delay_time="${4}"

# Resetting the collections and continuing the jobs if existent
if [ -f tmp/jobs-to-continue ]; then
    k_max="$(cat tmp/jobs-to-continue | wc -l)"
    for jobline_no in $(cat tmp/jobs-to-continue ); do
        k=$(( k + 1 ))
        cd slave
        echo "Continuing jobline ${jobline_no}"
        . exchange-continue-jobline.sh ${jobline_no} ${jobline_no} ${job_template} quiet
        cd ..
        if [ ! "${k}" = "${k_max}" ]; then
            sleep ${delay_time}
        fi
    done
fi

# Removing the temporary files
if [ -f "tmp/jobs-all" ]; then
    rm tmp/jobs-all
fi
if [ -f "tmp/jobs-to-continue" ]; then
    rm tmp/jobs-to-continue
fi

# Displaying some information
if [[ ! "$*" = *"quiet"* ]]; then
    echo "Number of joblines which were continued: ${k}"
    echo
fi
