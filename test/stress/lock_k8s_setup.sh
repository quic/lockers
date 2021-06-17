#!/usr/bin/env bash
#
# Copyright (c) 2021, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

readlink --canonicalize / &> /dev/null || readlink() { greadlink "$@" ; } # for MacOS
MYPROG=$(readlink -f -- "$0")
MYDIR=$(dirname -- "$MYPROG")
MYNAME=$(basename -- "$MYPROG")
source "$MYDIR"/../k8s/lib_k8s.sh

usage() { # error_message
    local k8s_msg=$(k8s_usage)
    cat <<-EOF
    Usage:
        $k8s_msg

    Refer to $MYDIR/../k8s/README.md for more information.

EOF

    [ -n "$1" ] && echo -e '\n'"ERROR: $1"
    exit 1
}

while [ $# -gt 0 ] ; do
    case "$1" in
        -h|--help)    usage ;;
        *)            k8s_parse_arg "$@" ; args=$? ; [ "$args" = 0 ] && usage ; shift $args ;;
    esac
done

K8S_PVC_NAME="lockers-repo"
K8S_YAMLS_DIR=$MYDIR/../k8s
K8S_DOCKER_CONTEXT="$MYDIR"/../../
K8S_DEPLOYMENT="lockers-stress-test-$(uuidgen | tr 'A-Z' 'a-z')"
K8S_REPLICAS_COUNT=4
k8s_check_prerequisite || die "Prerequisite check failed, make sure kubernetes client running"
k8s_setup_test_env || die "Failed to setup the test environment"

echo "Deployment created: $K8S_DEPLOYMENT"

echo "Pods created: "
echo "$(k8s_get_pods)"

echo "After stress test, to delete deployment run: "
echo "kubectl --namespace=$K8S_NAMESPACE delete deployment $K8S_DEPLOYMENT"