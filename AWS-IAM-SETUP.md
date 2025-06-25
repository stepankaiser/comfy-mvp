# 🔐 AWS IAM Setup Guide for ComfyUI Deployment

**Ne, nepotřebujete plná admin práva!** Zde je guide pro nastavení **minimální required permissions**.

## 🎯 **Tři možnosti nastavení:**

### **Option 1: Programmatic User (Doporučeno pro CI/CD)**
Pro GitHub Actions nebo automated deployment.

### **Option 2: IAM Role (Doporučeno pro EC2/local development)**
Pro deployment z EC2 instance nebo s AssumeRole.

### **Option 3: Temporary Admin (Nejjednodušší pro testing)**
Rychlé nastavení pro testing, později omezit.

---

## 🔧 **Option 1: Programmatic User Setup**

### **Krok 1: Vytvořte IAM User**
```bash
# V AWS Console:
# IAM → Users → Create User
# User name: comfyui-deployment-user
# Access type: Programmatic access (ne Console access)
```

### **Krok 2: Vytvořte Custom Policy**
```bash
# IAM → Policies → Create Policy
# JSON tab → vložte obsah z aws-iam-policy.json
# Name: ComfyUIDeploymentPolicy
# Description: Minimal permissions for ComfyUI AWS deployment
```

### **Krok 3: Připojte Policy k User**
```bash
# IAM → Users → comfyui-deployment-user
# Permissions tab → Add permissions → Attach existing policies
# Vyberte: ComfyUIDeploymentPolicy
```

### **Krok 4: Získejte Access Keys**
```bash
# IAM → Users → comfyui-deployment-user
# Security credentials tab → Create access key
# Use case: Command Line Interface (CLI)
# Uložte si: Access Key ID a Secret Access Key
```

---

## 🎭 **Option 2: IAM Role Setup**

### **Pro EC2 Instance nebo AssumeRole:**
```bash
# 1. Vytvořte IAM Role
# IAM → Roles → Create Role
# Trusted entity: AWS service → EC2

# 2. Připojte stejnou policy (ComfyUIDeploymentPolicy)

# 3. Pro AssumeRole přidejte trust relationship:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::YOUR-ACCOUNT:user/your-username"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

---

## ⚡ **Option 3: Temporary Admin (Pro rychlé testing)**

```bash
# POUZE PRO TESTING! V produkci použijte Option 1 nebo 2

# 1. Vytvořte IAM User
# 2. Připojte managed policy: AdministratorAccess
# 3. Po úspěšném deployment nahraďte za minimální permissions
```

---

## 🔍 **Co obsahuje minimální policy:**

### **✅ Povolené služby:**
- **VPC & Networking** - Vytvoření sítí, subnets, security groups
- **ECS** - Container orchestration a task definitions
- **EC2** - GPU instances a auto-scaling groups
- **ALB** - Load balancer pro traffic routing
- **S3** - Model storage a Terraform state
- **ECR** - Docker image registry
- **IAM** - Role creation (pouze pro comfyui-* resources)
- **CloudWatch** - Logging a monitoring
- **DynamoDB** - Terraform state locking

### **❌ NEPOVOLUJE:**
- ❌ Přístup k jiným AWS účtům
- ❌ Modifikace root účtu
- ❌ Přístup k billing informacím
- ❌ Vytváření users nebo groups
- ❌ Přístup k jiným aplikacím/resources

---

## 🛡️ **Security Best Practices:**

### **1. Resource Restrictions**
```json
// Policy je omezena na comfyui-* resources
"Resource": [
  "arn:aws:s3:::comfyui-*",
  "arn:aws:iam::*:role/comfyui-*"
]
```

### **2. Principle of Least Privilege**
- Pouze permissions potřebné pro deployment
- Žádné wildcard permissions kromě read-only operací
- Časově omezené access keys (rotace každé 3 měsíce)

### **3. Monitoring**
```bash
# Sledujte API calls v CloudTrail
# Nastavte billing alerts
# Používejte AWS Config pro compliance
```

---

## 🚀 **Testing Permissions**

### **Před deployment otestujte:**
```bash
# Test základního přístupu
aws sts get-caller-identity

# Test S3 permissions
aws s3 ls

# Test ECS permissions
aws ecs list-clusters

# Test EC2 permissions
aws ec2 describe-vpcs
```

### **Pokud dostanete chyby:**
```bash
# Common errors a řešení:

# AccessDenied na IAM
# → Zkontrolujte IAM permissions v policy

# UnauthorizedOperation na EC2
# → Zkontrolujte EC2 permissions pro váš region

# InvalidUserID.NotFound
# → Zkontrolujte ARN v resource restrictions
```

---

## 📋 **Quick Setup Checklist**

- [ ] ✅ Vytvořen IAM User/Role
- [ ] ✅ Připojena ComfyUIDeploymentPolicy
- [ ] ✅ Získány Access Keys (pro User)
- [ ] ✅ Nakonfigurován AWS CLI (`aws configure`)
- [ ] ✅ Otestován přístup (`aws sts get-caller-identity`)
- [ ] ✅ Připraveny GitHub Secrets (pokud používáte Actions)

---

## 🔄 **GitHub Secrets Setup**

Po vytvoření IAM User nastavte tyto secrets:

```bash
# V GitHub repo → Settings → Secrets and variables → Actions

AWS_ACCESS_KEY_ID: AKIA...
AWS_SECRET_ACCESS_KEY: xyz...

# Po spuštění setup-terraform-backend.sh přidejte:
TERRAFORM_STATE_BUCKET: comfyui-golden-image-terraform-state-xxxxx
TERRAFORM_LOCK_TABLE: comfyui-golden-image-terraform-locks
```

---

## 💡 **Pro Corporate/Enterprise účty:**

```bash
# Pokud máte organization policies:
# 1. Požádejte AWS admin o vytvoření custom policy
# 2. Použijte aws-iam-policy.json jako template
# 3. Možná budete potřebovat dodatečné permissions pro:
#    - Service Control Policies (SCPs)
#    - Resource Access Manager (RAM)
#    - AWS Config compliance
```

---

## ✅ **Shrnutí:**

**Minimální permissions stačí!** Policy obsahuje pouze to, co je potřeba pro:
- 🏗️ Vytvoření infrastruktury
- 🐋 Deploy kontejnerů
- 📊 Monitoring a logging
- 🔒 Bezpečné resource management

**Deployment bude fungovat bez admin práv** s touto custom policy! 🎉 