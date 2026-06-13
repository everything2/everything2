#!/usr/bin/env bash
#
# run-fargate-job.sh <local-script> [KEY=VAL ...] -- run a one-off maintenance script
# inside the VPC as a Fargate task using the deployed e2app image (#4282).
#
# It uploads the script to the single locked "jobs" bucket, then `aws ecs run-task`s
# the e2app task def with a command override that runs cron/run_s3_job.pl against that
# key. The task inherits the same subnets/SGs as the running service (so it can reach
# RDS) and the ECS task role. Extra KEY=VAL args become container env vars (e.g. for a
# job that needs E2_TSFIX_HOST).
#
# Output streams to the e2app CloudWatch log group. Requires: awscli, jq.
#
set -euo pipefail

SCRIPT="${1:?usage: run-fargate-job.sh <local-script> [KEY=VAL ...]}"; shift || true
REGION="${E2_REGION:-us-west-2}"
CLUSTER="${E2_CLUSTER:-E2-App-ECS-Cluster}"
SERVICE="${E2_SERVICE:-E2-App-Fargate-Service}"
TASKDEF="${E2_TASKDEF:-e2app-family}"
BUCKET="${E2_JOBS_BUCKET:-e2-maintenance-jobs}"

[ -f "$SCRIPT" ] || { echo "no such script: $SCRIPT" >&2; exit 1; }

# Extra KEY=VAL -> container env overrides (always includes E2_JOB_S3_KEY below).
ENV_JSON='[]'
for kv in "$@"; do
  k="${kv%%=*}"; v="${kv#*=}"
  ENV_JSON=$(echo "$ENV_JSON" | jq --arg k "$k" --arg v "$v" '. + [{name:$k,value:$v}]')
done

KEY="jobs/$(date +%Y%m%d-%H%M%S)-$(basename "$SCRIPT")"
echo ">> upload $SCRIPT -> s3://$BUCKET/$KEY"
aws s3 cp "$SCRIPT" "s3://$BUCKET/$KEY" --region "$REGION" >/dev/null

# Land the one-off task in the same network as the service (so it reaches RDS), and
# discover the container name from the task def.
NET=$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION" \
  --query 'services[0].networkConfiguration.awsvpcConfiguration' --output json)
SUBNETS=$(echo "$NET" | jq -r '.subnets | join(",")')
SGS=$(echo "$NET" | jq -r '.securityGroups | join(",")')
PUBIP=$(echo "$NET" | jq -r '.assignPublicIp // "DISABLED"')   # must match the service (ECR/S3 egress)
CONTAINER=$(aws ecs describe-task-definition --task-definition "$TASKDEF" --region "$REGION" \
  --query 'taskDefinition.containerDefinitions[0].name' --output text)

ENV_JSON=$(echo "$ENV_JSON" | jq --arg k E2_JOB_S3_KEY --arg v "$KEY" '. + [{name:$k,value:$v}]')
OVERRIDES=$(jq -nc --arg c "$CONTAINER" --argjson env "$ENV_JSON" \
  '{containerOverrides:[{name:$c, command:["perl","/var/everything/cron/run_s3_job.pl"], environment:$env}]}')

echo ">> run-task ($CONTAINER; subnets=$SUBNETS sgs=$SGS pubip=$PUBIP)"
TASK=$(aws ecs run-task --cluster "$CLUSTER" --task-definition "$TASKDEF" \
  --launch-type FARGATE --region "$REGION" --started-by "run-fargate-job:$(basename "$SCRIPT")" \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SGS],assignPublicIp=$PUBIP}" \
  --overrides "$OVERRIDES" --query 'tasks[0].taskArn' --output text)
echo ">> task: $TASK"

TASKID=$(basename "$TASK")
echo ">> polling until stopped (log stream: e2-fargate/$CONTAINER/$TASKID)"
# `aws ecs wait tasks-stopped` caps at ~10min; a 2M-row repair runs longer. Poll instead.
MAXWAIT="${E2_JOB_TIMEOUT:-5400}"   # seconds; default 90min
ELAPSED=0
while :; do
  ST=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" --region "$REGION" \
    --query 'tasks[0].lastStatus' --output text 2>&1)
  [ "$ST" = "STOPPED" ] && break
  if [ "$ELAPSED" -ge "$MAXWAIT" ]; then
    echo ">> still $ST after ${MAXWAIT}s -- not blocking further; poll the log stream above."
    exit 0
  fi
  printf ">> [%4ds] %s\n" "$ELAPSED" "$ST"
  sleep 30; ELAPSED=$((ELAPSED+30))
done
aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" --region "$REGION" \
  --query 'tasks[0].containers[0].{exitCode:exitCode,reason:reason}' --output table
echo ">> logs: e2app log group, stream e2-fargate/$CONTAINER/$TASKID"
