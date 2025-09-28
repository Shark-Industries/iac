#!/bin/bash

# Setup script for GCP project and service account
# Run this once to initialize the GCP project

PROJECT_ID="shark-outboards-prod"
BILLING_ACCOUNT_ID=""  # Set your billing account ID
SERVICE_ACCOUNT_NAME="terraform"
REGION="us-central1"

echo "Setting up GCP project: $PROJECT_ID"

# Create project
echo "Creating project..."
gcloud projects create $PROJECT_ID --name="Shark Outboards Production"

# Link billing account (requires billing account ID)
if [ -n "$BILLING_ACCOUNT_ID" ]; then
    echo "Linking billing account..."
    gcloud beta billing projects link $PROJECT_ID --billing-account=$BILLING_ACCOUNT_ID
else
    echo "WARNING: No billing account ID provided. Please link billing manually."
fi

# Set project as default
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "Enabling required APIs..."
gcloud services enable \
    compute.googleapis.com \
    dns.googleapis.com \
    storage.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iam.googleapis.com

# Create service account
echo "Creating service account..."
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
    --display-name="Terraform Service Account"

# Grant necessary roles
echo "Granting roles to service account..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/compute.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/dns.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"

# Create GCS bucket for Terraform state
echo "Creating Terraform state bucket..."
gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://shark-outboards-terraform-state/

# Enable versioning on the bucket
gsutil versioning set on gs://shark-outboards-terraform-state/

# Create service account key
echo "Creating service account key..."
gcloud iam service-accounts keys create ~/terraform-sa-key.json \
    --iam-account=$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com

echo ""
echo "Setup complete!"
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. Save the service account key from ~/terraform-sa-key.json"
echo "2. Add it as a GitHub secret named GOOGLE_CREDENTIALS"
echo "3. For local development, set: export GOOGLE_APPLICATION_CREDENTIALS=~/terraform-sa-key.json"
echo "4. Update terraform.tfvars with your domain name and SSH keys"
echo "5. Link billing account if not done automatically"