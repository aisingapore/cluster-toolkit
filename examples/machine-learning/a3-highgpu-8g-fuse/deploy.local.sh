#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(git -C "${script_dir}" rev-parse --show-toplevel)"
env_file="${repo_dir}/.env"

if [[ ! -f "${env_file}" ]]; then
  echo "Missing ${env_file}" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${env_file}"
set +a

: "${TCPX_KERNEL_LOGIN:?Set TCPX_KERNEL_LOGIN in .env}"
: "${TCPX_KERNEL_PASSWORD:?Set TCPX_KERNEL_PASSWORD in .env}"
: "${KEYSERVER_UBUNTU_KEY:?Set KEYSERVER_UBUNTU_KEY in .env}"

"${repo_dir}/gcluster" deploy \
  -d "${script_dir}/a3high-slurm-gcsfuse-lssd-deployment.yaml" \
  --vars "tcpx_kernel_login=${TCPX_KERNEL_LOGIN}" \
  --vars "tcpx_kernel_password=${TCPX_KERNEL_PASSWORD}" \
  --vars "keyserver_ubuntu_key=${KEYSERVER_UBUNTU_KEY}" \
  "${script_dir}/a3high-slurm-gcsfuse-lssd.yaml" \
  --auto-approve
