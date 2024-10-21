#!/bin/bash

terminate_instances() {
  local TAG_NAME=$1
  echo "Terminating instances with tag Name=${TAG_NAME}"
  INSTANCE_IDS=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${TAG_NAME}" --query "Reservations[*].Instances[*].InstanceId" --output text)

  # Vérifier s'il y a des instances à supprimer
  if [ -z "$INSTANCE_IDS" ]; then
    echo "No instances found with the Name tag '${TAG_NAME}'."
    return
  fi

  # Terminer les instances trouvées
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
  echo "Instances termination initiated for tag Name=${TAG_NAME}."
}

terminate_instances "roue-dynatrace-modernize-workshop-ez-monolith"
terminate_instances "roue-dynatrace-modernize-workshop-ez-docker"
