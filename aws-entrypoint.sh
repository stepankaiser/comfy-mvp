#!/bin/bash
set -e

# AWS ComfyUI Golden Image Entrypoint
# Optimized for Fargate deployment with intelligent S3 caching

echo "=== ComfyUI AWS Golden Image System ==="
echo "Container Role: ${CONTAINER_ROLE:-user}"
echo "Cache Strategy: ${CACHE_STRATEGY:-intelligent}"
echo "S3 Bucket: ${S3_BUCKET_NAME}"
echo "AWS Region: ${AWS_REGION}"

# Validate required environment variables
if [ -z "$S3_BUCKET_NAME" ]; then
  echo "ERROR: S3_BUCKET_NAME must be set as environment variable."
  exit 1
fi

if [ -z "$AWS_REGION" ]; then
  echo "ERROR: AWS_REGION must be set as environment variable."
  exit 1
fi

# Configuration
S3_REMOTE="s3-storage"
MODELS_DIR="/app/models"
CUSTOM_NODES_DIR="/app/custom_nodes"
CACHE_DIR="/tmp/model_cache"
HOT_CACHE_DIR="/tmp/hot_cache"
CACHE_SIZE_GB="${CACHE_SIZE_GB:-160}"

# Create necessary directories
mkdir -p "$CACHE_DIR" "$HOT_CACHE_DIR" "$MODELS_DIR" "$CUSTOM_NODES_DIR"
mkdir -p "/app/shared_python" "/app/shared_libs" "/app/cache" "/app/user"

# Configure rclone for S3 access (using IAM roles, no credentials needed)
echo "Configuring rclone for S3..."
rclone config create "$S3_REMOTE" s3 \
    provider=AWS \
    env_auth=true \
    region="$AWS_REGION" \
    endpoint="$S3_ENDPOINT"

# Test S3 connectivity
echo "Testing S3 connectivity..."
if ! rclone lsd "$S3_REMOTE:$S3_BUCKET_NAME" > /dev/null 2>&1; then
    echo "ERROR: Cannot connect to S3 bucket $S3_BUCKET_NAME"
    exit 1
fi
echo "✓ S3 connectivity verified"

# Model directories to manage
MODEL_DIRS=(
    "checkpoints" "clip" "clip_vision" "configs" "controlnet" "diffusers"
    "embeddings" "gligen" "hypernetworks" "loras" "photomaker" 
    "style_models" "t2i-adapter" "unet" "upscale_models" "vae" "vae_approx"
)

# Popular models to preload (customize based on your usage)
POPULAR_MODELS=(
    "models/checkpoints/sd_xl_base_1.0.safetensors"
    "models/vae/sdxl_vae.safetensors"
    "models/loras/popular_lora.safetensors"
)

# Initialize Python cache manager
init_cache_manager() {
    echo "=== Initializing Intelligent Cache Manager ==="
    
    # Start cache manager in background
    python3 /app/scripts/cache_manager.py &
    CACHE_MANAGER_PID=$!
    
    echo "✓ Cache manager started (PID: $CACHE_MANAGER_PID)"
}

# Sync essential models from S3 (admin only)
sync_essential_models() {
    echo "=== Syncing essential models from S3 ==="
    
    if [ "$CONTAINER_ROLE" = "admin" ]; then
        # For admin, sync a minimal set of essential models
        for dir in "checkpoints" "vae" "clip"; do
            local models_path="$MODELS_DIR/$dir"
            local s3_path="$S3_REMOTE:$S3_BUCKET_NAME/models/$dir"
            
            echo "Syncing essential $dir models..."
            mkdir -p "$models_path"
            
            # Sync only the most essential models (limit to prevent long startup)
            rclone copy "$s3_path" "$models_path" --include "*.safetensors" --max-size 5G --max-age 30d || echo "Warning: Failed to sync $dir"
            
            local count=$(find "$models_path" -name "*.safetensors" 2>/dev/null | wc -l)
            echo "✓ Synced $dir: $count essential models"
        done
    else
        echo "User mode: Skipping initial sync, using on-demand loading"
    fi
}

# Setup model paths with intelligent caching
setup_intelligent_model_paths() {
    echo "=== Setting up intelligent model paths ==="
    
    # Create extra_model_paths.yaml for ComfyUI
    cat > /app/extra_model_paths.yaml << EOF
# ComfyUI Model Paths Configuration
# Using intelligent S3 caching

comfyui:
EOF

    # Add model paths for each directory
    for dir in "${MODEL_DIRS[@]}"; do
        local models_path="$MODELS_DIR/$dir"
        mkdir -p "$models_path"
        
        cat >> /app/extra_model_paths.yaml << EOF
    ${dir}: $models_path
EOF
    done
    
    echo "✓ Model paths configured with intelligent caching"
}

