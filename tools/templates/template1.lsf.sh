#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#
# Description: LSF job file.
#
# Revision history:
# 2017-03-15  Created (version 8.1), based on the LSF tmplate
# ---------------------------------------------------------------------------


# LSF Settings
###############################################################################

#BSUB -J h-1.1
#BSUB -W 00:30
#BSUB -R "rusage[mem=400]"
#BSUB -R "select[scratch2]"
#BSUB -R "span[ptile=4]"
#BSUB -n 4
#BSUB -q medium
#BSUB -oo ../workflow/output-files/jobs/job-1.1_%J.out           # File to which standard out will be written
#BSUB -wt '5'
#BSUB -wa 'USR1'

# Job Information
##################################################################################
echo
echo "                    *** Job Information ***                    "
echo "==============================================================="
echo
echo "Environment variables"
echo "------------------------"
env
echo
echo
echo "Job infos by bjobs"
echo "------------------------"
bjobs $LSB_JOBID

# Running the Job - Screening of the Ligands
######################################################################
echo
echo "                    *** Job Output ***                    "
echo "==========================================================="
echo

# Functions
# Standard error response
error_response_std() {
    echo "Error was trapped" 1>&2
    echo "Error in bash script $0" 1>&2
    echo "Error on line $1" 1>&2
    echo "Environment variables" 1>&2
    echo "----------------------------------" 1>&2
    env 1>&2
    if [[ "${error_response}" == "ignore" ]]; then
        echo -e "\n Ignoring error. Trying to continue..."
    elif [[ "${error_response}" == "next_job" ]]; then
        echo -e "\n Ignoring error. Trying to continue and start next job..."
    elif [[ "${error_response}" == "fail" ]]; then
        echo -e "\n Stopping jobline."
        print_job_infos_end
        exit 1
    fi
}
trap 'error_response_std $LINENO' ERR

# Handling signals
time_near_limit() {
    echo "The script ${BASH_SOURCE[0]} caught a time limit signal. Trying to start a new job."
}
trap 'time_near_limit' 10

termination_signal() {
    echo "The script ${BASH_SOURCE[0]} caught a termination signal. Stopping jobline."
    if [[ "${error_response}" == "ignore" ]]; then
        echo -e "\n Ignoring error. Trying to continue..."
    elif [[ "${error_response}" == "next_job" ]]; then
        echo -e "\n Ignoring error. Trying to continue and start next job..."
    elif [[ "${error_response}" == "fail" ]]; then
        echo -e "\n Stopping the jobline."
        print_job_infos_end
        exit 1
    fi
}
trap 'termination_signal' 1 2 3 9 12 15

# Printing final job information
print_job_infos_end() {
    # Job information
    echo
    echo "                     *** Final Job Information ***                    "
    echo "======================================================================"
    echo
    echo "Starting time:" $STARTINGTIME
    echo "Ending time:  " $(date)
    echo
}

