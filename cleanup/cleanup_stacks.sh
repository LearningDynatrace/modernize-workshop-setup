#!/bin/bash

# Récupérer toutes les stacks actives (CREATE_COMPLETE, UPDATE_COMPLETE)
STACKS=$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE ROLLBACK_COMPLETE --query "StackSummaries[*].StackName" --output text)

# Vérifier si des stacks existent
if [ -z "$STACKS" ]; then
  echo "No active stacks found."
  exit 0
fi

# Boucle sur chaque stack et la supprime
for STACK in $STACKS; do
  echo "Deleting stack: $STACK"
  aws cloudformation delete-stack --stack-name $STACK
  echo "Stack $STACK deletion initiated."
done

echo "All stacks are being deleted."
