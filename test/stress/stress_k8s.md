## Stress testing k8s lock


- Run the [lock_k8s_setup.sh](lock_k8s_setup.sh) to bring up the environment, Refer to
[this readme](../k8s/README.md) on what parameters to pass to it.
- The above script would generate a deployment with 4 pods, to stress test run the following
commands on each pod:

```
Pod 1: $  time ~/lockers/test/stress.new/lock_k8s.sh --dir /lockers/test/file/ --sleep .1 count 2000 --restart
Pod 2: $  time ~/lockers/test/stress.new/lock_k8s.sh --dir /lockers/test/file/ --sleep .1 count 2000
Pod 3: $  while true ; do ~/lockers/test/stress.new/lock_k8s.sh lock_go_stale ; done
Host Machine: $ ./test/stress.new/lock_go_stale_delete_pod.sh -d <deployment name obtained from setup script> --dir /lockers/test/file
```

Note: Make sure all the commands point to same --dir option, which is the lock file we
will be using for testing and is present on shared volume accessible by all the pods.

If you wish to decrease the node heartbeat frequency on a minikube environment,
run the following:

```
minikube start --extra-config kubelet.node-status-update-frequency=1s --kubernetes-version=v1.14.0 --feature-gates=NodeLease=false
```