# ComfyUI Golden Image System

Kompletní multi-user systém pro ComfyUI s centralizovaným správou modelů, custom nodes a závislostí.

## 🎯 Funkce

- **Admin Role**: Plný write přístup - instalace modelů, custom nodes, dependencies
- **User Role**: Read-only přístup ke sdílenému prostředí
- **Centralizované úložiště**: S3 jako single source of truth
- **Sdílené prostředí**: Modely, custom nodes, Python balíčky
- **Transparentní integrace**: ComfyUI funguje jako s lokálními soubory

## 🏗️ Architektura

```
┌─────────────────┐    ┌─────────────────┐
│   Admin User    │    │  Regular User   │
│                 │    │                 │
│ ✅ Install      │    │ 👁️ Read-only    │
│ ✅ Upload       │    │ 👁️ Use models   │
│ ✅ Manage       │    │ 👁️ Generate     │
└─────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────┐
│         Shared Golden Image             │
│                                         │
│ 📁 Models (checkpoints, loras, vae)     │
│ 🔧 Custom Nodes                         │
│ 🐍 Python Dependencies                  │
│ 📚 System Libraries                     │
└─────────────────────────────────────────┘
                    │
                    ▼
          ┌─────────────────┐
          │   S3 Storage    │
          │ (Persistence)   │
          └─────────────────┘
```

## 🚀 Spuštění

### 1. Nastavení prostředí

Vytvořte `.env` soubor:

```bash
# AWS S3 Configuration
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=eu-central-1
S3_BUCKET_NAME=your-comfyui-bucket
S3_ENDPOINT=https://s3.eu-central-1.amazonaws.com
```

### 2. Spuštění systému

```bash
# Spustit celý systém
docker-compose up -d

# Sledovat logy
docker-compose logs -f admin_comfyui
docker-compose logs -f user_comfyui
```

### 3. Přístup k rozhraní

- **Admin ComfyUI**: http://localhost:8190
- **Admin Manager**: http://localhost:8190/manager (full access)
- **Admin Data Manager**: http://localhost:8190/data-manager (file management)
- **User ComfyUI**: http://localhost:8191
- **User Manager**: http://localhost:8191/manager (read-only)
- **User Data Manager**: http://localhost:8191/data-manager (browse files)

## 👑 Admin Workflow

### Instalace modelů

**Metoda 1: Přes Data Manager (doporučeno)**
1. Otevřete Data Manager: http://localhost:8190/data-manager
2. Přetáhněte modely do drop zone nebo klikněte pro výběr
3. Vyberte cílovou složku (checkpoints, loras, vae, atd.)
4. Modely se automaticky nahrají a seřadí

**Metoda 2: Přes ComfyUI interface**
1. Otevřete admin rozhraní (port 8190)
2. Nahrajte modely přes ComfyUI interface
3. Modely se automaticky uloží do shared volume
4. Background sync je nahraje do S3 (každých 5 minut)

### Instalace custom nodes
1. Otevřete ComfyUI Manager: http://localhost:8190/manager
2. Klikněte "Install Custom Nodes"
3. Vyberte požadované nodes z katalogu
4. Systém automaticky:
   - Nainstaluje node do shared volume
   - Nainstaluje Python dependencies
   - Synchronizuje do S3
5. Restart admin kontejneru pro aktivaci nových nodes

### Správa prostředí
```bash
# Restart admin kontejneru (po větších změnách)
docker-compose restart admin_comfyui

# Manuální sync do S3
docker-compose exec admin_comfyui rclone sync /app/shared_models s3-storage:your-bucket/models
```

## 👤 User Experience

### Co uživatel vidí
- ✅ Všechny modely nainstalované adminem
- ✅ Všechny custom nodes funkční
- ✅ Plně funkční ComfyUI interface
- ❌ Zakázané install tlačítka (read-only)

### Workflow pro uživatele
1. Otevřete user rozhraní (port 8191)
2. Vyberte model z dropdown (všechny admin modely dostupné)
3. Použijte custom nodes (všechny admin nodes funkční)
4. Generujte obrázky normálně
5. Obrázky se ukládají do uživatelského output adresáře

## 🗂️ Data Manager

### Funkce
- **📁 Procházení adresářů**: Vizuální prohlížeč všech ComfyUI složek
- **🖱️ Drag & Drop**: Jednoduché nahrávání souborů přetažením
- **🗑️ Správa souborů**: Mazání souborů a složek s potvrzením
- **🔄 Real-time aktualizace**: Automatické obnovení po operacích
- **📊 Progress tracking**: Vizuální indikátory průběhu nahrávání

