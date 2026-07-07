#!/usr/bin/env bash

bash examples/machine-learning/a3-highgpu-8g-fuse/deploy.local.sh

gcloud compute firewall-rules create a3high-allow-ssh-public \
    --project=projectseald \
    --network=a3high-slurm-gcsfuse-net-0 \
    --direction=INGRESS \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=a3high