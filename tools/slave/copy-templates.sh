#!/bin/bash
# ---------------------------------------------------------------------------
##
# Usage: . copy-templates.sh templates [quiet]
#
# Description: Copies the template-files from the ../templates folder to the proper places in the ../../workflow folder. 
#
# Option: templates
#    Possible values: 
#        subjobfiles: ../templates/one-step.sh and ../templates/one-queue.sh are copied to ../../worflow/job-files/sub/
#        todofiles: ../templates/todo.all is copied to ../../workflow/ligand-collections/todo/todo.all and ../../workflow/ligand-collections/var/todo.original
#        controlfiles: ../templates/all.ctrl is copied to ../../workflow/control/
#        all: all of the above templates
#
# Option: quiet (optional)
#    Possible values: 
#        quiet: No information is displayed on the screen.
#
# Revision history:
# 2015-12-12  Created (version 1.10)
# 2015-12-16  Adaption to version 2.1
# 2016-03-06  Small improvements (version 2.3)
# 2016-07-16  Various improvements
#
# ---------------------------------------------------------------------------

# Displaying help if the first argument is -h
usage="Usage: . copy-templates templates [quiet]"
if [ "${1}" = "-h" ]; then
    echo "${usage}"
    return
fi

# Standard error response
error_response_nonstd() {
    echo "Error was trapped which is a nonstandard error."
    echo "Error in bash script $(basename ${BASH_SOURCE[0]})"
    echo "Error on line $1"
    exit 1
}
trap 'error_response_nonstd $LINENO' ERR

# Copying the template files
if [[ "${1}" = "subjobfiles" || "${1}" = "all" ]]; then
    cp ../templates/one-step.sh ../../workflow/job-files/sub/
    cp ../templates/one-queue.sh ../../workflow/job-files/sub/
    chmod u+x ../../workflow/job-files/sub/one-step.sh
fi
if [[ "${1}" = "todofiles" || "${1}" = "all" ]]; then
    cp -i ../templates/todo.all ../../workflow/ligand-collections/todo/
    cp -i ../templates/todo.all ../../workflow/ligand-collections/var/todo.original
fi
if [[ "${1}" = "controlfiles" || "${1}" = "all" ]]; then
    cp -i ../templates/all.ctrl ../../workflow/control/
fi

# Displaying some information
if [[ ! "$*" = *"quiet"* ]]; then
    echo
    echo "The templates were copied."
    echo
fi
