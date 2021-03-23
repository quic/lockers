#!/usr/bin/env bash
#
# Copyright (c) 2021, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

minikube_die() { echo "$1" >&2 ; kill $$ ; exit 1 ; } # error_message

minikube_check_prerequisite() {
    minikube version > /dev/null || minikube_die "Minikube is not Installed"
    local status=$(minikube status -o=json)
    echo "$status" | jq -e '."Kubelet" == "Running"' || \
        minikube_die "Minikube: kubelet is not running"
    echo "$status" | jq -e '."Host" == "Running"' || \
        minikube_die "Minikube: host is not running"
}

minikube_docker_deamon() {
    eval $(minikube docker-env)
}