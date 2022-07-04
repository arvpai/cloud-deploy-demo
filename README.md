Run ./setupscript.sh

Run ./cleanup.sh

Clone this repo: git clone github.com/MaGilli81/cloud-deploy-demo

Make 2 scripts executable: chmod +x setupscript.sh && chmod +x cleanup.sh  

Setup the environment run: ./setupscript.sh

After the script completes, you will have:
- Enabled all the necessary APIs
- Created a GKE standard cluster
- Created Cloud Source Repository for hello-cloudbuild-app and hello-cloudbuild-env
- Created Cloud Build Triggers for hello-cloudbuild-ci and hello-cloudbuild-deploy
- Created an Artifact Registry Repository for the image output of hello-cloudbuild-ci trigger
- Created a Cloud Deploy pipeline for deploying the image to the hello-cloudbuild GKE cluster

To delete the environment run: ./cleanup.sh
