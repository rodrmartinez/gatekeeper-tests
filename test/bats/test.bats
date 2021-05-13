#!/usr/bin/env bats

load helpers

TESTS_DIR=library
BATS_TESTS_DIR=test/bats
WAIT_TIME=300
SLEEP_TIME=5
CLEAN_CMD="echo cleaning..."

teardown() {
  bash -c "${CLEAN_CMD}"
  kubectl delete constrainttemplate --all
}

setup() {
  kubectl config set-context --current --namespace default
}

@test "gatekeeper-controller-manager is running" {
  wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "kubectl -n gatekeeper-system wait --for=condition=Ready --timeout=60s pod -l control-plane=controller-manager"
}

@test "gatekeeper-audit is running" {
  wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "kubectl -n gatekeeper-system wait --for=condition=Ready --timeout=60s pod -l control-plane=audit-controller"
}

@test "namespace label webhook is serving" {
  cert=$(mktemp)
  CLEAN_CMD="${CLEAN_CMD}; rm ${cert}"
  wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "get_ca_cert ${cert}"

  kubectl run temp  --image=tutum/curl -- tail -f /dev/null
  kubectl wait --for=condition=Ready --timeout=60s pod temp
  kubectl cp ${cert} temp:/cacert

  wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "kubectl exec -it temp -- curl -f --cacert /cacert --connect-timeout 1 --max-time 2  https://gatekeeper-webhook-service.gatekeeper-system.svc:443/v1/admitlabel"
  kubectl delete pod temp
}

@test "constrainttemplates crd is established" {
  wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "kubectl wait --for condition=established --timeout=60s crd/constrainttemplates.templates.gatekeeper.sh"
}

@test "waiting for validating webhook" {
  wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "kubectl get validatingwebhookconfigurations.admissionregistration.k8s.io gatekeeper-validating-webhook-configuration"
}

@test "testing constraint templates" {
  for policy in "$TESTS_DIR"/*/*; do
    if [ -d "$policy" ]; then
      local policy_group=$(basename "$(dirname "$policy")")
      local template_name=$(basename "$policy")
      echo "running integration test against policy group: $policy_group, constraint template: $template_name"
      # apply template
      wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "kubectl apply -f $policy"
      for sample in "$policy"/samples/*; do
        echo "testing sample constraint: $(basename "$sample")"
        # apply constraint
        wait_for_process ${WAIT_TIME} ${SLEEP_TIME} "kubectl apply -f ${sample}/constraint.yaml"

        for allowed in "$sample"/example_allowed*.yaml; do
          if [[ -e "$allowed" ]]; then
            # apply resource
            run kubectl apply -f "$allowed"
            assert_match 'created' "$output"
            assert_success
            # delete resource
            kubectl delete --ignore-not-found -f "$allowed"
          fi
        done

        for disallowed in "$sample"/example_disallowed*.yaml; do
          if [[ -e "$disallowed" ]]; then
            # apply resource
            run kubectl apply -f "$disallowed"
            assert_match 'denied the request' "${output}"
            assert_failure
            # delete resource
            kubectl delete --ignore-not-found -f "$disallowed"
          fi
        done
        # delete constraint
        kubectl delete -f "$sample"/constraint.yaml
      done
      # delete template
      kubectl delete -f "$policy"
    fi
  done
}

