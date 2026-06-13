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
CONTAINER=$(aws ecs describe-task-definition --task-definition "$TASKDEF" --region "$REGION" \
  --query 'taskDefinition.containerDefinitions[0].name' --output text)

ENV_JSON=$(echo "$ENV_JSON" | jq --arg k E2_JOB_S3_KEY --arg v "$KEY" '. + [{name:$k,value:$v}]')
OVERRIDES=$(jq -nc --arg c "$CONTAINER" --argjson env "$ENV_JSON" \
  '{containerOverrides:[{name:$c, command:["perl","/var/everything/cron/run_s3_job.pl"], environment:$env}]}')

echo ">> run-task ($CONTAINER; subnets=$SUBNETS sgs=$SGS)"
TASK=$(aws ecs run-task --cluster "$CLUSTER" --task-definition "$TASKDEF" \
  --launch-type FARGATE --region "$REGION" --started-by "run-fargate-job:$(basename "$SCRIPT")" \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SGS],assignPublicIp=DISABLED}" \
  --overrides "$OVERRIDES" --query 'tasks[0].taskArn' --output text)
echo ">> task: $TASK"

echo ">> waiting for stop..."
aws ecs wait tasks-stopped --cluster "$CLUSTER" --tasks "$TASK" --region "$REGION"
aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" --region "$REGION" \
  --query 'tasks[0].containers[0].{exitCode:exitCode,reason:reason}' --output table
echo ">> logs: e2app log group, stream for task $(basename "$TASK")"
