#! /bin/bash
# Push only if it's not a pull request
if [ -z "$TRAVIS_PULL_REQUEST" ] || [ "$TRAVIS_PULL_REQUEST" == "false" ]; then
  # Push only if we're testing a deployable branch
  if [ "$TRAVIS_BRANCH" == "development" ] || [ "$TRAVIS_BRANCH" == "qa" ] || [ "$TRAVIS_BRANCH" == "production" ]; then

    case "$TRAVIS_BRANCH" in
      production)
        export AWS_ACCESS_KEY_ID=$aws_access_key_id_production
        export AWS_SECRET_ACCESS_KEY=$aws_secret_access_key_production
        DOCKER_REPO_URL=$REMOTE_IMAGE_URL_PRODUCTION
        ;;
      qa)
        export AWS_ACCESS_KEY_ID=$aws_access_key_id_production
        export AWS_SECRET_ACCESS_KEY=$aws_secret_access_key_production
        DOCKER_REPO_URL=$REMOTE_IMAGE_URL_QA
        ;;
      *)
        export AWS_ACCESS_KEY_ID=$aws_access_key_id_development
        export AWS_SECRET_ACCESS_KEY=$aws_secret_access_key_development
        DOCKER_REPO_URL=$REMOTE_IMAGE_URL_DEVELOPMENT
        ;;
    esac

    # This is needed to login on AWS and push the image on ECR
    # Change it accordingly to your docker repo
    pip install --user awscli
    export PATH=$PATH:$HOME/.local/bin
    eval $(aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION)

    # Build and push
    LOCAL_TAG_NAME=$IMAGE_NAME:$TRAVIS_BRANCH-latest
    REMOTE_FULL_URL=$DOCKER_REPO_URL:$TRAVIS_BRANCH-latest

    docker build -t $LOCAL_TAG_NAME .
    echo "Pushing $LOCAL_TAG_NAME"
    docker tag $LOCAL_TAG_NAME "$REMOTE_FULL_URL"
    docker push "$REMOTE_FULL_URL"
    echo "Pushed $LOCAL_TAG_NAME to $REMOTE_FULL_URL"
  else
    echo "Skipping deploy because branch is not a deployable branch"
  fi
else
  echo "Skipping deploy because it's a pull request"
fi
