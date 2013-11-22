# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause
# a library for testing the lockers

# Provides a stable PID until killed or orphaned
stable_process() {
    local pid=$BASHPID # pid to check for orphanage

    # If $3 (PPID) is init (1), then the parent is no longer running
    while ps -f $pid|awk '$3==1{exit 1}' ; do
        sleep 10
    done
}

kill_wait() { kill $1 ; wait $1 ; }
