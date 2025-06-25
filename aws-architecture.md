# AWS Production Architecture for ComfyUI Golden Image System

## 🎯 **Architektura Overview**

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   CloudFront    │────│  Application     │────│    ECS Fargate      │
│   (CDN/Cache)   │    │  Load Balancer   │    │   Auto Scaling      │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
                                │                         │
                                │                         │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│      S3         │    │   ElastiCache    │    │  Local NVMe SSD     │
│ (Golden Image)  │    │   (Hot Cache)    │    │  (Working Cache)    │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
         │                       │                         │
         └───────────────────────┼─────────────────────────┘
                                 │
                    ┌──────────────────┐
                    │      RDS         │
                    │   (Metadata)     │
                    └──────────────────┘
```

## 🏗️ **Klíčové komponenty**

### **1. ECS Fargate s optimalizovaným storage**
```yaml
# Fargate task definition
Resources:
  ComfyUITaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Properties:
      Family: comfyui-golden-image
      NetworkMode: awsvpc
      RequiresCompatibilities:
        - FARGATE
      Cpu: 4096          # 4 vCPU
      Memory: 16384      # 16 GB RAM
      EphemeralStorage:
        SizeInGiB: 200   # 200GB NVMe SSD pro cache
      ContainerDefinitions:
        - Name: comfyui-admin
          Image: !Sub ${AWS::AccountId}.dkr.ecr.${AWS::Region}.amazonaws.com/comfyui:latest
          Environment:
            - Name: CONTAINER_ROLE
              Value: admin
            - Name: S3_BUCKET
              Value: !Ref ModelsBucket
            - Name: CACHE_STRATEGY
              Value: intelligent
```

### **2. Inteligentní S3 + Local Cache strategie**
```bash
# Optimalizovaná cache strategie
CACHE_LEVELS:
  1. Local NVMe SSD (200GB) - Aktivní modely
  2. ElastiCache Redis - Metadata + malé soubory  
  3. S3 Intelligent Tiering - Kompletní Golden Image
  4. S3 Glacier - Archivní modely
```

### **3. Performance optimalizace**
- **Předem načtené modely**: Nejpoužívanější modely v local cache
- **Lazy loading**: Modely se stahují jen když jsou potřeba
- **Parallel downloads**: Více souborů současně z S3
- **Compression**: Modely komprimované v S3, dekomprese do local cache

## 🚀 **Deployment strategie**

### **Option A: Pure S3 s optimalizací (Doporučeno)**
```yaml
# Výhody:
✅ Nejnižší náklady
✅ Neomezená kapacita
✅ Automatické backupy
✅ Multi-region replikace
✅ Intelligent tiering

# Optimalizace:
- S3 Transfer Acceleration
- CloudFront pro statické assety
- Předem načtené "hot" modely
- Intelligent caching layer
```

### **Option B: Hybrid S3 + EBS**
```yaml
# Pro extra performance
- EBS GP3 volumes (1000 IOPS baseline)
- S3 jako backup + sync
- Dražší ale rychlejší
```

### **Option C: S3 + Instance Store**
```yaml
# Nejrychlejší option
- Instance Store NVMe (až 3.3M IOPS)
- S3 jako persistence layer
- Nejvyšší náklady
```

## 💡 **Doporučené řešení: Enhanced S3 Strategy**

### **Inteligentní cache management**
```python
# Pseudokód pro cache strategii
class ModelCacheManager:
    def __init__(self):
        self.local_cache = "/tmp/models"  # NVMe SSD
        self.s3_bucket = "comfyui-models"
        self.redis_cache = ElastiCacheRedis()
        
    async def get_model(self, model_path):
        # 1. Check local cache first
        if self.local_cache_has(model_path):
            return self.load_from_local(model_path)
            
        # 2. Check if downloading
        if self.is_downloading(model_path):
            await self.wait_for_download(model_path)
            return self.load_from_local(model_path)
            
        # 3. Start background download from S3
        asyncio.create_task(self.download_from_s3(model_path))
        
        # 4. Stream directly from S3 for immediate use
        return self.stream_from_s3(model_path)
        
    def cache_eviction_policy(self):
        # LRU + size-based eviction
        # Keep 80% of cache for hot models
        # 20% for new downloads
```

### **Auto-scaling konfigurace**
```yaml
AutoScalingGroup:
  MinSize: 1
  MaxSize: 10
  DesiredCapacity: 2
  TargetGroupARNs:
    - !Ref ComfyUITargetGroup
  
  # Scaling policies
  ScaleUpPolicy:
    MetricName: CPUUtilization
    Threshold: 70
    ScalingAdjustment: 2
    
  ScaleDownPolicy:
    MetricName: CPUUtilization  
    Threshold: 30
    ScalingAdjustment: -1
    
  # Custom metrics
  CustomMetrics:
    - ModelLoadTime
    - ActiveUsers
    - QueueLength
```

## 💰 **Cost Optimization**

### **S3 Storage Classes**
```yaml
S3Lifecycle:
  Rules:
    - Id: ModelLifecycle
      Status: Enabled
      Transitions:
        - Days: 30
          StorageClass: STANDARD_IA
        - Days: 90  
          StorageClass: GLACIER
        - Days: 365
          StorageClass: DEEP_ARCHIVE
```

### **Spot Instances pro development**
```yaml
# Pro dev/test prostředí
SpotFleetConfiguration:
  IamFleetRole: !GetAtt SpotFleetRole.Arn
  AllocationStrategy: lowestPrice
  TargetCapacity: 2
  SpotPrice: "0.50"
  LaunchSpecifications:
    - ImageId: ami-12345678
      InstanceType: g4dn.xlarge
      SpotPrice: "0.50"
```

## 🔧 **Implementation Plan**

### **Phase 1: Infrastructure Setup**
1. **Terraform/CDK** infrastructure definice
2. **ECR** repository pro Docker images  
3. **S3 bucket** s lifecycle policies
4. **VPC** a networking setup
5. **IAM roles** a security groups

### **Phase 2: Container Optimization**
1. **Multi-stage Docker build** pro menší images
2. **Cache-optimized** entrypoint script
3. **Health checks** a monitoring
4. **Graceful shutdown** handling

### **Phase 3: Deployment Pipeline**
1. **GitHub Actions** CI/CD
2. **Blue/Green deployment**
3. **Automated testing**
4. **Rollback strategy**

### **Phase 4: Monitoring & Optimization**
1. **CloudWatch dashboards**
2. **Performance monitoring**
3. **Cost optimization**
4. **Auto-scaling tuning**

## 📊 **Expected Performance**

```yaml
# Benchmark expectations
ModelLoadTime:
  LocalCache: <2s
  S3Direct: 10-30s (depending on model size)
  S3Accelerated: 5-15s
  
Throughput:
  ConcurrentUsers: 50-100 per instance
  ImageGeneration: 1-5 images/minute per user
  
Costs:
  Development: $50-100/month
  Production: $200-500/month
  Enterprise: $500-2000/month
```

Chcete začít implementací? Doporučuji začít s **Phase 1** - Terraform infrastrukturou! 