# Deploying Spaceloop to Railway

## Step 1: Create Railway Account
1. Go to [railway.app](https://railway.app)
2. Sign up with GitHub

## Step 2: Prepare Your Code
Since Railway only provides one PORT, we'll run just the game server (not the HTTP status server).

## Step 3: Deploy to Railway

### Option A: Deploy via GitHub (Recommended)
1. Push your code to GitHub:
```bash
git add .
git commit -m "Add Railway deployment files"
git push origin main
```

2. In Railway dashboard:
   - Click "New Project"
   - Choose "Deploy from GitHub repo"
   - Select your repository
   - Railway will auto-detect the Dockerfile

### Option B: Deploy via CLI
1. Install Railway CLI:
```bash
npm install -g @railway/cli
```

2. Login and deploy:
```bash
railway login
railway link
railway up
```

## Step 4: Get Your Server URL
After deployment, Railway will provide:
- A public URL like: `your-app.up.railway.app`
- The PORT is automatically assigned

## Step 5: Update Your Game Client
Update your game to connect to the Railway server:

1. In `multiplayer_client.gd`, change:
```gdscript
var error = peer.create_client("127.0.0.1", 8910)
```
to:
```gdscript
var error = peer.create_client("your-app.up.railway.app", 443)
```

Note: Railway uses port 443 for external connections, which gets routed to your container's PORT.

## Important Notes:
- Railway's free tier gives you 500 hours/month
- The server will sleep after 10 minutes of inactivity
- You can keep it awake with a health check service
- HTTP status server won't work on Railway (only one port allowed)

## Monitoring
View logs in Railway dashboard or via CLI:
```bash
railway logs
```