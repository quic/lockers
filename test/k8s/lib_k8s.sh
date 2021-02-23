#!/usr/bin/env bash
#
# Copyright (c) 2021, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

wait_for() { # timeout [args]...
    local timeout=$1 ; shift
    local remaining_time
    for remaining_time in $(seq "$timeout" -2 1) ; do
        "$@" && return
        echo -n "."
        sleep 2s
    done
    return 1
}

k8s_check_prerequisite() {
    minikube version > /dev/null || return 1
    local status=$(minikube status -o=json)
    echo "$status" | jq ."Kubelet" | grep -q "Running" || return 1
    echo "$status" | jq ."Host" | grep -q "Running" || return 1
    return 0
}

k8s_use_minikube_docker_deamon() {
    eval $(minikube docker-env) \
        || die "Cannot point to minikube's docker env"
}

k8s_minikube_mount_lockers() {
    local seconds_mount_timeout=60
    minikube mount "$MYDIR"/../../../lockers:/lockers > /dev/null &
    local mount_pid=$!
    if wait_for "$seconds_mount_timeout" minikube ssh '[ -d /lockers ]' &> /dev/null ; then
        minikube ssh 'cp -r /lockers ~/'
    else
        die "Mount failed on minikube"
    fi
    kill -9 $mount_pid > /dev/null 2>&1
    trap "minikube ssh 'rm -rf ~/lockers'" EXIT
}

k8s_get_manifest() { # pod_name image
    local manifest=$(cat "$MYDIR"/lockers-k8s.yaml)
    manifest="${manifest//PROJECT_NAME/$1}"
    manifest="${manifest//IMAGE_NAME/$2}"
    echo "$manifest"
}

k8s_end_test() { # exit_code
    kubectl delete deployment "$DEPLOYMENT"
    exit $1
}

k8s_populate_pods() {
    local pods="$(kubectl get pods --sort-by=.status.startTime | awk '{print $1}' | grep "$DEPLOYMENT")"
    POD_A="$(echo "$pods" | sed -n 1p)"
    POD_B="$(echo "$pods" | sed -n 2p)"
}

k8s_exec() { # pod cmds...
    local pod=$1 ; shift
    kubectl exec "$pod" -- "$@"
}

k8s_stable_process() { # pod
    k8s_exec "$1" bash -c "sleep infinity & echo \$!"
}

k8s_setup_test_env() {
    local image_name="${DEPLOYMENT}:latest"

    k8s_use_minikube_docker_deamon
    k8s_minikube_mount_lockers
    local ret
    docker build --quiet -t "$DEPLOYMENT"  -< "$MYDIR"/Dockerfile ; ret=$?

    if [ $ret -eq 0 ] ; then
        k8s_get_manifest "$DEPLOYMENT" "$image_name" | kubectl apply -f  -
        kubectl apply -f "$MYDIR"/role.yaml
        echo "Waiting for deployment to be ready"
        kubectl rollout status deployment "$DEPLOYMENT" > /dev/null
    else
        k8s_end_test $ret
    fi

    k8s_populate_pods
}