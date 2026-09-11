#!/bin/bash

set -euxo pipefail

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------
exec > >(tee /var/log/workstation-user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "========================================="
echo "Starting workstation setup"
echo "========================================="

# ------------------------------------------------------------
# Disk resize
# ------------------------------------------------------------
echo "Growing partition..."

growpart /dev/nvme0n1 4 || true

lvextend -L +30G /dev/mapper/RootVG-varVol || true

xfs_growfs /var || true

# ------------------------------------------------------------
# Install Docker
# ------------------------------------------------------------
echo "Installing Docker..."

dnf -y install dnf-plugins-core

dnf config-manager --add-repo \
  https://download.docker.com/linux/rhel/docker-ce.repo

dnf install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

systemctl enable docker
systemctl start docker

usermod -aG docker ec2-user

echo "Docker installed successfully"

# ------------------------------------------------------------
# Install kubectl
# ------------------------------------------------------------
echo "Installing kubectl..."

cd /tmp

curl -LO \
  https://s3.us-west-2.amazonaws.com/amazon-eks/1.34.2/2025-11-13/bin/linux/amd64/kubectl

chmod +x kubectl

install -m 0755 kubectl /usr/local/bin/kubectl

rm -f kubectl

echo "kubectl version:"
/usr/local/bin/kubectl version --client

# ------------------------------------------------------------
# Install eksctl
# ------------------------------------------------------------
echo "Installing eksctl..."

cd /tmp

curl -sLO \
  https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz

tar -xzf eksctl_Linux_amd64.tar.gz

install -m 0755 eksctl /usr/local/bin/eksctl

rm -f eksctl
rm -f eksctl_Linux_amd64.tar.gz

echo "eksctl version:"
/usr/local/bin/eksctl version

# ------------------------------------------------------------
# Create EKS configuration
# ------------------------------------------------------------
echo "Creating EKS configuration..."

mkdir -p /opt/eks

cat > /opt/eks/cluster.yaml <<'EOC'
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: roboshop-dev
  region: us-east-1

managedNodeGroups:
  - name: roboshop-dev
    instanceTypes:
      - m5.large
      - c3.large
      - c4.large
      - c5.large
    desiredCapacity: 3
    spot: true
EOC

echo "EKS configuration:"
cat /opt/eks/cluster.yaml

# ------------------------------------------------------------
# Verify AWS identity
# ------------------------------------------------------------
echo "Checking AWS identity..."

aws sts get-caller-identity

# ------------------------------------------------------------
# Create EKS cluster
# ------------------------------------------------------------
echo "========================================="
echo "Creating EKS cluster..."
echo "========================================="

/usr/local/bin/eksctl create cluster \
  -f /opt/eks/cluster.yaml

echo "========================================="
echo "EKS cluster creation completed"
echo "========================================="

# ------------------------------------------------------------
# Verify cluster
# ------------------------------------------------------------
echo "Checking EKS cluster..."

aws eks list-clusters --region us-east-1

echo "========================================="
echo "Workstation setup completed"
echo "========================================="