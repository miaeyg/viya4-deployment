#!/usr/bin/env bash

# Copyright © 2020-2023, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

set -e

# AWS
# Authenticate Helm to AWS ECR
# When running this image mount the ".aws" folder to it for this to work
# for example:
# --volume ~/.aws:/viya4-deployment/.aws
#
if [ -d "/viya4-deployment/.aws" ]; then
   export _profile=$(aws configure list-profiles)
   echo $_profile
   export _region=$(aws configure get region --profile ${_profile})
   echo $_region
   export _accountID=$(aws sts get-caller-identity --profile ${_profile} | jq -r '.Account')
   echo $_accountID
   aws ecr get-login-password --profile ${_profile} --region ${_region} | helm registry login --username AWS --password-stdin ${_accountID}.dkr.ecr.${_region}.amazonaws.com
   chmod 770 /viya4-deployment/.config -R
fi

# setup container user
echo "viya4-deployment:*:$(id -u):$(id -g):,,,:/viya4-deployment:/bin/bash" >> /etc/passwd
echo "viya4-deployment:*:$(id -G | cut -d' ' -f 2)" >> /etc/group

OPTS="-e BASE_DIR=/data"

for MOUNT in "/config"/*
do
  base=$(basename $MOUNT)
  VAR=${base^^}

  if [[ "$VAR" == "VAULT_PASSWORD_FILE" ]]; then
    OPTS+=" --vault-password-file $MOUNT"
  else
    OPTS+=" -e $VAR=$MOUNT"
  fi
done

# TODO: Can remove the next line when the default GKE kubernetes_version is moved to 1.26 and greater
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
echo  "Running: ansible-playbook $OPTS $@ playbooks/${PLAYBOOK}"
ANSIBLE_STDOUT_CALLBACK=yaml exec ansible-playbook $OPTS $@ playbooks/${PLAYBOOK}
