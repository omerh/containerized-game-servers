#!/bin/bash

npm install aws-cdk-lib
. ~/.bash_profile
cdk bootstrap aws://$AWS_ACCOUNT_ID/$AWS_REGION
npm install
cdk deploy --app "npx ts-node --prefer-ts-exts ./base-pipeline.ts"  --parameters BUILDXVER=$BUILDX_VER --parameters BASEREPO=$BASE_REPO --parameters BASEIMAGETAG=$BASE_IMAGE_TAG 
