### Kubernetes Setup

The steps below explain how to run the k8s tests on any Kubernetes environment.

1. Specify the docker registry from where your kubernetes setup pulls the images using the
`--docker-registry` option. Make sure you have necessary rights to upload images to it.

2. Minimal roles needed for the k8s lockers are `create` on `pods/exec` and `get` on
`nodes` and `pods`. We can tie them to a service account and create pods using that
specific account. Refer to [role.yaml][1] for the configuration which ties the needed roles
to the default account. If you already have an account with the needed roles you can pass it
to the script using the `--service-account` option. If your account is in a different
namespace also use `--namespace` to specify it.

3. k8s lockers also require a shared volume where they can actually create lock files. Refer
to [pvc.yaml][2] for general PersistentVolumeClaim configuration. If you already have a PVC
use it by specifying option `--pvc-name`.

4. Use the options `--create-role` and `--create-pvc` to create missing resources and modify
their yaml files according to your needs.

5. To start the tests in an environment where the required resources already exist, use:

```
./lock_k8s.sh --docker-registry docker-registry.example.com --pvc-name example-volume --service-account example-account --namespace example-namespace
```

6. To start tests in an environment where you want the tests to create non-existent resources,
use:

```
./lock_k8s.sh --docker-registry docker-registry.example.com/image --pvc-name example-volume --service-account example-account --namespace example-namespace --create-pvc --create-svc
```

> NOTE: Make sure you modify `pvc.yaml` and `svc.yaml` according to your kubernetes cluster
and that those files' content match the name specified with `--pvc-name` and `--service-account`
options.


### Running on minikube

To run the tests on minikube in default namespace and default account, use `--minikube` flag as
shown:

```
./lock_k8s.sh --minikube --create-pvc --create-svc
```

There is no need to modify any yaml files while running in minikube unless you wish to change
the namespace or the account configurations.

[1]: ./pvc.yaml
[2]: ./role.yaml