# Setup custom nodes with S3 sync
setup_custom_nodes() {
    echo "=== Setting up custom nodes ==="
    
    # Ensure ComfyUI Manager exists
    if [ ! -d "$CUSTOM_NODES_DIR/ComfyUI-Manager" ]; then
        echo "Installing ComfyUI Manager..."
        git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$CUSTOM_NODES_DIR/ComfyUI-Manager"
    fi
    
    # Ensure Data Manager exists
    if [ ! -d "$CUSTOM_NODES_DIR/ComfyUI-DataManager" ]; then
        echo "Installing ComfyUI Data Manager..."
        if [ -d "/app/custom_nodes/ComfyUI-DataManager" ]; then
            cp -r "/app/custom_nodes/ComfyUI-DataManager" "$CUSTOM_NODES_DIR/"
        fi
    fi
    
    # Sync additional custom nodes from S3 (admin only)
    if [ "$CONTAINER_ROLE" = "admin" ]; then
        echo "Admin: Syncing custom nodes from S3..."
        rclone sync "$S3_REMOTE:$S3_BUCKET_NAME/custom_nodes" "$CUSTOM_NODES_DIR" \
            --exclude "ComfyUI-Manager/**" --exclude "ComfyUI-DataManager/**" \
            || echo "Warning: Failed to sync custom nodes"
    fi
    
    echo "✓ Custom nodes setup completed"
}

# Install Python dependencies for custom nodes
install_custom_node_dependencies() {
    echo "=== Installing custom node dependencies ==="
    
    # Find and install requirements
    find "$CUSTOM_NODES_DIR" -name "requirements.txt" -type f | while read req_file; do
        echo "Installing requirements from: $req_file"
        pip install --no-cache-dir -r "$req_file" || echo "Warning: Failed to install from $req_file"
    done
    
    echo "✓ Custom node dependencies installed"
}

# Configure ComfyUI Manager based on role
configure_comfyui_manager() {
    local role=$1
    echo "=== Configuring ComfyUI Manager for $role ==="
    
    mkdir -p "/app/user/default"
    
    if [ "$role" = "admin" ]; then
        cat > "/app/user/default/manager_config.json" << EOF
{
    "security_level": "normal",
    "install_policy": "allow_all",
    "auto_install_deps": true,
    "show_install_buttons": true,
    "enable_cache_optimization": true
}
EOF
        echo "✓ Admin: Full ComfyUI Manager access enabled"
    else
        cat > "/app/user/default/manager_config.json" << EOF
{
    "security_level": "strict",
    "install_policy": "block_all",
    "auto_install_deps": false,
    "show_install_buttons": false,
    "enable_cache_optimization": true
}
EOF
        echo "✓ User: ComfyUI Manager in read-only mode"
    fi
}

# Start background sync for admin container
start_background_sync() {
    echo "=== Starting background sync for admin ==="
    
    (
        while true; do
            sleep 600  # Sync every 10 minutes
            echo "Background sync: Uploading changes to S3..."
            
            # Sync models to S3
            for dir in "${MODEL_DIRS[@]}"; do
                local models_path="$MODELS_DIR/$dir"
                local s3_path="$S3_REMOTE:$S3_BUCKET_NAME/models/$dir"
                
                if [ -d "$models_path" ]; then
                    rclone sync "$models_path" "$s3_path" --transfers 4 --checkers 8 || echo "Warning: Failed to sync $dir"
                fi
            done
            
            # Sync custom nodes to S3
            rclone sync "$CUSTOM_NODES_DIR" "$S3_REMOTE:$S3_BUCKET_NAME/custom_nodes" \
                --exclude "ComfyUI-Manager/**" --transfers 4 --checkers 8 || echo "Warning: Failed to sync custom nodes"
            
            echo "Background sync completed"
        done
    ) &
    
    SYNC_PID=$!
    echo "✓ Background sync started (PID: $SYNC_PID)"
}

