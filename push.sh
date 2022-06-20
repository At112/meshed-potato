#!/bin/bash -x
#
# Builds a Docker image and pushes to an AWS ECR repository

set -e

source_path="./project" 
repository_url="181608912584.dkr.ecr.us-east-1.amazonaws.com/aws-terraform-test" 
tag="latest"
userid="AWS"

# splits string using '.' and picks 4th item
region="us-east-1"

# splits string using '/' and picks 2nd item
image_name="$(echo "$repository_url" | cut -d/ -f2)"

# builds docker image
(cd "$source_path" && DOCKER_BUILDKIT=1 docker build -t "$image_name" .)

# login to ecr
aws --region "$region" ecr get-login-password | docker login --username AWS --password-stdin ${userid}.dkr.ecr.us-east-1.amazonaws.com

#$(aws ecr get-login-password --region "$region")

# tag image
docker tag "$image_name" "$repository_url":"$tag"

# push image
docker push "$repository_url":"$tag"