### Přístup k Data Manageru
- **Tlačítko v menu**: Klikněte "🗂️ Data Manager" v ComfyUI menu
- **Klávesová zkratka**: Stiskněte `Ctrl+D` pro toggle widget
- **Přímý URL**: Navštivte `/data-manager` endpoint
- **Plovoucí widget**: Přetahovatelný panel v pravém horním rohu

### Podporované adresáře
- **🎯 Models**: Všechny typy modelů (checkpoints, LoRA, VAE, atd.)
- **🔧 Custom Nodes**: Rozšíření a custom funkce
- **📥 Input**: Vstupní soubory pro workflows
- **📤 Output**: Vygenerované obrázky a výsledky

## 🔧 Pokročilé funkce

### Struktura shared volumes
```
shared_models/
├── checkpoints/     # Hlavní modely
├── loras/          # LoRA modely
├── vae/            # VAE modely
├── controlnet/     # ControlNet modely
├── embeddings/     # Textual Inversion
└── upscale_models/ # Upscale modely

shared_custom_nodes/
├── ComfyUI-Manager/
├── ComfyUI-Custom-Scripts/
└── [další custom nodes]

shared_python/
├── [Python balíčky z custom nodes]
└── [site-packages]
```

### S3 struktura
```
s3://your-bucket/
├── models/
│   ├── checkpoints/
│   ├── loras/
│   └── [další model typy]
└── custom_nodes/
    ├── ComfyUI-Manager/
    └── [další nodes]
```

### Monitoring a debugging
```bash
# Sledovat sync aktivity
docker-compose logs -f admin_comfyui | grep "sync"

# Zkontrolovat shared volumes
docker-compose exec admin_comfyui ls -la /app/shared_models/checkpoints/

# Ověřit Python dependencies
docker-compose exec admin_comfyui ls -la /app/shared_python/
```

## 🛠️ Troubleshooting

### Modely se nezobrazují
```bash
# Zkontrolovat model paths
docker-compose exec admin_comfyui cat /app/extra_model_paths.yaml

# Ověřit symlinky
docker-compose exec admin_comfyui ls -la /app/models
```

### Custom nodes nefungují
```bash
# Zkontrolovat custom nodes
docker-compose exec admin_comfyui ls -la /app/custom_nodes/

# Zkontrolovat Python path
docker-compose exec admin_comfyui echo $PYTHONPATH
```

### S3 sync problémy
```bash
# Test S3 připojení
docker-compose exec admin_comfyui rclone ls s3-storage:your-bucket

# Manuální sync
docker-compose exec admin_comfyui rclone sync /app/shared_models s3-storage:your-bucket/models --dry-run
```

## 📈 Scaling

### Přidání dalších uživatelů
```yaml
# V docker-compose.yml
user2_comfyui:
  build: .
  container_name: user2_comfyui
  ports:
    - "8192:8190"
  environment:
    - CONTAINER_ROLE=user
  volumes:
    - shared_models:/app/shared_models:ro
    - shared_custom_nodes:/app/shared_custom_nodes:ro
    - shared_python:/app/shared_python:ro
    - user2_cache:/app/cache
    - user2_config:/app/user
    - user2_output:/app/output
```

### Production deployment
- Použijte externí S3 bucket s proper IAM policies
- Nastavte resource limits pro kontejnery
- Implementujte proper logging a monitoring
- Zvažte použití Kubernetes pro scaling

## 🔐 Security

### IAM Permissions (S3)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket",
        "arn:aws:s3:::your-bucket/*"
      ]
    }
  ]
}
```

### Container Security
- User kontejnery nemají privilegované přístupy
- Read-only mount pro shared volumes
- Izolované user-specific volumes

## 🎉 Výhody tohoto řešení

1. **Unified Golden Image**: Admin vytvoří kompletní prostředí jednou
2. **Zero Setup Users**: Uživatelé mají okamžitě vše dostupné
3. **Centralized Management**: Vše se spravuje z jednoho místa
4. **Cost Effective**: Sdílené modely = úspora místa
5. **Transparent**: ComfyUI funguje normálně pro všechny
6. **Scalable**: Snadné přidávání dalších uživatelů
7. **Persistent**: S3 jako backup pro celé prostředí 