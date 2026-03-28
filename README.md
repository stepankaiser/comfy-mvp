# ComfyUI Golden Image System

**Multi-user Docker infrastructure for ComfyUI with centralized model management and S3 persistence.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](docker-compose.yml)
[![Python 3.11](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)](Dockerfile)

A production-ready system that uses the **golden image** pattern: an admin maintains a single, centralized ComfyUI environment (models, custom nodes, Python dependencies), while any number of users get instant read-only access to that environment through Docker volume mounts. AWS S3 serves as the durable storage backend, with rclone handling background synchronization.

---

## Features

- **Admin Role** -- Full write access to install models, custom nodes, and Python packages.
- **User Role** -- Read-only access to the shared environment; users generate images without managing infrastructure.
- **Centralized Storage** -- One set of models and nodes shared across all containers. No duplication.
- **S3 Persistence** -- rclone syncs the golden image to S3 on a schedule, so nothing is lost when containers restart.
- **Zero-Setup Users** -- New users get a fully configured ComfyUI instance immediately.
- **Horizontal Scaling** -- Add more user containers with a few lines of Compose config.

---

## Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   Admin User    │    │  Regular User   │
│                 │    │                 │
│  Install        │    │  Read-only      │
│  Upload         │    │  Use models     │
│  Manage         │    │  Generate       │
└─────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────┐
│         Shared Golden Image             │
│                                         │
│  Models (checkpoints, LoRAs, VAE)       │
│  Custom Nodes                           │
│  Python Dependencies                    │
│  System Libraries                       │
└─────────────────────────────────────────┘
                    │
                    ▼
          ┌─────────────────┐
          │   AWS S3        │
          │  (Persistence)  │
          └─────────────────┘
```

The admin container mounts shared Docker volumes with **read-write** access. User containers mount the same volumes as **read-only**. A background rclone process in the admin container syncs changes to S3 every 5 minutes, and pulls the latest state from S3 on startup.

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/stepankaiser/comfy-mvp.git
cd comfy-mvp
```

### 2. Configure environment

```bash
cp env.example .env
```

Edit `.env` and fill in your AWS credentials:

```bash
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=eu-central-1
S3_BUCKET_NAME=your-comfyui-bucket
S3_ENDPOINT=https://s3.eu-central-1.amazonaws.com
```

### 3. Start the system

```bash
docker-compose up -d
```

### 4. Access the interfaces

| Role  | ComfyUI              | Manager                           |
|-------|----------------------|-----------------------------------|
| Admin | http://localhost:8190 | http://localhost:8190/manager      |
| User  | http://localhost:8191 | http://localhost:8191/manager (RO) |

---

## Admin Workflow

1. Open the admin interface at port **8190**.
2. **Install models** -- upload checkpoints, LoRAs, or VAE files through the ComfyUI interface. They are saved to the shared volume automatically.
3. **Install custom nodes** -- use ComfyUI Manager at `/manager` to browse and install nodes from the catalog. Python dependencies are installed alongside them.
4. **S3 sync** -- a background process uploads changes to S3 every 5 minutes. To trigger a manual sync:
   ```bash
   docker-compose exec admin_comfyui rclone sync /app/models s3-storage:$S3_BUCKET_NAME/models
   ```
5. **Restart** the admin container after major changes (new nodes that require a process restart):
   ```bash
   docker-compose restart admin_comfyui
   ```

---

## User Experience

Users open port **8191** and see a fully functional ComfyUI instance:

- All admin-installed models appear in the model dropdowns.
- All custom nodes are available and functional.
- The standard ComfyUI workflow editor works normally.
- Generated images are saved to a per-user output directory.

Install and delete buttons in ComfyUI Manager are disabled -- users cannot modify the shared environment.

---

## Volume Structure

```
Shared (golden image)          Per-user
─────────────────────          ────────────────
shared_models/                 user_cache/
  checkpoints/                 user_config/
  loras/                       user_output/
  vae/
  controlnet/
  embeddings/
  upscale_models/

shared_custom_nodes/
  ComfyUI-Manager/
  ...

shared_python/
  (site-packages from nodes)

shared_libs/
  (system libraries)
```

On S3, the layout mirrors the shared volumes:

```
s3://your-bucket/
├── models/
│   ├── checkpoints/
│   ├── loras/
│   └── ...
└── custom_nodes/
    └── ...
```

---

## Scaling

To add another user, append a new service to `docker-compose.yml`:

```yaml
user2_comfyui:
  build: .
  container_name: user2_comfyui
  ports:
    - "8192:8190"
  environment:
    - CONTAINER_ROLE=user
  volumes:
    - shared_models:/app/models:ro
    - shared_custom_nodes:/app/custom_nodes:ro
    - shared_python:/app/shared_python:ro
    - shared_libs:/app/shared_libs:ro
    - user2_cache:/app/cache
    - user2_config:/app/user
    - user2_output:/app/output
```

Remember to declare the new per-user volumes in the top-level `volumes:` block.

For larger deployments, consider Kubernetes with a shared PersistentVolumeClaim and per-pod output volumes.

---

## Security

- **IAM scoping** -- create a dedicated IAM user with permissions limited to the single S3 bucket used by this system.
- **Read-only mounts** -- user containers cannot write to model or node volumes.
- **Container isolation** -- each user has isolated cache, config, and output volumes.
- **Manager lockdown** -- the `COMFYUI_DISABLE_MANAGER_INSTALL` flag prevents users from installing packages.
- **No privileged access** -- only the admin container requires `SYS_ADMIN` / FUSE capabilities (for rclone mount); user containers do not.

---

## License

This project is licensed under the [MIT License](LICENSE).
