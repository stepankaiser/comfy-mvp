#!/bin/bash

echo "=== ComfyUI Golden Image System Test ==="

# Check if .env file exists and has correct variables
if [ ! -f ".env" ]; then
    echo "❌ .env file not found!"
    echo "Please copy env.example to .env and set your AWS credentials"
    exit 1
fi

# Check if AWS credentials are set
if ! grep -q "AWS_ACCESS_KEY_ID=AKIA" .env; then
    echo "❌ AWS_ACCESS_KEY_ID not properly set in .env"
    exit 1
fi

if grep -q "your_secret_key_here" .env; then
    echo "❌ AWS_SECRET_ACCESS_KEY still contains placeholder"
    echo "Please set your real AWS secret key in .env file"
    exit 1
fi

echo "✅ Environment configuration looks good"

# Build and start the system
echo "🏗️  Building Docker images..."
docker-compose build

echo "🚀 Starting Golden Image system..."
docker-compose up -d

echo "⏳ Waiting for containers to start..."
sleep 10

# Check container status
echo "📊 Container Status:"
docker-compose ps

echo ""
echo "🎉 Golden Image System Started!"
echo ""
echo "Access points:"
echo "- Admin ComfyUI: http://localhost:8190"
echo "- Admin Manager:  http://localhost:8190/manager"
echo "- User ComfyUI:   http://localhost:8191"
echo "- User Manager:   http://localhost:8191/manager (read-only)"
echo ""
echo "Admin workflow:"
echo "1. Open http://localhost:8190"
echo "2. Install models via ComfyUI interface or Manager"
echo "3. Install custom nodes via ComfyUI Manager"
echo "4. Changes are automatically synced to S3"
echo ""
echo "User experience:"
echo "1. Open http://localhost:8191"
echo "2. All admin models and nodes are available"
echo "3. Generate images normally"
echo "4. ComfyUI Manager shows available content (read-only)"
echo ""
echo "Monitor logs with:"
echo "docker-compose logs -f admin_comfyui"
echo "docker-compose logs -f user_comfyui" 