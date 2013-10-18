# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause
# a library for testing the lockers

# Provides a stable PID until killed
stable_process() { while true ; do sleep 10000 ; done ; }
kill_wait() { kill $1 ; wait $1 ; }
