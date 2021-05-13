.ONESHELL: 

KIND_VERSION ?= 0.8.1
# note: k8s version pinned since KIND image availability lags k8s releases
GATEKEEPER_VERSION ?= release-3.3

deploy:
	kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml

uninstall:
	kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml


test-integration:
	bats -t test/bats/test.bats
