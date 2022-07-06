#!/bin/bash

#### SET PROJECT VARIABLES ####
export GITHUB_USERNAME=MaGilli81
export GITHUB_USEREMAIL=mattgilliam0904@gmail.com  
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
    clouddeploy.googleapis.com \
    compute.googleapis.com \
    container.googleapis.com \
    storage.googleapis.com \
    container.googleapis.com \
    gkeconnect.googleapis.com \
    gkehub.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iam.googleapis.com

#### CREATE A GKE STANDARD CLUSTER ####
gcloud container clusters create ${GKE_CLUSTER} \
    --num-nodes 1 --region ${REGION}

#### CREATE AN ARTIFACT REPOSITORY ####
gcloud artifacts repositories create ${AR_REPOSITORY} \
  --repository-format=docker \
  --location=${REGION}

# #### IDENTIFY AUTHOR OF COMMITS
# git config --global user.email "${GITHUB_USEREMAIL}"
# git config --global user.name "${GITHUB_USERNAME}"

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
git clone https://github.com/MaGilli81/gke-gitops-tutorial-cloudbuild \
    hello-cloudbuild-app

#### CONFIGURE HELLO-CLOUDBUILD-APP CSR REPO AS THE REMOTE #### 
cd ~/hello-cloudbuild-app
git remote add google \
    "https://source.developers.google.com/p/${PROJECT_ID}/r/hello-cloudbuild-app"

#### TAG THE HELLO-CLOUDBUILD-APP WITH THE LATEST COMMIT_SHA(THIS IS PICKED UP FROM CLOUD BUILD)####
COMMIT_ID="$(git rev-parse --short=7 HEAD)"
gcloud builds submit --tag="us-central1-docker.pkg.dev/${PROJECT_ID}/my-repository/hello-cloudbuild:${COMMIT_ID}" .

#### CREATE CLOUD BUILD TRIGGER FOR CONTINUOUS  INTEGRATION PIPELINE FOR HELLO-CLOUDBUILD-APP
#### CLOUD BUILD CI TRIGGER SHOULD CONTAIN A CLOUD BUILD YAML FILE THAT PACKAGES, CONTAINERIZES AND TAGS AN IMAGE BEFORE PUSHING IMAGE TO ARTIFACT REGISTRY ####
gcloud beta builds triggers create cloud-source-repositories \
    --repo=${CSR_REPOSITORY_APP} \
    --branch-pattern=^master$ \
    --build-config=/cloudbuild.yaml \
    --name=${TRIGGER_CI}

#### IDENTIFY AUTHOR OF COMMITS
git config --global user.email "${GITHUB_USEREMAIL}"
git config --global user.name "${GITHUB_USERNAME}"

#### PUSH APPLICATION CODE TO THE HELLO-CLOUDBUILD-APP CSR REPO'S MASTER BRANCH TO START THE CI PROCESS
cd ~/hello-cloudbuild-app
git push google master

#### SERVICE ACCOUNTS ####
#### GRANT CONTAINER.DEVELOPER ROLE TO CLOUD BUILD DEFAULT SERVICE ACCOUNT ####
gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
    --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
    --role=roles/container.developer \
    --role=roles/source.writer \
    --role=roles/clouddeploy.jobRunner

#### CLONE THE HELLO-CLOUDBUILD-ENV REPO AND CREATE A PRODUCTION BRANCH
cd ~
gcloud source repos clone hello-cloudbuild-env
cd ~/hello-cloudbuild-env
git checkout -b production

#### Copy the cloudbuild-delivery.yaml file available in the hello-cloudbuild-app repository and commit the change ####
#### Copy the cloudbuild-delivery.yaml file available in the hello-cloudbuild-app repository and commit the change ####
cd ~/hello-cloudbuild-env
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
    --repo=${CSR_REPOSITORY_ENV} \
    --branch-pattern=^candidate$ \
    --build-config=/cloudbuild.yaml \
    --name=${TRIGGER_DEPLOY}

#### KICK OFF THE CI BY GENERATING A NEW VERSION BY REPLACING THE CLOUDBUILD.YAML FILE WITH THE CLOUDBUILD-TRIGGER-CD.YAML FILE ####
cd ~/hello-cloudbuild-app
cp cloudbuild-trigger-cd.yaml cloudbuild.yaml

####Commit the modifications and push them to Cloud Source Repositories. Commit the modifications and push them to Cloud Source Repositories.
cd ~/hello-cloudbuild-app
git add cloudbuild.yaml
git commit -m "Trigger CD pipeline"
git push google master

#### GRANT THE CLOUD DEPLOY SA THE JOBRUNNER ROLE ####
 gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
     --member=serviceAccount:$(gcloud projects describe ${PROJECT_NUMBER} \
     --format="value(projectNumber)")-compute@developer.gserviceaccount.com \
     --role=roles/clouddeploy.jobRunner \
     --role=roles/container.developer

#### REGISTER CLOUD DEPLOY DELIVERY PIPELINE ####
cd ~/
gcloud deploy apply --file=delivery-pipeline.yaml --region=${REGION} && \
gcloud deploy apply --file=target-dev.yaml --region=${REGION}

#### CREATE A RELEASE FOR THE CLOUD DEPLOY DELIVERY PIPELINE ####
gcloud config set project ${PROJECT_ID}
gcloud deploy releases create my-release \
--delivery-pipeline=hello-cloudbuild-delivery-pipeline \
--region=${REGION}

# --image=us-central1-docker.pkg.dev/cloud-deploy-354814/my-repository/hello-cloudbuild:d4080a7

# gcloud deploy releases create rel-'$DATE'-'$TIME' \
#   --delivery-pipeline=hello-cloudbuild-delivery-pipeline \
#   --region=us-central1 \
#   --images=image=us-central1-docker.pkg.dev/$PROJECT_ID/my-repository/hello-cloudbuild:${SHORT_SHA}
# google_cloud_project/us-central1/hello-cloudbuild