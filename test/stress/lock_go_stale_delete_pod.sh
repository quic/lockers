#!/usr/bin/env bash
#
# Copyright (c) 2021, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

readlink --canonicalize / &> /dev/null || readlink() { greadlink "$@" ; } # for MacOS
MYPROG=$(readlink -f -- "$0")
MYDIR=$(dirname -- "$MYPROG")
source "$MYDIR"/../k8s/lib_k8s.sh

usage() { # error_message
    local prog=$(basename -- "$0")
    cat >&2 <<EOF

    usage: $prog -h|--help
           $prog -d <deployment> --dir <lock file> [-n <namespace>]

    Repeatedly acquires lock on the latest pod in given deployment
    and makes it stale by deleting the pod.

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 1
}

LOCKER="/home/locker_user/lockers/lock_k8s.sh"

while [ $# -gt 0 ] ; do
    case "$1" in
        -h|--help)       usage ;;
        -d|--deployment) K8S_DEPLOYMENT=$2 ; shift ;;
        -n|--namespace)  K8S_NAMESPACE=$2 ; shift ;;
        --dir)           DIR=$2 ; shift ;;
    esac
    shift
done

get_lock() { # pod process
    k8s_exec "$1" "$LOCKER" lock "$DIR"/lock "$2" 2>/dev/null
}

[ -z "$K8S_DEPLOYMENT" ] && k8s_die "set -d|--deployment"
[ -z "$DIR" ] && k8s_die "set --dir"

while true ; do
    POD=$(k8s_get_pods | awk 'END {print}')
    PROCESS=$(k8s_stable_process "$POD")
    while ! get_lock "$POD" "$PROCESS" ; do : ; done
    kubectl delete pod "$POD"
done
