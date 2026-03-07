#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# deploy.sh – Update an ECS service to a new Docker image tag
#
# Usage:
#   ./deploy.sh <region> <cluster> <service> <container> <image>
#
# Called automatically by Jenkinsfile in the Deploy stage.
# ─────────────────────────────────────────────────────────────

set -euo pipefail

# ── Arguments ────────────────────────────────────────────────
AWS_REGION="${1:?'AWS region required'}"
ECS_CLUSTER="${2:?'ECS cluster name required'}"
ECS_SERVICE="${3:?'ECS service name required'}"
CONTAINER_NAME="${4:?'Container name required'}"
NEW_IMAGE="${5:?'New Docker image URI required'}"

echo ""
echo "══════════════════════════════════════════════"
echo "  🚀 ECS Blue/Green-style Rolling Deployment"
echo "  Cluster  : $ECS_CLUSTER"
echo "  Service  : $ECS_SERVICE"
echo "  Container: $CONTAINER_NAME"
echo "  Image    : $NEW_IMAGE"
echo "══════════════════════════════════════════════"
echo ""

# ── Step 1: Fetch the current task definition ─────────────────
echo "📄 Fetching current task definition..."
TASK_DEFINITION=$(aws ecs describe-services \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --query 'services[0].taskDefinition' \
  --output text)

echo "   Current: $TASK_DEFINITION"

# ── Step 2: Get full task definition JSON ─────────────────────
TASK_DEF_JSON=$(aws ecs describe-task-definition \
  --region "$AWS_REGION" \
  --task-definition "$TASK_DEFINITION" \
  --query 'taskDefinition')

# ── Step 3: Swap the image for our container ──────────────────
echo "🔄 Updating image to: $NEW_IMAGE"
NEW_TASK_DEF=$(echo "$TASK_DEF_JSON" | jq \
  --arg CONTAINER "$CONTAINER_NAME" \
  --arg IMAGE "$NEW_IMAGE" \
  '.containerDefinitions |= map(if .name == $CONTAINER then .image = $IMAGE else . end)
   | {
       family:                  .family,
       containerDefinitions:    .containerDefinitions,
       volumes:                 .volumes,
       networkMode:             .networkMode,
       requiresCompatibilities: .requiresCompatibilities,
       cpu:                     .cpu,
       memory:                  .memory,
       executionRoleArn:        .executionRoleArn,
       taskRoleArn:             .taskRoleArn
     }')

# ── Step 4: Register the new task definition revision ─────────
echo "📝 Registering new task definition revision..."
NEW_TASK_ARN=$(aws ecs register-task-definition \
  --region "$AWS_REGION" \
  --cli-input-json "$NEW_TASK_DEF" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "   New ARN: $NEW_TASK_ARN"

# ── Step 5: Update the ECS service ────────────────────────────
echo "⚙️  Updating ECS service..."
aws ecs update-service \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --task-definition "$NEW_TASK_ARN" \
  --query 'service.serviceName' \
  --output text

# ── Step 6: Wait for deployment to stabilise ──────────────────
echo "⏳ Waiting for service to reach steady state (up to 10 min)..."
aws ecs wait services-stable \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE"

echo ""
echo "✅ Deployment successful!"
echo "   Running task definition: $NEW_TASK_ARN"
