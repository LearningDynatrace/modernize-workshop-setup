#!/bin/bash

delete_vpc() {
  local TAG_NAME=$1
  echo "Deleting VPC with tag Name=${TAG_NAME}"

  # Get the VPC ID
  VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${TAG_NAME}" --query "Vpcs[*].VpcId" --output text)

  # Check if the VPC exists
  if [ -z "$VPC_ID" ]; then
    echo "No VPC found with the Name tag '${TAG_NAME}'."
    return
  fi

  echo "Found VPC ID: $VPC_ID"

  # Terminate all instances in the VPC
  INSTANCE_IDS=$(aws ec2 describe-instances --filters "Name=vpc-id,Values=${VPC_ID}" --query "Reservations[*].Instances[*].InstanceId" --output text)
  if [ -n "$INSTANCE_IDS" ]; then
    echo "Terminating instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS
    echo "Instances terminated."
  fi

  # Get and delete NAT Gateways
  NAT_GATEWAY_IDS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=${VPC_ID}" --query "NatGateways[*].NatGatewayId" --output text)
  for NAT_GATEWAY_ID in $NAT_GATEWAY_IDS; do
    ALLOCATION_ID=$(aws ec2 describe-nat-gateways --nat-gateway-ids $NAT_GATEWAY_ID --query "NatGateways[*].NatGatewayAddresses[0].AllocationId" --output text)
    if [ -n "$ALLOCATION_ID" ]; then
      echo "Releasing Elastic IP: $ALLOCATION_ID associated with NAT Gateway: $NAT_GATEWAY_ID"
      aws ec2 release-address --allocation-id $ALLOCATION_ID
    fi
    echo "Deleting NAT Gateway: $NAT_GATEWAY_ID"
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GATEWAY_ID
  done

  # Wait for NAT Gateways to be deleted
  for NAT_GATEWAY_ID in $NAT_GATEWAY_IDS; do
    aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_GATEWAY_ID
    echo "NAT Gateway $NAT_GATEWAY_ID has been deleted."
  done

  # Delete Elastic Network Interfaces (ENIs) associated with the VPC
  ENI_IDS=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=${VPC_ID}" --query "NetworkInterfaces[*].NetworkInterfaceId" --output text)
  for ENI_ID in $ENI_IDS; do
    echo "Deleting Elastic Network Interface: $ENI_ID"
    aws ec2 delete-network-interface --network-interface-id $ENI_ID
  done

  # Dissociate all route table associations
  ROUTE_TABLE_ASSOCIATIONS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" --query "RouteTables[*].Associations[?Main!=true].RouteTableAssociationId" --output text)
  for ASSOCIATION_ID in $ROUTE_TABLE_ASSOCIATIONS; do
    echo "Dissociating route table association: $ASSOCIATION_ID"
    aws ec2 disassociate-route-table --association-id $ASSOCIATION_ID
  done

  # Delete all routes (except the local route) from route tables
  VPC_CIDR_BLOCK=$(aws ec2 describe-vpcs --vpc-ids ${VPC_ID} --query "Vpcs[0].CidrBlock" --output text)
  ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" --query "RouteTables[*].RouteTableId" --output text)
  for ROUTE_TABLE_ID in $ROUTE_TABLE_IDS; do
    ROUTE_IDS=$(aws ec2 describe-route-tables --route-table-ids $ROUTE_TABLE_ID --query "RouteTables[*].Routes[?DestinationCidrBlock!='${VPC_CIDR_BLOCK}'].DestinationCidrBlock" --output text)
    for ROUTE_ID in $ROUTE_IDS; do
      echo "Deleting route: $ROUTE_ID from route table: $ROUTE_TABLE_ID"
      aws ec2 delete-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block $ROUTE_ID
    done
    echo "Deleting route table: $ROUTE_TABLE_ID"
    aws ec2 delete-route-table --route-table-id $ROUTE_TABLE_ID
  done

  # Delete Load Balancers (ELBs and ALBs) associated with the VPC
  LOAD_BALANCER_ARNs=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='${VPC_ID}'].LoadBalancerArn" --output text)
  for LB_ARN in $LOAD_BALANCER_ARNs; do
    echo "Deleting Load Balancer: $LB_ARN"
    aws elbv2 delete-load-balancer --load-balancer-arn $LB_ARN
  done

  ELB_NAMES=$(aws elb describe-load-balancers --query "LoadBalancerDescriptions[?VPCId=='${VPC_ID}'].LoadBalancerName" --output text)
  for ELB_NAME in $ELB_NAMES; do
    echo "Deleting ELB: $ELB_NAME"
    aws elb delete-load-balancer --load-balancer-name $ELB_NAME
  done

  # Delete all subnets in the VPC
  SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --query "Subnets[*].SubnetId" --output text)
  for SUBNET_ID in $SUBNET_IDS; do
    echo "Deleting subnet: $SUBNET_ID"
    aws ec2 delete-subnet --subnet-id $SUBNET_ID
  done

  # Get and delete the internet gateway
  IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=${VPC_ID}" --query "InternetGateways[*].InternetGatewayId" --output text)
  if [ -n "$IGW_ID" ]; then
    echo "Detaching and deleting internet gateway: $IGW_ID"
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
  fi

  # Get and delete all network ACLs in the VPC (excluding the default network ACL)
  NETWORK_ACL_IDS=$(aws ec2 describe-network-acls --filters "Name=vpc-id,Values=${VPC_ID}" --query "NetworkAcls[?IsDefault==\`false\`].NetworkAclId" --output text)
  for NETWORK_ACL_ID in $NETWORK_ACL_IDS; do
    echo "Deleting network ACL: $NETWORK_ACL_ID"
    aws ec2 delete-network-acl --network-acl-id $NETWORK_ACL_ID
  done

  # Get and delete all security groups in the VPC (excluding the default security group)
  SECURITY_GROUP_IDS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=${VPC_ID}" --query "SecurityGroups[?GroupName!=\`default\`].GroupId" --output text)
  for SECURITY_GROUP_ID in $SECURITY_GROUP_IDS; do
    echo "Deleting security group: $SECURITY_GROUP_ID"
    aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID
  done

  # Delete the VPC
  echo "Deleting VPC: $VPC_ID"
  aws ec2 delete-vpc --vpc-id $VPC_ID
  echo "VPC $VPC_ID deletion initiated."
}

# Example usage
delete_vpc "roue-dynatrace-modernize-workshop"

