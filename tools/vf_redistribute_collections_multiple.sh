#!/usr/bin/env bash

#Checking the input arguments
usage="Usage: vf_redistribute_collections_multiple.sh <input_collection_file> <queues_per_step_new> <nodes_per_job_new> <job_no> <collections_per_queue> <output_folder>

<collections_per_queue> collection will be placed per collection file/queue."


if [ "${1}" == "-h" ]; then
   echo -e "\n${usage}\n\n"
   exit 0
fi
if [ "$#" -ne "6" ]; then
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
input_collection_file=$1
queues_per_step_new=$2
nodes_per_job_new=$3
job_no=$4
collections_per_queue=$5
output_folder=$6
export VF_CONTROLFILE="../workflow/control/all.ctrl"

# Verbosity
VF_VERBOSITY_COMMANDS="$(grep -m 1 "^verbosity_commands=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export VF_VERBOSITY_COMMANDS
if [ "${VF_VERBOSITY_COMMANDS}" = "debug" ]; then
    set -x
fi

# Preparing the directory
echo -e " *** Preparing the output directory ***\n"
#rm ${output_folder}/* 2>/dev/null || true

# Loop for each collection
queue_no=1
step_no=1
echo -e " *** Starting to distribute the collections ***\n"
sed -i "s/^$//g" ${input_collection_file}
for i in $(seq 1 $collections_per_queue); do
    for step_no in $(seq 1 ${nodes_per_job_new}); do
        for queue_no in $(seq 1 ${queues_per_step_new}); do
            collection=$(head -n 1 ${input_collection_file})
            collection=$(echo ${collection} | tr -d '\040\011\012\015' )
            if [[ ${collection} == *"_"* ]]; then
                echo " * Assigning collection ${collection} to queue $job_no-$step_no-$queue_no"
                echo ${collection} >> ${output_folder}/${job_no}-${step_no}-${queue_no}
                sed -i "/${collection}/d" ${input_collection_file} || true
            fi
        done
    done
done

echo -e "\n * Resdistribution complete\n\n"

