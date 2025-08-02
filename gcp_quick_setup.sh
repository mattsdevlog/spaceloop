#!/bin/bash

# Quick GCP Setup Script for Spaceloop Server

echo "=== GCP Quick Setup for Spaceloop ==="
echo "Run this in Google Cloud Shell"
echo ""

# Set variables
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-a"  # Change if you want a different region
INSTANCE_NAME="spaceloop-server"

echo "Creating VM instance..."
gcloud compute instances create $INSTANCE_NAME \
  --zone=$ZONE \
  --machine-type=e2-micro \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=30GB \
  --tags=game-server \
  --metadata=startup-script='#!/bin/bash
# Install Godot on startup
apt-get update
apt-get install -y wget unzip
cd /opt
wget -q https://downloads.tuxfamily.org/godotengine/4.3/Godot_v4.3-stable_linux.x86_64.zip
unzip -q Godot_v4.3-stable_linux.x86_64.zip
mv Godot_v4.3-stable_linux.x86_64 godot
chmod +x godot
rm *.zip
'

echo "Creating firewall rules..."
gcloud compute firewall-rules create spaceloop-game \
  --allow tcp:8910,tcp:8911 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=game-server \
  --description="Allow Spaceloop game traffic"

echo "Waiting for instance to be ready..."
sleep 30

echo "Getting external IP..."
EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo ""
echo "=== Setup Complete! ==="
echo "Server IP: $EXTERNAL_IP"
echo ""
echo "Next steps:"
echo "1. SSH into your server:"
echo "   gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo ""
echo "2. Upload your game files:"
echo "   gcloud compute scp --recurse /Users/matt/spaceloop/* $INSTANCE_NAME:~/spaceloop/ --zone=$ZONE"
echo ""
echo "3. Run the server:"
echo "   cd spaceloop && /opt/godot --headless run_server.gd"
echo ""
echo "Your server IP is: $EXTERNAL_IP"
echo "Update this in your game client!"