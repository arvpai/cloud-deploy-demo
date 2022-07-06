#!/bin/bash
export PROJECT_ID=$(gcloud config get-value core/project)
export PROJECT_NUMBER="$(gcloud projects describe ${PROJECT_ID} --format='get(projectNumber)')"

#DELETE CLOUD BUILD TRIGGERS
gcloud beta builds triggers delete hello-cloudbuild-ci
gcloud beta builds triggers delete hello-cloudbuild-deploy

#DELETE REPOS IN CSR
gcloud source repos delete hello-cloudbuild-app --quiet
gcloud source repos delete hello-cloudbuild-env --quiet

#DELETE AR REPOSITORY AND IMAGE
gcloud artifacts repositories delete my-repository \
    --location=us-central1 \
    --quiet

# #DELETE THE GKE CLUSTER
# gcloud container clusters delete hello-cloudbuild \
#    --region us-central1 \
#    --quiet

#DELETE CLOUD DEPLOY PIPELINE
gcloud deploy delete --file=delivery-pipeline.yaml --region=us-central1 --force
gcloud deploy delete --file=target-dev.yaml --region=us-central1 --force

#REMOVE FILES FROM SHELL
rm -rf hello-cloudbuild-app
rm -rf hello-cloudbuild-env