# Preload popular models
preload_popular_models() {
    echo "=== Preloading popular models ==="
    
    if [ ${#POPULAR_MODELS[@]} -gt 0 ]; then
        python3 -c "
import asyncio
import sys
sys.path.append('/app/scripts')
from cache_manager import get_cache_manager

async def preload():
    manager = get_cache_manager()
    models = ['${POPULAR_MODELS[*]}']
    await manager.preload_models(models)

asyncio.run(preload())
" &
        PRELOAD_PID=$!
        echo "✓ Popular models preloading started (PID: $PRELOAD_PID)"
    else
        echo "No popular models configured for preloading"
    fi
}

# Setup monitoring and health checks
setup_monitoring() {
    echo "=== Setting up monitoring ==="
    
    # Create health check endpoint
    mkdir -p /app/monitoring
    
    cat > /app/monitoring/health.py << 'EOF'
#!/usr/bin/env python3
import json
import time
import psutil
from pathlib import Path

def get_health_status():
    """Get container health status"""
    try:
        # Check disk usage
        cache_usage = psutil.disk_usage('/tmp/model_cache')
        hot_cache_usage = psutil.disk_usage('/tmp/hot_cache')
        
        # Check memory usage
        memory = psutil.virtual_memory()
        
        # Check if ComfyUI is running
        comfyui_running = any('python' in p.name() and 'main.py' in ' '.join(p.cmdline()) 
                             for p in psutil.process_iter(['name', 'cmdline']))
        
        status = {
            'status': 'healthy' if comfyui_running else 'unhealthy',
            'timestamp': time.time(),
            'cache_usage_gb': cache_usage.used / 1024**3,
            'hot_cache_usage_gb': hot_cache_usage.used / 1024**3,
            'memory_usage_percent': memory.percent,
            'comfyui_running': comfyui_running
        }
        
        return status
    except Exception as e:
        return {'status': 'error', 'error': str(e)}

if __name__ == '__main__':
    print(json.dumps(get_health_status(), indent=2))
EOF
    
    chmod +x /app/monitoring/health.py
    echo "✓ Health monitoring configured"
}

# Graceful shutdown handler
setup_graceful_shutdown() {
    echo "=== Setting up graceful shutdown ==="
    
    cat > /app/shutdown.sh << 'EOF'
#!/bin/bash
echo "Graceful shutdown initiated..."

# Stop background processes
if [ ! -z "$SYNC_PID" ]; then
    kill $SYNC_PID 2>/dev/null || true
fi

if [ ! -z "$CACHE_MANAGER_PID" ]; then
    kill $CACHE_MANAGER_PID 2>/dev/null || true
fi

if [ ! -z "$PRELOAD_PID" ]; then
    kill $PRELOAD_PID 2>/dev/null || true
fi

# Save cache metadata
python3 -c "
import sys
sys.path.append('/app/scripts')
from cache_manager import get_cache_manager
manager = get_cache_manager()
manager.cleanup_cache()
"

echo "Graceful shutdown completed"
EOF
    
    chmod +x /app/shutdown.sh
    
    # Setup signal handlers
    trap '/app/shutdown.sh; exit 0' SIGTERM SIGINT
    
    echo "✓ Graceful shutdown configured"
}

# Main execution based on container role
case "${CONTAINER_ROLE:-user}" in
    "admin")
        echo "=== ADMIN MODE: AWS Golden Image Management ==="
        
        # Initialize systems
        setup_monitoring
        setup_graceful_shutdown
        init_cache_manager
        
        # Setup model and node paths
        setup_intelligent_model_paths
        setup_custom_nodes
        
        # Sync essential models only (for faster startup)
        sync_essential_models
        
        # Configure ComfyUI Manager for admin
        configure_comfyui_manager "admin"
        
        # Install dependencies
        install_custom_node_dependencies
        
        # Start background sync
        start_background_sync
        
        # Preload popular models in background
        preload_popular_models
        
        echo "✓ Admin container ready with intelligent caching"
        echo "✓ ComfyUI Manager: Available with full access"
        echo "✓ Data Manager: Available with full access"
        echo "✓ Cache Strategy: Intelligent S3 caching with ${CACHE_SIZE_GB}GB local cache"
        ;;
        
    "user")
        echo "=== USER MODE: AWS Golden Image Access ==="
        
        # Initialize systems
        setup_monitoring
        setup_graceful_shutdown
        init_cache_manager
        
        # Setup paths (no initial sync, use on-demand loading)
        setup_intelligent_model_paths
        setup_custom_nodes
        
        # Configure ComfyUI Manager for user (read-only)
        configure_comfyui_manager "user"
        
        # Preload popular models in background
        preload_popular_models
        
        echo "✓ User container ready with intelligent caching"
        echo "✓ ComfyUI Manager: Available in read-only mode"
        echo "✓ Data Manager: Available with browse/download access"
        echo "✓ Cache Strategy: On-demand S3 loading with ${CACHE_SIZE_GB}GB local cache"
        ;;
        
    *)
        echo "ERROR: Invalid CONTAINER_ROLE. Must be 'admin' or 'user'"
        exit 1
        ;;
esac

# Display system information
echo ""
echo "=== System Information ==="
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Cache Space: ${CACHE_SIZE_GB}GB"
echo "CPU Cores: $(nproc)"
echo "Disk Space: $(df -h /tmp | tail -1 | awk '{print $2}')"
echo ""

# Start ComfyUI
echo "=== Starting ComfyUI ==="
echo "🎉 ComfyUI AWS Golden Image ready!"
echo "📊 Monitoring endpoint: /app/monitoring/health.py"
echo ""

# Start ComfyUI with optimized settings
exec python3 /app/main.py \
    --listen 0.0.0.0 \
    --port 8190 \
    --extra-model-paths-config /app/extra_model_paths.yaml \
    --cpu 