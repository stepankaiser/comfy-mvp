#!/bin/bash
set -e

# Golden Image Pattern Entrypoint for ComfyUI Multi-User System
# Supports both admin (write) and user (read-only) roles

echo "=== ComfyUI Golden Image System ==="
echo "Container Role: ${CONTAINER_ROLE:-user}"

# Validate required environment variables
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "ERROR: AWS credentials must be set as environment variables."
  exit 1
fi

# Configuration
S3_REMOTE="s3-storage"
MODELS_DIR="/app/models"                    # Direct mount to shared volume
CUSTOM_NODES_DIR="/app/custom_nodes"        # Direct mount to shared volume
SHARED_PYTHON_DIR="/app/shared_python"
SHARED_LIBS_DIR="/app/shared_libs"
CACHE_DIR="/app/cache"

# Create necessary directories
mkdir -p "$CACHE_DIR"
mkdir -p "$SHARED_PYTHON_DIR"
mkdir -p "$SHARED_LIBS_DIR"

# Configure rclone for S3 access
echo "Configuring rclone for S3..."
rclone config create "$S3_REMOTE" s3 \
    provider=AWS \
    env_auth=true \
    region="$AWS_REGION" \
    endpoint="$S3_ENDPOINT"

# Model directories to sync
MODEL_DIRS=(
    "checkpoints" "clip" "clip_vision" "configs" "controlnet" "diffusers"
    "embeddings" "gligen" "hypernetworks" "loras" "photomaker" 
    "style_models" "t2i-adapter" "unet" "upscale_models" "vae" "vae_approx"
)

# Sync models from S3 to models directory (admin only)
sync_models_from_s3() {
    echo "=== Syncing models from S3 to models directory ==="
    for dir in "${MODEL_DIRS[@]}"; do
        local models_path="$MODELS_DIR/$dir"
        local s3_path="$S3_REMOTE:$S3_BUCKET_NAME/models/$dir"
        
        echo "Syncing $dir..."
        mkdir -p "$models_path"
        
        # Only admin syncs from S3, user uses shared volume directly
        if [ "$CONTAINER_ROLE" = "admin" ]; then
            rclone sync "$s3_path" "$models_path" --progress --transfers 4 --checkers 8 || echo "Warning: Failed to sync $dir"
            echo "✓ Synced $dir: $(find "$models_path" -type f 2>/dev/null | wc -l) files"
        fi
    done
}

# Sync custom nodes from S3 to custom_nodes directory (admin only)
sync_custom_nodes_from_s3() {
    echo "=== Syncing custom nodes from S3 to custom_nodes directory ==="
    local s3_path="$S3_REMOTE:$S3_BUCKET_NAME/custom_nodes"
    
    echo "Syncing custom nodes..."
    # Only admin syncs from S3, user uses shared volume directly
    if [ "$CONTAINER_ROLE" = "admin" ]; then
        rclone sync "$s3_path" "$CUSTOM_NODES_DIR" --progress --transfers 4 --checkers 8 || echo "Warning: Failed to sync custom nodes"
        echo "✓ Synced custom nodes: $(find "$CUSTOM_NODES_DIR" -type d -name "ComfyUI*" 2>/dev/null | wc -l) nodes"
    fi
}

# Sync models back to S3 (admin only)
sync_models_to_s3() {
    echo "=== Syncing models from models directory to S3 ==="
    for dir in "${MODEL_DIRS[@]}"; do
        local models_path="$MODELS_DIR/$dir"
        local s3_path="$S3_REMOTE:$S3_BUCKET_NAME/models/$dir"
        
        if [ -d "$models_path" ]; then
            echo "Uploading $dir..."
            rclone sync "$models_path" "$s3_path" --progress --transfers 4 --checkers 8
            echo "✓ Uploaded $dir"
        fi
    done
}

# Sync custom nodes back to S3 (admin only)
sync_custom_nodes_to_s3() {
    echo "=== Syncing custom nodes from custom_nodes directory to S3 ==="
    local s3_path="$S3_REMOTE:$S3_BUCKET_NAME/custom_nodes"
    
    if [ -d "$CUSTOM_NODES_DIR" ]; then
        echo "Uploading custom nodes..."
        rclone sync "$CUSTOM_NODES_DIR" "$s3_path" --progress --transfers 4 --checkers 8
        echo "✓ Uploaded custom nodes"
    fi
}

# Setup model paths - Direct mount, no extra config needed
setup_model_paths() {
    echo "=== Setting up model paths ==="
    
    # With direct mount to /app/models, no extra configuration needed
    # ComfyUI will use standard paths which are now shared volumes
    
    echo "✓ Models directory directly mounted to shared volume"
    echo "✓ Models path: /app/models (shared volume)"
}

