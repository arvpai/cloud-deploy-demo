#!/bin/bash

#### SET PROJECT VARIABLES ####
export GITHUB_USERNAME=xxxxx
export GITHUB_USEREMAIL=xxxx@xxxx.com  
export PROJECT_ID=$(gcloud config get-value core/project)
export PROJECT_NUMBER="$(gcloud projects describe ${PROJECT_ID} --format='get(projectNumber)')"
export AR_REPOSITORY=my-repository
export GKE_CLUSTER=hello-cloudbuild
export REGION=us-central1
export CSR_REPOSITORY_APP=hello-cloudbuild-app
export CSR_REPOSITORY_ENV=hello-cloudbuild-env
export TRIGGER_CI=hello-cloudbuild-ci
export TRIGGER_DEPLOY=hello-cloudbuild-deploy

gcloud config set project $PROJECT_ID

#### ENABLE APIS ####
gcloud services enable container.googleapis.com \
    cloudbuild.googleapis.com \
    sourcerepo.googleapis.com \
    artifactregistry.googleapis.com \
    compute.googleapis.com \
    container.googleapis.com \
    storage.googleapis.com \
    container.googleapis.com \
    gkeconnect.googleapis.com \
    gkehub.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iam.googleapis.com

# #### CREATE A GKE STANDARD CLUSTER ####
gcloud container clusters create ${GKE_CLUSTER} \
--num-nodes 1 --region ${REGION}

#### Grab credentials to the GKE cluster
# gcloud container clusters get-credentials hello-cloudbuild --region ${REGION}--project ${PROJECT_ID}

gcloud container clusters get-credentials ${GKE_CLUSTER} --region us-central1 --project ${PROJECT_ID}
#### CREATE AN ARTIFACT REPOSITORY ####
gcloud artifacts repositories create ${AR_REPOSITORY} \
  --repository-format=docker \
  --location=${REGION}

# CREATE A REPO IN CLOUD SOURCE REPOSITORY
gcloud source repos create ${CSR_REPOSITORY_APP}
gcloud source repos create ${CSR_REPOSITORY_ENV}

# #### Add gke hub admin rolel to user in IAM #####
# #### REGISTER THE CLUSTER TO ANTHOS ####
# gcloud container fleet memberships register hello-cloudbuild-membership \
#  --gke-cluster=https://container.googleapis.com/v1/projects/$PROJECT_ID/locations/us-central1/clusters/hello-cloudbuild \
#  --enable-workload-identity

#### CLONE A GITHUB REPOSITORY FOR THE HELLO-CLOUDBUILD-APP SOURCE CODE #### 
cd ~
git clone https://github.com/xxxx/gke-gitops-tutorial-cloudbuild \
    hello-cloudbuild-app

#### CONFIGURE HELLO-CLOUDBUILD-APP CSR REPO AS THE REMOTE #### 
cd ~/hello-cloudbuild-app
PROJECT_ID=$(gcloud config get-value project)
git remote add google \
    "https://source.developers.google.com/p/${PROJECT_ID}/r/hello-cloudbuild-app"

#### TAG THE HELLO-CLOUDBUILD-APP WITH THE LATEST COMMIT_SHA(THIS IS PICKED UP FROM CLOUD BUILD)####
cd ~/hello-cloudbuild-app
COMMIT_ID="$(git rev-parse --short=7 HEAD)"
gcloud builds submit --tag="us-central1-docker.pkg.dev/${PROJECT_ID}/${AR_REPOSITORY}/hello-cloudbuild:${COMMIT_ID}" .

#### CREATE CLOUD BUILD TRIGGER FOR CONTINUOUS  INTEGRATION PIPELINE FOR HELLO-CLOUDBUILD-APP
#### CLOUD BUILD CI TRIGGER SHOULD CONTAIN A CLOUD BUILD YAML FILE THAT PACKAGES, CONTAINERIZES AND TAGS AN IMAGE BEFORE PUSHING IMAGE TO ARTIFACT REGISTRY ####
gcloud beta builds triggers create cloud-source-repositories \
    --repo=${CSR_REPOSITORY_APP} \
    --branch-pattern=^master$ \
    --build-config=cloudbuild.yaml \
    --name=${TRIGGER_CI}

#### IDENTIFY AUTHOR OF COMMITS
git config --global user.email "${GITHUB_USEREMAIL}"
git config --global user.name "${GITHUB_USERNAME}"

#### PUSH APPLICATION CODE TO THE HELLO-CLOUDBUILD-APP CSR REPO'S MASTER BRANCH TO START THE CI PROCESS
cd ~/hello-cloudbuild-app

