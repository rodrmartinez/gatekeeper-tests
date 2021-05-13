# OPA Gatekeeper Tests

Gatekeeper tests based on https://github.com/open-policy-agent/gatekeeper-library

## Requirements

* [kind](https://kind.sigs.k8s.io/) or [mininikube](https://minikube.sigs.k8s.io/) cluster
* [bats](https://github.com/sstephenson/bats#installing-bats-from-source) installed in localhost

### Install Gatekeeper

`make deploy`

### Test Deployment and library constraint templates 

`make test-intergration`

### Usage

Apply the `template.yaml` and `constraint.yaml` provided in each directory under `library/`

#### Example:

```bash
cd library/pod-security-policy/privileged-containers/
# Define constraint template
kubectl apply -f template.yaml
# Deploy constraint
kubectl apply -f samples/psp-privileged-container/constraint.yaml
```
 Create a Pod without privileges
```bash
kubectl apply -f samples/psp-privileged-container/example_allowed.yaml 
```
The pod should be created
```bash
pod/nginx-privileged-allowed created
```
Create a Pod with **privilege:true** label

```bash
kubectl apply -f samples/psp-privileged-container/example_disallowed.yaml 
```
The request to create the pod should be denied:

```bash
Error from server ([denied by psp-privileged-container] Privileged container is not allowed: nginx, securityContext: {"privileged": true}): error when creating "samples/psp-privileged-container/example_disallowed.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [denied by psp-privileged-container] Privileged container is not allowed: nginx, securityContext: {"privileged": true}
```
