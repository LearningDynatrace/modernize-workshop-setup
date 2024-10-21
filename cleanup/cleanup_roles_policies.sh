#!/bin/bash

delete_iam_resources() {
  local RESOURCE_TYPE=$1
  local SEARCH_KEYWORD=$2

  if [ "$RESOURCE_TYPE" == "role" ]; then
    echo "Listing all IAM roles containing '${SEARCH_KEYWORD}'"
    RESOURCE_NAMES=$(aws iam list-roles --query "Roles[?contains(RoleName, '${SEARCH_KEYWORD}')].RoleName" --output text)
  elif [ "$RESOURCE_TYPE" == "policy" ]; then
    echo "Listing all IAM policies containing '${SEARCH_KEYWORD}'"
    RESOURCE_NAMES=$(aws iam list-policies --scope Local --query "Policies[?contains(PolicyName, '${SEARCH_KEYWORD}')].Arn" --output text)
  else
    echo "Invalid resource type: ${RESOURCE_TYPE}"
    exit 1
  fi

  # Vérifier s'il y a des ressources à supprimer
  if [ -z "$RESOURCE_NAMES" ]; then
    echo "No IAM ${RESOURCE_TYPE}s found containing '${SEARCH_KEYWORD}'."
    return
  fi

  # Boucle sur chaque ressource trouvée et la supprimer
  for RESOURCE in $RESOURCE_NAMES; do
    echo "Deleting IAM ${RESOURCE_TYPE}: $RESOURCE"
    if [ "$RESOURCE_TYPE" == "role" ]; then
      # Detach role from instance profiles
      INSTANCE_PROFILES=$(aws iam list-instance-profiles-for-role --role-name $RESOURCE --query "InstanceProfiles[*].InstanceProfileName" --output text)
      for PROFILE in $INSTANCE_PROFILES; do
        echo "Removing role $RESOURCE from instance profile $PROFILE"
        aws iam remove-role-from-instance-profile --instance-profile-name $PROFILE --role-name $RESOURCE
      done
      # Detach all policies from the role
      ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name $RESOURCE --query "AttachedPolicies[*].PolicyArn" --output text)
      for POLICY_ARN in $ATTACHED_POLICIES; do
        echo "Detaching policy $POLICY_ARN from role $RESOURCE"
        aws iam detach-role-policy --role-name $RESOURCE --policy-arn $POLICY_ARN
      done
      aws iam delete-role --role-name $RESOURCE
    elif [ "$RESOURCE_TYPE" == "policy" ]; then
      aws iam delete-policy --policy-arn $RESOURCE
    fi
    echo "${RESOURCE_TYPE^} $RESOURCE deletion initiated."
  done

  echo "All matching IAM ${RESOURCE_TYPE}s are being deleted."
}

delete_iam_resources "role" "Dynatrace"
delete_iam_resources "policy" "Dynatrace"