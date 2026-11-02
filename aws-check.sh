# RDS
aws rds describe-db-clusters --query "DBClusters[?contains(DBClusterIdentifier,'litellm')].[DBClusterIdentifier,Status]"
aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier,'litellm')].[DBInstanceIdentifier,DBInstanceStatus]"
aws rds describe-db-subnet-groups --query "DBSubnetGroups[].[DBSubnetGroupName,VpcId]"

# Load balancing and ECS
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName,'litellm')].[LoadBalancerName,State.Code]"
aws elbv2 describe-target-groups --query "TargetGroups[].[TargetGroupName,TargetGroupArn]"
aws ecs list-clusters

# Network
aws ec2 describe-security-groups --filters Name=group-name,Values='*litellm*' --query "SecurityGroups[].[GroupId,GroupName,VpcId]"
aws ec2 describe-vpcs --query "Vpcs[].[VpcId,IsDefault,CidrBlock]"
aws ec2 describe-subnets --query "Subnets[].[SubnetId,VpcId,MapPublicIpOnLaunch,AvailabilityZone]"
aws ec2 describe-network-interfaces --query "NetworkInterfaces[].[NetworkInterfaceId,Status,Description,VpcId]"

# Other leftovers
aws logs describe-log-groups --log-group-name-prefix /ecs
aws secretsmanager list-secrets --include-planned-deletion --query "SecretList[?contains(Name,'litellm')].[Name,DeletedDate]"
aws s3 ls | grep -i -E "llm|litellm"
aws ecr describe-repositories --query "repositories[].repositoryName"
aws iam list-roles --query "Roles[?contains(RoleName,'litellm')].RoleName"
