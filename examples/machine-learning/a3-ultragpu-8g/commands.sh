# create a GCS bucket for storing terraform state
gcloud storage buckets create gs://gcp64-03-2026-terraform \
    --project=projectseald \
    --default-storage-class=STANDARD --location=us-south1 \
    --uniform-bucket-level-access
gcloud storage buckets update gs://gcp64-03-2026-terraform --versioning --project=projectseald

# check gcluster version
./gcluster version

cd /home/ubuntu/gcp64-03-2026/cluster-toolkit-gcp64-03-2026

# skip auto-approve first
./gcluster deploy -d examples/machine-learning/a3-ultragpu-8g/a3ultra-slurm-deployment.yaml examples/machine-learning/a3-ultragpu-8g/a3ultra-slurm-blueprint.yaml --auto-approve