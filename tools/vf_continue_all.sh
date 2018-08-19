#!/usr/bin/env bash

#Checking the input arguments
usage="Usage: vf_continue_all.sh <job template> <delay_time_in_seconds>"
if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0
fi
if [ "$#" -ne "2" ]; then
   echo -e "\nWrong number of arguments. Exiting."
   echo -e "\n${usage}\n\n"
   exit 1
fi

# Displaying the banner
echo
echo
. slave/show_banner.sh
echo
echo

# Standard error response 
error_response_nonstd() {
    echo "Error was trapped which is a nonstandard error."
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})"
    echo "Error on line $1"
    exit 1
}
trap 'error_response_nonstd $LINENO' ERR

# Variables
delay_time=$2
line=$(grep -m 1 "^job_letter" ../workflow/control/all.ctrl)
job_letter=${line/"job_letter="}
job_template=$1
no_of_jobfiles=$(ls ../workflow/job-files/main/ | wc -l)

# Body
cat /dev/null > tmp/sqs.out
bin/sqs > tmp/sqs.out || true


# Loop for each jobfile
counter=1
for file in $(ls ../workflow/job-files/main/); do
    jobline_no=${file/.job}
    if ! grep -q "${job_letter}\-${jobline_no}\." tmp/sqs.out; then
        vf_continue_jobline.sh ${jobline_no} ${jobline_no} ${job_template} 1
        if [ ! "${counter}" -eq "${no_of_jobfiles}" ]; then
            sleep $delay_time
        fi
    fi
    counter=$((counter + 1))
done

rm tmp/sqs.out
