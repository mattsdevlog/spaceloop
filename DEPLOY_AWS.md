# Deploy to AWS (Free for 12 months)

## Using AWS Lightsail (Simplest AWS option)

### 1. Sign up for AWS
- Go to [aws.amazon.com](https://aws.amazon.com)
- Create account (credit card required)

### 2. Go to Lightsail
- Visit [lightsail.aws.amazon.com](https://lightsail.aws.amazon.com)
- Click "Create Instance"

### 3. Create Instance
- Platform: Linux/Unix
- Blueprint: Ubuntu 22.04 LTS
- Instance Plan: First month free ($3.50/month after)
- Name: spaceloop-server
- Click "Create Instance"

### 4. Setup Networking
- Click on your instance
- Go to "Networking" tab
- Add rules:
  - Custom TCP 8910
  - Custom TCP 8911

### 5. Connect & Install
Click "Connect using SSH" button, then:
```bash
# Install Godot
sudo apt update
sudo apt install -y wget unzip screen
wget https://downloads.tuxfamily.org/godotengine/4.3/Godot_v4.3-stable_linux.x86_64.zip
unzip Godot_v4.3-stable_linux.x86_64.zip
sudo mv Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot

# Upload your files (from your local machine):
# scp -r * ubuntu@YOUR_IP:~/spaceloop/

# Or clone from git
git clone YOUR_REPO_URL spaceloop
cd spaceloop

# Run with screen (survives disconnection)
screen -S game
godot --headless run_server.gd
# Press Ctrl+A then D to detach

screen -S http
godot --headless run_http_server.gd
# Press Ctrl+A then D to detach

# Reattach: screen -r game
```

Your server IP is shown in Lightsail dashboard!