#!/bin/bash
# Nom du cluster
CLUSTER_NAME="dynatrace-workshop"
# 1. Supprimer les ressources Kubernetes
echo "Mise à jour de la configuration de kubectl pour le cluster $CLUSTER_NAME"
aws eks update-kubeconfig --name $CLUSTER_NAME
echo "Suppression de toutes les ressources Kubernetes dans le cluster $CLUSTER_NAME"
kubectl delete all --all
# 2. Lister et supprimer les groupes de nœuds gérés
echo "Liste des groupes de nœuds pour le cluster $CLUSTER_NAME"
NODEGROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --query 'nodegroups' --output text)
if [ -n "$NODEGROUPS" ]; then
  for NODEGROUP in $NODEGROUPS; do
    echo "Suppression du groupe de nœuds $NODEGROUP"
    aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODEGROUP
  done
fi
# 3. Supprimer le cluster EKS
echo "Suppression du cluster EKS $CLUSTER_NAME"
aws eks delete-cluster --name $CLUSTER_NAME
# 4. Supprimer les instances EC2 associées
echo "Recherche des instances EC2 associées au cluster $CLUSTER_NAME"
INSTANCE_IDS=$(aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" --query "Reservations[].Instances[].InstanceId" --output text)
if [ -n "$INSTANCE_IDS" ]; then
  echo "Suppression des instances EC2 : $INSTANCE_IDS"
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
fi
# 5. Supprimer les Elastic Network Interfaces si elles existent
echo "Suppression des interfaces réseau associés"
ENI_IDS=$(aws ec2 describe-network-interfaces --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" --query "NetworkInterfaces[].NetworkInterfaceId" --output text)
if [ -n "$ENI_IDS" ]; then
  for ENI_ID in $ENI_IDS; do
    echo "Suppression de l'interface réseau $ENI_ID"
    aws ec2 delete-network-interface --network-interface-id $ENI_ID
  done
fi
# 6. (Optionnel) Supprimer les ECR Repositories
REPO_NAMES=$(aws ecr describe-repositories --query "repositories[].repositoryName" --output text)
for REPO_NAME in $REPO_NAMES; do
  if [[ $REPO_NAME == *"$CLUSTER_NAME"* ]]; then
    echo "Suppression du dépôt ECR $REPO_NAME"
    aws ecr delete-repository --repository-name $REPO_NAME --force
  fi
done
echo "Suppression du cluster et des ressources associées terminée"