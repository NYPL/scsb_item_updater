#! /bin/bash
# Deploy only if it's not a pull request
if [ -z "$TRAVIS_PULL_REQUEST" ] || [ "$TRAVIS_PULL_REQUEST" == "false" ]; then
  # Deploy only if we're testing the master branch
  if [ "$TRAVIS_BRANCH" == "development" ] || [ "$TRAVIS_BRANCH" == "qa" ] || [ "$TRAVIS_BRANCH" == "production" ]; then

    case "$TRAVIS_BRANCH" in
      production)
        AWS_ACCESS_KEY_ID=$aws_access_key_id_production
        AWS_SECRET_ACCESS_KEY=$aws_secret_access_key_production
        CLUSTER_NAME=$CLUSTER_NAME_PRODUCTION
        SERVICE_NAME=$SERVICE_NAME_PRODUCTION
        ;;
      qa)
        AWS_ACCESS_KEY_ID=$aws_access_key_id_production
        AWS_SECRET_ACCESS_KEY=$aws_secret_access_key_production
        CLUSTER_NAME=$CLUSTER_NAME_QA
        SERVICE_NAME=$SERVICE_NAME_QA
        ;;
      *)
        AWS_ACCESS_KEY_ID=$aws_access_key_id_development
        AWS_SECRET_ACCESS_KEY=$aws_secret_access_key_development
        CLUSTER_NAME=$CLUSTER_NAME_DEVELOPMENT
        SERVICE_NAME=$SERVICE_NAME_DEVELOPMENT
        ;;
    esac

    echo "Deploying $TRAVIS_BRANCH on $TASK_DEFINITION"
    AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION aws ecs update-service --cluster $CLUSTER_NAME --region us-east-1 --service $SERVICE_NAME --force-new-deployment
  else
    echo "Skipping deploy because it's not a deployable branch"
  fi
else
  echo "Skipping deploy because it's a PR"
fi
