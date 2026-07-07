./gcluster deploy examples/machine-learning/a2-ultragpu-8g-fuse/ml-slurm-gcsfuse-lssd.yaml -d examples/machine-learning/a2-ultragpu-8g-fuse/ml-slurm-gcsfuse-lssd-deployment.yaml --auto-approve -w


gcloud compute firewall-rules create a2ultra-allow-ssh-public \
--project=projectseald \
--network=a2ultra-slurm-gcsfuse-net \
--direction=INGRESS \
--action=ALLOW \
--rules=tcp:22 \
--source-ranges=0.0.0.0/0 \
--target-tags=a2ultraslu