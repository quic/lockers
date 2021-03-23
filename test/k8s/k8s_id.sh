#!/usr/bin/env bash
#
# Copyright (c) 2021, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

readlink --canonicalize / &> /dev/null || readlink() { greadlink "$@" ; } # for MacOS
MYPROG=$(readlink -f -- "$0")
MYDIR=$(dirname -- "$MYPROG")
MYNAME=$(basename -- "$MYPROG")
source "$MYDIR"/../../lib/test/results.sh
source "$MYDIR"/lib_k8s.sh

out() { OUT=$("$@") ; }
outerr() { OUT=$("$@" 2>&1) ; }
die() { echo -e "$@" ; exit 1 ; } # error_message

print_dots() {
    while true ; do
        echo -n "."
        sleep 5
    done
}

run_test_with_dots() { # cmds...
    echo "WARNING: This test could take upto 5 mins to complete"
    "$@" &
    pid=$!
    while kill -0 $pid 2>"/dev/null" ; do
        echo -n "."
        sleep 5
    done
    echo
    wait $pid
}

usage() { # error_message
    local k8s_msg=$(k8s_usage)
    cat <<-EOF
    Usage:
        $k8s_msg

    Refer to $MYDIR/README.md for more information.

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
K8S_YAMLS_DIR=$MYDIR
K8S_DOCKER_CONTEXT="$MYDIR"/../../
K8S_DEPLOYMENT="lockers-k8s-id-test-$$"
ID_CHECKER="/home/locker_user/lockers/$MYNAME"
k8s_check_prerequisite || die "Prerequisite check failed, make sure kubernetes client running"
k8s_setup_test_env || die "Failed to setup the test environment"

STABLE_A=$(k8s_stable_process "$POD_A")
STABLE_B=$(k8s_stable_process "$POD_B")

echo "Running Tests...."

uid=$(k8s_exec "$POD_B" "$ID_CHECKER" uid "$STABLE_B")
result "uid of pod B($STABLE_B)" "$uid"

pid_out=$(echo "$uid" | grep "$STABLE_B")
result "original pid in uid($uid)" "$pid_out"

out k8s_exec "$POD_A" "$ID_CHECKER" is_valid_uid "$uid"
result "is_valid_uid($uid) by pod A" "$OUT"

out k8s_exec "$POD_B" "$ID_CHECKER" is_valid_uid "$uid"
result "is_valid_uid($uid) by pod B" "$OUT"

pid=$(k8s_exec "$POD_A" "$ID_CHECKER" _pid "$uid")
result_out "pid check by other pod" "$STABLE_B" "$pid"

pod_name=$(k8s_exec "$POD_A" "$ID_CHECKER" _pod_name "$uid")
result_out "pod_name check by other pod" "$pod_name" "$POD_B"

! outerr k8s_exec "$POD_A" "$ID_CHECKER" is_pod_not_registered "$uid"
result "is_pod_not_registered check by other pod" "$OUT"

! outerr k8s_exec "$POD_A" "$ID_CHECKER" is_process_stale "$uid"
result "is_process_stale($uid) check by pod A" "$OUT"

! outerr k8s_exec "$POD_A" "$ID_CHECKER" is_stale "$uid"
result "is_stale($uid) check by pod A" "$OUT"

k8s_exec "$POD_B" kill -9 "$STABLE_B"
out k8s_exec "$POD_A" "$ID_CHECKER" is_process_stale "$uid"
result "is_process_stale($uid) by pod A" "$OUT"

# Reaped process test
reaped_uid=$(k8s_exec "$POD_B" "/bin/bash" "-c" '"$0" uid $$' "$ID_CHECKER")
out k8s_exec "$POD_A" "$ID_CHECKER" is_process_stale "$reaped_uid"
result "is_process_stale($reaped_uid) by pod A for reaped process of pod B" "$OUT"

kubectl delete pod "$POD_B"

out k8s_exec "$POD_A" "$ID_CHECKER" is_pod_not_registered "$uid"
result "is_pod_not_registered check by other pod" "$OUT"

! outerr k8s_exec "$POD_A" "$ID_CHECKER" is_process_stale "$uid"
result "is_process_stale($uid) by pod A" "$OUT"

run_test_with_dots out k8s_exec "$POD_A" "$ID_CHECKER" is_stale "$uid"
result "is_stale($uid) check by pod A" "$OUT"

k8s_populate_pods # deployment will generate a new POD meantime
STABLE_B=$(k8s_stable_process "$POD_B")

node=$(k8s_exec "$POD_A" "$ID_CHECKER" _node "$uid")
out k8s_exec "$POD_B" "$ID_CHECKER" is_node_ready "$node"
result "is_node_ready($node) by pod B" "$OUT"

run_test_with_dots out k8s_exec "$POD_B" "$ID_CHECKER" is_node_receiving_heartbeats "$node"
result "is_node_receiving_heartbeats($node) by pod B" "$OUT"

out k8s_exec "$POD_B" "$ID_CHECKER" is_pod_not_registered "$uid"
result "is_pod_not_registered by new pod B" "$OUT"

run_test_with_dots out k8s_exec "$POD_B" "$ID_CHECKER" is_stale "$uid"
result "is_stale($uid) check by new pod B" "$OUT"

heartbeat_from_A=$(k8s_exec "$POD_A" "$ID_CHECKER" node_heartbeat_epoch "$node")
heartbeat_from_B=$(k8s_exec "$POD_A" "$ID_CHECKER" node_heartbeat_epoch "$node")
result_out "Heartbeat check for node($node) from both pods" "$heartbeat_from_A" "$heartbeat_from_B"

! outerr k8s_exec "$POD_B" "$ID_CHECKER" is_heartbeat_ge_epoch "$node" "$(($heartbeat_from_A + 1))"
result "is_process_stale($uid) by new pod B" "$OUT"

out k8s_exec "$POD_B" "$ID_CHECKER" is_heartbeat_ge_epoch "$node" "$(($heartbeat_from_A - 1))"
result "is_process_stale($uid) by new pod B" "$OUT"

k8s_end_test $RESULT