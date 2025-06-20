# Golden Image ComfyUI - Multi-User System
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    build-essential \
    fuse3 \
    netcat-openbsd \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Install rclone for S3 operations
RUN curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip \
    && unzip rclone-current-linux-amd64.zip \
    && cd rclone-*-linux-amd64 \
    && cp rclone /usr/local/bin/ \
    && chmod +x /usr/local/bin/rclone \
    && cd .. \
    && rm -rf rclone-*

# Clone and setup ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git .

# Fix numpy/scipy compatibility issues
RUN pip install --no-cache-dir "numpy<2.0" "scipy<1.13"

# Install base ComfyUI requirements
RUN pip install --no-cache-dir -r requirements.txt

# Install ComfyUI Manager (for admin interface)
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git ./custom_nodes/ComfyUI-Manager

# Copy Data Manager custom node
COPY custom_nodes/ComfyUI-DataManager ./custom_nodes/ComfyUI-DataManager

# Install Data Manager dependencies
RUN pip install --no-cache-dir -r ./custom_nodes/ComfyUI-DataManager/requirements.txt

# Backup ComfyUI Manager and Data Manager before volume mount overwrites them
RUN cp -r ./custom_nodes/ComfyUI-Manager /tmp/ComfyUI-Manager-backup \
    && cp -r ./custom_nodes/ComfyUI-DataManager /tmp/ComfyUI-DataManager-backup

# Create directories for Golden Image pattern
RUN mkdir -p /app/shared_python \
    /app/shared_libs \
    /app/cache \
    /app/user

# Copy and set permissions for entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ComfyUI port
EXPOSE 8190

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"] 