#!/bin/bash
# =====================================================================================================================
# 3-TIER ARCHITECTURE AUTOMATED SMOKE TEST & VERIFICATION HARNESS
# =====================================================================================================================
set -e

ENV=${1:-dev}
echo "=========================================================="
echo "Starting Smoke Test Suite for Environment: [${ENV}]"
echo "=========================================================="

cd "$(dirname "$0")/../environments/${ENV}"

echo ">> 1. Reading Terraform Outputs..."
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || true)
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || true)
ASG_NAME=$(terraform output -raw asg_name 2>/dev/null || true)
DB_ENDPOINT=$(terraform output -raw db_instance_endpoint 2>/dev/null || true)

if [ -z "$ALB_DNS" ]; then
  echo "Error: Infrastructure not deployed or outputs unavailable. Run 'terraform apply' first."
  exit 1
fi

echo "  VPC ID:        ${VPC_ID}"
echo "  ALB DNS:       ${ALB_DNS}"
echo "  ASG Name:      ${ASG_NAME}"
echo "  RDS Endpoint:  ${DB_ENDPOINT}"
echo ""

# ---------------------------------------------------------------------------------------------------------------------
# TEST 1: ALB HTTP CONNECTIVITY & HEALTH
# ---------------------------------------------------------------------------------------------------------------------
echo ">> 2. Testing Public ALB Endpoint Connectivity..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${ALB_DNS}/" || true)
if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "  [PASS] ALB returned HTTP 200 OK"
  RESPONSE=$(curl -s "http://${ALB_DNS}/")
  echo "  Response Payload: ${RESPONSE}"
else
  echo "  [FAIL] ALB returned HTTP ${HTTP_STATUS} (Expected 200)"
fi
echo ""

# ---------------------------------------------------------------------------------------------------------------------
# TEST 2: AUTO SCALING GROUP CAPACITY & HEALTH
# ---------------------------------------------------------------------------------------------------------------------
echo ">> 3. Inspecting Auto Scaling Group Health..."
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "${ASG_NAME}" \
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,AvailabilityZone,HealthStatus,LifecycleState]" \
  --output table
echo ""

# ---------------------------------------------------------------------------------------------------------------------
# TEST 3: VERIFY INSTANCES HAVE NO PUBLIC IPS
# ---------------------------------------------------------------------------------------------------------------------
echo ">> 4. Verifying Zero Public IPs on EC2 Compute Instances..."
PUBLIC_IPS=$(aws ec2 describe-instances \
  --filters "Name=tag:aws:autoscaling:groupName,Values=${ASG_NAME}" \
  --query "Reservations[*].Instances[*].PublicIpAddress" --output text)

if [ -z "$PUBLIC_IPS" ] || [ "$PUBLIC_IPS" == "None" ]; then
  echo "  [PASS] Strictly zero public IP addresses detected on application instances."
else
  echo "  [FAIL] Security Alert: Instances have public IP addresses: ${PUBLIC_IPS}"
fi
echo ""

# ---------------------------------------------------------------------------------------------------------------------
# TEST 4: CLOUDWATCH ALARM HEALTH
# ---------------------------------------------------------------------------------------------------------------------
echo ">> 5. Checking CloudWatch Alarms Status..."
aws cloudwatch describe-alarms \
  --alarm-name-prefix "three-tier-${ENV}-" \
  --query "MetricAlarms[*].[AlarmName,StateValue]" \
  --output table

echo "=========================================================="
echo "Verification Suite Finished."
echo "=========================================================="