# Setup custom nodes - Direct mount, ensure ComfyUI Manager exists
setup_custom_nodes() {
    echo "=== Setting up custom nodes ==="
    
    # With direct mount to /app/custom_nodes, just ensure ComfyUI Manager and Data Manager exist
    if [ ! -d "/app/custom_nodes/ComfyUI-Manager" ]; then
        echo "ComfyUI Manager not found in shared volume, copying from container..."
        # If we have a local copy, copy it to the shared volume
        if [ -d "/tmp/ComfyUI-Manager-backup" ]; then
            cp -r "/tmp/ComfyUI-Manager-backup" "/app/custom_nodes/ComfyUI-Manager"
        else
            echo "Warning: ComfyUI Manager not available"
        fi
    fi
    
    # Ensure Data Manager exists (only for admin with write access)
    if [ ! -d "/app/custom_nodes/ComfyUI-DataManager" ]; then
        echo "🗂️ Data Manager not found in shared volume..."
        if [ "$CONTAINER_ROLE" = "admin" ] && [ -d "/tmp/ComfyUI-DataManager-backup" ]; then
            echo "Admin: Copying Data Manager from container backup..."
            cp -r "/tmp/ComfyUI-DataManager-backup" "/app/custom_nodes/ComfyUI-DataManager"
        elif [ "$CONTAINER_ROLE" = "user" ]; then
            echo "User: Data Manager will be available once admin initializes it"
        else
            echo "Warning: Data Manager not available"
        fi
    else
        echo "✓ Data Manager found in shared volume"
    fi
    
    echo "✓ Custom nodes directory directly mounted to shared volume"
    echo "✓ Custom nodes path: /app/custom_nodes (shared volume)"
    echo "✓ ComfyUI Manager available at: http://localhost:819X/manager"
}

# Install Python dependencies for custom nodes (admin only)
install_custom_node_dependencies() {
    echo "=== Installing custom node dependencies ==="
    
    # Find all requirements.txt files in custom nodes
    find "$CUSTOM_NODES_DIR" -name "requirements.txt" -type f | while read req_file; do
        echo "Installing requirements from: $req_file"
        pip install --target="$SHARED_PYTHON_DIR" -r "$req_file" || echo "Warning: Failed to install from $req_file"
    done
    
    echo "✓ Custom node dependencies installed to shared Python directory"
}

# Configure ComfyUI Manager settings
configure_comfyui_manager() {
    local role=$1
    echo "=== Configuring ComfyUI Manager for $role ==="
    
    # Create manager config directory
    mkdir -p "/app/user/default"
    
    if [ "$role" = "admin" ]; then
        # Admin: Full access to ComfyUI Manager
        cat > "/app/user/default/manager_config.json" << EOF
{
    "security_level": "normal",
    "install_policy": "allow_all",
    "auto_install_deps": true,
    "show_install_buttons": true
}
EOF
        echo "✓ Admin: Full ComfyUI Manager access enabled"
    else
        # User: Read-only mode
        cat > "/app/user/default/manager_config.json" << EOF
{
    "security_level": "strict",
    "install_policy": "block_all",
    "auto_install_deps": false,
    "show_install_buttons": false
}
EOF
        echo "✓ User: ComfyUI Manager in read-only mode"
    fi
}

# Background sync for admin container
start_background_sync() {
    echo "=== Starting background sync for admin ==="
    (
        while true; do
            sleep 300  # Sync every 5 minutes
            echo "Background sync: Uploading changes to S3..."
            sync_models_to_s3
            sync_custom_nodes_to_s3
            echo "Background sync completed"
        done
    ) &
    echo "✓ Background sync started"
}

# Main execution based on container role
case "${CONTAINER_ROLE:-user}" in
    "admin")
        echo "=== ADMIN MODE: Full Golden Image Management ==="
        
        # Initial sync from S3
        sync_models_from_s3
        sync_custom_nodes_from_s3
        
        # Setup paths and links
        setup_model_paths
        setup_custom_nodes
        
        # Configure ComfyUI Manager for admin
        configure_comfyui_manager "admin"
        
        # Install dependencies for custom nodes
        install_custom_node_dependencies
        
        # Start background sync to S3
        start_background_sync
        
        echo "✓ Admin container ready - Full access to install models and custom nodes"
        echo "✓ ComfyUI Manager: http://localhost:8190/manager"
        echo "✓ Data Manager: http://localhost:8190/data-manager"
        ;;
        
    "user")
        echo "=== USER MODE: Read-only Golden Image Access ==="
        
        # Skip S3 sync for user mode - use shared volumes directly
        echo "Skipping S3 sync - using shared volumes from admin container"
        echo "Models directory: /app/models (shared volume, read-only)"
        echo "Custom nodes directory: /app/custom_nodes (shared volume, read-only)"
        
        # Setup paths (no sync needed, direct mount)
        setup_model_paths
        setup_custom_nodes
        
        # Configure ComfyUI Manager for user (read-only)
        configure_comfyui_manager "user"
        
        echo "✓ User container ready - Read-only access to Golden Image"
        echo "✓ ComfyUI Manager: http://localhost:8191/manager (read-only)"
        echo "✓ Data Manager: http://localhost:8191/data-manager"
        ;;
        
    *)
        echo "ERROR: Invalid CONTAINER_ROLE. Must be 'admin' or 'user'"
        exit 1
        ;;
esac

# Start ComfyUI
echo "=== Starting ComfyUI ==="
echo "Models available in shared volume: $(find "$SHARED_MODELS_DIR" -name "*.safetensors" -o -name "*.ckpt" -o -name "*.pth" 2>/dev/null | wc -l) files"
echo "Custom nodes available: $(find "$SHARED_CUSTOM_NODES_DIR" -maxdepth 1 -type d 2>/dev/null | wc -l) directories"
echo ""
echo "🎉 ComfyUI ready with ComfyUI Manager!"
echo "📱 Access ComfyUI Manager via the web interface or direct URL"

exec python3 /app/main.py --listen 0.0.0.0 --port 8190 --cpu 