# GCP Cloud Native CICD Pipeline

Uses the following technologies:

- CSR
- AR
- Cloud Build
- Cloud Deploy
- GKE

## Getting Started

1. Clone this repo: `git clone github.com/MaGilli81/cloud-deploy-demo && cd cloud-deploy-demo`
2. Make 2 scripts executable: `chmod +x setupscript.sh && chmod +x cleanup.sh`
3. Setup the environment run: `./setupscript.sh`

After the script completes, you will have:

- Enabled all the necessary APIs
- Created a GKE standard cluster
- Created Cloud Source Repository for **hello-cloudbuild-app** and **hello-cloudbuild-env**
- Created Cloud Build Triggers for **hello-cloudbuild-ci** and **hello-cloudbuild-deploy**
- Created an Artifact Registry Repository for the image output of **hello-cloudbuild-ci** trigger
- Created a Cloud Deploy pipeline for deploying the image to the **hello-cloudbuild** GKE cluster
- End result will deploy a kubernetes.yaml file with a deployment and service for hello-cloudbuil-app

## Clean Up

To delete the environment run: `./cleanup.sh
