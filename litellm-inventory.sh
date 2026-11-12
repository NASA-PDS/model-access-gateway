#!/usr/bin/env bash
# Read-only inventory of litellm-related AWS resources. Makes no changes.
# Usage: AWS_PROFILE=<profile> ./litellm-inventory.sh
OUT="${1:-litellm-inventory-output.txt}"
export AWS_REGION="${AWS_REGION:-us-west-2}" AWS_PAGER=""

run() {
  echo
  echo "################ $*"
  "$@" 2>&1
}

{
  echo "Run at: $(date -u +%FT%TZ)"
  run aws sts get-caller-identity --output json

  echo; echo "========== RDS =========="
  run aws rds describe-db-clusters --query "DBClusters[].[DBClusterIdentifier,Status,Engine,EngineVersion,DBSubnetGroup,DeletionProtection]" --output json
  run aws rds describe-db-instances --query "DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,DBClusterIdentifier,DBSubnetGroup.DBSubnetGroupName]" --output json
  run aws rds describe-db-subnet-groups --query "DBSubnetGroups[].[DBSubnetGroupName,VpcId,SubnetGroupStatus]" --output json

  echo; echo "========== Load balancing =========="
  run aws elbv2 describe-load-balancers --query "LoadBalancers[].[LoadBalancerName,LoadBalancerArn,State.Code,Scheme,VpcId,DNSName]" --output json
  run aws elbv2 describe-target-groups --query "TargetGroups[].[TargetGroupName,TargetGroupArn,VpcId,LoadBalancerArns]" --output json
  for tg in $(aws elbv2 describe-target-groups --query "TargetGroups[].TargetGroupArn" --output text 2>/dev/null); do
    run aws elbv2 describe-target-health --target-group-arn "$tg" --output json
  done

  echo; echo "========== ECS =========="
  run aws ecs list-clusters --output json
  for c in $(aws ecs list-clusters --query "clusterArns[]" --output text 2>/dev/null); do
    run aws ecs describe-clusters --clusters "$c" --query "clusters[].[clusterName,status,activeServicesCount,runningTasksCount]" --output json
    run aws ecs list-services --cluster "$c" --output json
    for s in $(aws ecs list-services --cluster "$c" --query "serviceArns[]" --output text 2>/dev/null); do
      run aws ecs describe-services --cluster "$c" --services "$s" --query "services[].[serviceName,status,desiredCount,runningCount,taskDefinition,events[:5].message]" --output json
    done
  done
  run aws ecs list-task-definitions --family-prefix pds --output json
  run aws ecs list-task-definition-families --status ACTIVE --output json

  echo; echo "========== EC2 / network =========="
  run aws ec2 describe-vpcs --query "Vpcs[].[VpcId,IsDefault,CidrBlock,State,Tags[?Key=='Name']|[0].Value]" --output json
  run aws ec2 describe-subnets --query "Subnets[].[SubnetId,VpcId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch,Tags[?Key=='Name']|[0].Value]" --output json
  run aws ec2 describe-route-tables --query "RouteTables[].[RouteTableId,VpcId,Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId]]" --output json
  run aws ec2 describe-nat-gateways --query "NatGateways[].[NatGatewayId,State,VpcId,SubnetId]" --output json
  run aws ec2 describe-internet-gateways --query "InternetGateways[].[InternetGatewayId,Attachments[].VpcId]" --output json
  run aws ec2 describe-vpc-endpoints --query "VpcEndpoints[].[VpcEndpointId,ServiceName,VpcId,State]" --output json
  run aws ec2 describe-security-groups --query "SecurityGroups[?GroupName!='default'].[GroupId,GroupName,VpcId,Description]" --output json
  run aws ec2 describe-network-interfaces --query "NetworkInterfaces[].[NetworkInterfaceId,Status,Description,VpcId,SubnetId,Groups[].GroupId,Attachment.AttachmentId]" --output json

  echo; echo "========== Logs / secrets / storage / images / IAM =========="
  run aws logs describe-log-groups --log-group-name-prefix /ecs --query "logGroups[].logGroupName" --output json
  run aws logs describe-log-groups --query "logGroups[?contains(logGroupName,'litellm')].logGroupName" --output json
  run aws secretsmanager list-secrets --include-planned-deletion --query "SecretList[].[Name,ARN,DeletedDate]" --output json
  run aws s3api list-buckets --query "Buckets[].Name" --output json
  run aws ecr describe-repositories --query "repositories[].[repositoryName,repositoryUri]" --output json
  run aws iam list-roles --query "Roles[?contains(RoleName,'litellm')].[RoleName,Arn,PermissionsBoundary.PermissionsBoundaryArn]" --output json
  run aws iam list-policies --scope Local --query "Policies[].[PolicyName,Arn]" --output json

  echo; echo "========== CloudFormation / tagged resources =========="
  run aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE DELETE_FAILED ROLLBACK_COMPLETE CREATE_FAILED UPDATE_ROLLBACK_COMPLETE --query "StackSummaries[].[StackName,StackStatus]" --output json
  run aws resourcegroupstaggingapi get-resources --tag-filters Key=component,Values=llm-for-developers --query "ResourceTagMappingList[].ResourceARN" --output json

  echo; echo "Done."
} 2>&1 | tee "$OUT"

echo
echo "Wrote $OUT"