# Checking if the queue should be stopped
check_queue_end1() {

    # Determining the controlfile to use for this jobline
    VF_CONTROLFILE=""
    for file in $(ls ../workflow/control/*-* 2>/dev/null|| true); do
        file_basename=$(basename $file)
        jobline_range=${file_basename/.*}
        jobline_no_start=${jobline_range/-*}
        jobline_no_end=${jobline_range/*-}
        if [[ "${jobline_no_start}" -le "${jobline_no}" && "${jobline_no}" -le "${jobline_no_end}" ]]; then
            export VF_CONTROLFILE="${file}"
            break
        fi
    done
    if [ -z "${VF_CONTROLFILE}" ]; then
        export VF_CONTROLFILE="../workflow/control/all.ctrl"
    fi

    # Checking if the queue should be stopped
    line="$(cat ${VF_CONTROLFILE} | grep "stop_after_current_docking=")"
    stop_after_current_docking=${line/"stop_after_current_docking="}
    if [ "${stop_after_current_docking}" = "yes" ]; then
        echo
        echo "This job line was stopped by the stop_after_current_docking flag in the controlfile ${VF_CONTROLFILE}."
        echo
        print_job_infos_end
        exit 0
    fi

    # Checking if there are still ligand collections to-do
    no_collections_incomplete="0"
    i=0
    # Using a loop to try several times if there are no ligand collections left - maybe the files where just shortly inaccessible
    while [ "${no_collections_incomplete}" == "0" ]; do
        no_collections_incomplete="$(cat ../workflow/ligand-collections/todo/todo.all* ../workflow/ligand-collections/todo/${jobline_no}-* ../workflow/ligand-collections/current/${jobline_no}-* 2>/dev/null | grep -c "[^[:blank:]]" || true)"
        i="$((i + 1))"
        if [ "${i}" == "5" ]; then
            break
        fi
        sleep 1
    done
    if [[ "${no_collections_incomplete}" = "0" ]]; then
        echo
        echo "This job line was stopped because there are no ligand collections left."
        echo
        print_job_infos_end
        exit 0
    fi
}

check_queue_end2() {
    check_queue_end1
    line=$(cat ${VF_CONTROLFILE} | grep "stop_after_job=")
    stop_after_job=${line/"stop_after_job="}
    if [ "${stop_after_job}" = "yes" ]; then
        echo
        echo "This job line was stopped by the stop_after_job flag in the controlfile ${VF_CONTROLFILE}."
        echo
        print_job_infos_end
        exit 0
    fi
}

# Creating the /tmp/${USER} folder if not present
if [ ! -d "/tmp/${USER}" ]; then
    mkdir -p /tmp/${USER}
fi

# Setting important variables
job_line=$(grep -m 1 -- "-J " $0)
jobname=${job_line/"#BSUB -J "}
export old_job_no=${jobname/[a-zA-Z]-}
export old_job_no_2=${old_job_no/*.}
export queue_no_1=${old_job_no/.*}
export jobline_no=${queue_no_1}
export batch_system="LSF"
export sleep_time_1="1"
export STARTINGTIME=`date`
export start_time_seconds="$(date +%s)"
#export job_line=$(grep -m 1 "nodes=" ../workflow/job-files/main/${jobline_no}.job)
#export nodes_per_job=${job_line/"#SBATCH --nodes="}
#export nodes_per_job=${SLURM_JOB_NUM_NODES}
export nodes_per_job=1
export LC_ALL=C
export LANG=C


# Determining the controlfile to use for this jobline
VF_CONTROLFILE=""
for file in $(ls ../workflow/control/*-* 2>/dev/null|| true); do
    file_basename=$(basename $file)
    jobline_range=${file_basename/.*}
    jobline_no_start=${jobline_range/-*}
    jobline_no_end=${jobline_no_end/-*}
    if [[ "${jobline_no_start}" -le "${jobline_no}" && "${jobline_no}" -le "${jobline_no_end}" ]]; then
        export VF_CONTROLFILE="${file}"
        break
    fi
done
if [ -z "${VF_CONTROLFILE}" ]; then
    export VF_CONTROLFILE="../workflow/control/all.ctrl"
fi

# Verbosity
VF_VERBOSITY_LOGFILES="$(grep -m 1 "^verbosity_logfiles=" ${VF_CONTROLFILE} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
export VF_VERBOSITY_LOGFILES
if [ "${VF_VERBOSITY_LOGFILES}" = "debug" ]; then
    set -x
fi

# Setting the job letter1
line=$(cat ${VF_CONTROLFILE} | grep -m 1 "^job_letter=")
export job_letter=${line/"job_letter="}

# Setting the verbosity level
line=$(cat ${VF_CONTROLFILE} | grep -m 1 "^verbosity=")
export verbosity=${line/"verbosity="}
if [[ "${verbosity}" == "debug" ]]; then
    set -x
fi

# Setting the error sensitivity
line=$(cat ${VF_CONTROLFILE} | grep -m 1 "^error_sensitivity=")
export error_sensitivity=${line/"error_sensitivity="}
if [[ "${error_sensitivity}" == "high" ]]; then
    set -uo pipefail
    trap '' PIPE        # SIGPIPE = exit code 141, means broken pipe. Happens often, e.g. if head is listening and got all the lines it needs.
fi

# Setting the error response
line=$(cat ${VF_CONTROLFILE} | grep -m 1 "^error_response=")
export error_response=${line/"error_response="}

# Checking if the queue should be stopped
check_queue_end1

# Getting the available wallclock time
job_line=$(grep -m 1 --  "-W " ../workflow/job-files/main/${jobline_no}.job)
timelimit=${job_line/"#BSUB -W"}
export timelimit_seconds="$(echo -n "${timelimit}" | awk -F ':' '{print $2 * 60 + $1 * 3600 }')"

# Getting the number of queues per step
line=$(cat ${VF_CONTROLFILE} | grep -m 1 "^queues_per_step=")
export queues_per_step=${line/"queues_per_step="}

# Preparing the to-do lists for the queues
cd slave
bash prepare-todolists.sh ${jobline_no} ${nodes_per_job} ${queues_per_step}
cd ..

# Starting the individual steps on different nodes
for step_no in $(seq 1 ${nodes_per_job} ); do
    export step_no
    echo "Starting job step $step_no on host $(hostname)."
    bash ../workflow/job-files/sub/one-step.sh &
    sleep "${sleep_time_1}"
done


# Waiting for all steps to finish
wait


# Creating the next job
#####################################################################################
echo
echo
echo "                  *** Preparing the next batch system job ***                     "
echo "=================================================================================="
echo

# Checking if the queue should be stopped
check_queue_end2

# Syncing the new jobfile with the settings in the controlfile
cd slave
. sync-jobfile.sh ${jobline_no}
cd ..

# Changing the job name
new_job_no_2=$((old_job_no_2 + 1))
new_job_no="${jobline_no}.${new_job_no_2}"
sed -i "s/^#BSUB -J ${job_letter}-.*/#BSUB -J ${job_letter}-${new_job_no}/g" ../workflow/job-files/main/${jobline_no}.job

# Changing the output filenames
sed -i "s|^#BSUB -oo ../workflow/output-files/jobs/job-${old_job_no}_%J.out|#BSUB -oo ../workflow/output-files/jobs/job-${new_job_no}_%J.out|g" ../workflow/job-files/main/${jobline_no}.job

# Checking how much time has passed since the job has been started
end_time_seconds="$(date +%s)"
time_diff="$((end_time_seconds - start_time_seconds))"
treshhold=100
if [ "${time_diff}" -le "${treshhold}" ]; then
    echo "Since the beginning of the job less than ${treshhold} seconds have passed."
    echo "Sleeping for some while to prevent a job submission run..."
    sleep 120
fi

# Submitting a new new job
cd slave
. submit.sh ../workflow/job-files/main/${jobline_no}.job
cd ..


# Finalizing the job
#####################################################################################
print_job_infos_end