echo "test"
sed -i 's/Hello World/Hello Cloud Build/g' app.py
sed -i 's/Hello World/Hello Cloud Build/g' test_app.py

git add .
git commit -m "initial commit"
git push google master

#### SERVICE ACCOUNTS ####
#### GRANT CONTAINER.DEVELOPER ROLE TO CLOUD BUILD DEFAULT SERVICE ACCOUNT ####
gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
    --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
    --role=roles/container.developer \
    --role=roles/source.writer

#### CLONE THE HELLO-CLOUDBUILD-ENV REPO AND CREATE A PRODUCTION BRANCH
cd ~
gcloud source repos clone hello-cloudbuild-env
cd ~/hello-cloudbuild-env
git checkout -b production

#### Copy the cloudbuild-delivery.yaml file available in the hello-cloudbuild-app repository and commit the change ####
#### Copy the cloudbuild-delivery.yaml file available in the hello-cloudbuild-app repository and commit the change ####
cd ../hello-cloudbuild-env
echo "testing"
cp ~/hello-cloudbuild-app/cloudbuild-delivery.yaml ~/hello-cloudbuild-env/cloudbuild.yaml
echo "copying"
git add .
git commit -m "Create cloudbuild.yaml for deployment"

#### CREATE A CANDIDATE BRANCH AND PUSH TO UPDATE THE PRODUCTION AND CANDIDATE BRANCH ####
git push origin production
git checkout -b candidate
git push origin candidate

#### GRANT CLOUD BUILD THE SOURCE WRITER ROLE TO WRITE CODE TO THE HELLO-CLOUDBUIL-ENV CSR REPO ####
cat >/tmp/hello-cloudbuild-env-policy.yaml <<EOF
bindings:
- members:
  - serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
  role: roles/source.writer
EOF
gcloud source repos set-iam-policy \
    hello-cloudbuild-env /tmp/hello-cloudbuild-env-policy.yaml

#### CREATE CLOUD BUILD TRIGGER FOR CONTINUOS DELIVER PIPELINE FOR HELLO-CLOUDBUILD-APP
#### CLOUD BUILD CD TRIGGER SHOULD CONTAIN A CLOUD BUILD YAML FILE THAT GRABS THE IMAGE FROM ARTIFACT REGISTRY AND DEPLOYS IT TO GKE, OR CLOUD DEPLOY ####
gcloud beta builds triggers create cloud-source-repositories \
    --repo=hello-cloudbuild-env \
    --branch-pattern=.* \
    --build-config=cloudbuild.yaml \
    --name=hello-cloudbuild-deploy
    
#### KICK OFF THE CI BY GENERATING A NEW VERSION BY REPLACING THE CLOUDBUILD.YAML FILE WITH THE CLOUDBUILD-TRIGGER-CD.YAML FILE ####
cd ~/hello-cloudbuild-app
cp cloudbuild-trigger-cd.yaml cloudbuild.yaml


####Commit the modifications and push them to Cloud Source Repositories. Commit the modifications and push them to Cloud Source Repositories.
cd ~/hello-cloudbuild-app
git add .
git commit -m "Trigger CD pipeline"
git push google master

# #### GRANT THE CLOUD DEPLOY SA THE JOBRUNNER ROLE ####
#  gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
#      --member=serviceAccount:$(gcloud projects describe ${PROJECT_NUMBER} \
#      --format="value(projectNumber)")-compute@developer.gserviceaccount.com \
#      --role=roles/clouddeploy.jobRunner \
#      --role=roles/container.developer

# #### REGISTER CLOUD DEPLOY DELIVERY PIPELINE ####
# cd ~/cloud-deploy-76/cloud-deploy-demo
# gcloud deploy apply --file=delivery-pipeline.yaml --region=${REGION} && \
# gcloud deploy apply --file=target-dev.yaml --region=${REGION}

# #### CREATE A RELEASE FOR THE CLOUD DEPLOY DELIVERY PIPELINE ####
# export PROJECT_ID=$(gcloud config get-value core/project)
# gcloud config set project $PROJECT_ID
# gcloud deploy releases create my-release45 \
# --delivery-pipeline=hello-cloudbuild-delivery-pipeline \
# --region=${REGION} \
# --images=us-central1-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild

# gcloud config set project ${PROJECT_ID}
# gcloud deploy releases create my-release \
#   --delivery-pipeline=hello-cloudbuild-delivery-pipeline \
#   --region=us-central1 \
# #   --build-artifacts=gs://$PROJECT_ID_clouddeploy_us-central1/source/1657133930.500557-104e499573cb4b4ea54eae66b8448aad.tgz