set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

mkdir -p /tmp/nvidia

cd /tmp/nvidia

wget wget https://developer.download.nvidia.com/compute/cuda/12.4.1/local_installers/cuda_12.4.1_550.54.15_linux.run

chmod +x cuda_12.4.1_550.54.15_linux.run

apt --purge remove '*nvidia*535*' -y
apt install linux-headers-$(uname -r) -y

./cuda_12.4.1_550.54.15_linux.run --silent --override-driver-check

