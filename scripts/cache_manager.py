#!/usr/bin/env python3
"""
Intelligent Cache Manager for ComfyUI AWS Deployment
Handles S3 model caching with LRU eviction and parallel downloads
"""

import os
import sys
import asyncio
import aiofiles
import aioboto3
import json
import time
import hashlib
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from collections import OrderedDict
import psutil
import shutil

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class CacheEntry:
    """Represents a cached model entry"""
    path: str
    size: int
    last_access: float
    download_time: float
    access_count: int
    s3_key: str
    local_path: str

class IntelligentCacheManager:
    """
    Intelligent cache manager for S3 models with:
    - LRU eviction policy
    - Parallel downloads
    - Hot/Cold cache tiers
    - Performance monitoring
    """
    
    def __init__(self, 
                 cache_dir: str = "/tmp/model_cache",
                 hot_cache_dir: str = "/tmp/hot_cache", 
                 max_cache_size_gb: int = 160,
                 hot_cache_ratio: float = 0.3,
                 s3_bucket: str = None,
                 aws_region: str = "eu-central-1"):
        
        self.cache_dir = Path(cache_dir)
        self.hot_cache_dir = Path(hot_cache_dir)
        self.max_cache_size = max_cache_size_gb * 1024 * 1024 * 1024  # Convert to bytes
        self.hot_cache_size = int(self.max_cache_size * hot_cache_ratio)
        self.cold_cache_size = self.max_cache_size - self.hot_cache_size
        
        self.s3_bucket = s3_bucket or os.getenv('S3_BUCKET_NAME')
        self.aws_region = aws_region
        
        # Cache metadata
        self.cache_metadata: Dict[str, CacheEntry] = {}
        self.hot_cache: OrderedDict = OrderedDict()
        self.cold_cache: OrderedDict = OrderedDict()
        
        # Performance metrics
        self.stats = {
            'cache_hits': 0,
            'cache_misses': 0,
            'downloads': 0,
            'evictions': 0,
            'total_download_time': 0,
            'total_download_size': 0
        }
        
        # Create directories
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.hot_cache_dir.mkdir(parents=True, exist_ok=True)
        
        # Initialize metadata
        self._load_metadata()
        
        logger.info(f"Cache initialized: {max_cache_size_gb}GB total, "
                   f"{hot_cache_ratio*100}% hot cache")
    
    def _load_metadata(self):
        """Load cache metadata from disk"""
        metadata_file = self.cache_dir / "cache_metadata.json"
        if metadata_file.exists():
            try:
                with open(metadata_file, 'r') as f:
                    data = json.load(f)
                    for key, entry_data in data.items():
                        self.cache_metadata[key] = CacheEntry(**entry_data)
                logger.info(f"Loaded {len(self.cache_metadata)} cache entries")
            except Exception as e:
                logger.error(f"Failed to load cache metadata: {e}")
    
    def _save_metadata(self):
        """Save cache metadata to disk"""
        metadata_file = self.cache_dir / "cache_metadata.json"
        try:
            data = {key: asdict(entry) for key, entry in self.cache_metadata.items()}
            with open(metadata_file, 'w') as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            logger.error(f"Failed to save cache metadata: {e}")
    
    def _get_cache_key(self, s3_key: str) -> str:
        """Generate cache key from S3 key"""
        return hashlib.md5(s3_key.encode()).hexdigest()
    
    def _get_local_path(self, cache_key: str, is_hot: bool = False) -> Path:
        """Get local file path for cache key"""
        base_dir = self.hot_cache_dir if is_hot else self.cache_dir
        return base_dir / f"{cache_key}.model"
    
    async def _download_from_s3(self, s3_key: str, local_path: Path, 
                              progress_callback=None) -> bool:
        """Download file from S3 with progress tracking"""
        try:
            session = aioboto3.Session()
            async with session.client('s3', region_name=self.aws_region) as s3:
                # Get object info
                response = await s3.head_object(Bucket=self.s3_bucket, Key=s3_key)
                file_size = response['ContentLength']
                
                logger.info(f"Downloading {s3_key} ({file_size / 1024 / 1024:.1f} MB)")
                
                start_time = time.time()
                
                # Download with streaming
                response = await s3.get_object(Bucket=self.s3_bucket, Key=s3_key)
                
                async with aiofiles.open(local_path, 'wb') as f:
                    downloaded = 0
                    async for chunk in response['Body']:
                        await f.write(chunk)
                        downloaded += len(chunk)
                        
                        if progress_callback:
                            await progress_callback(downloaded, file_size)
                
                download_time = time.time() - start_time
                
                # Update stats
                self.stats['downloads'] += 1
                self.stats['total_download_time'] += download_time
                self.stats['total_download_size'] += file_size
                
                logger.info(f"Downloaded {s3_key} in {download_time:.2f}s "
                           f"({file_size / download_time / 1024 / 1024:.1f} MB/s)")
                
                return True
                
        except Exception as e:
            logger.error(f"Failed to download {s3_key}: {e}")
            return False
    
    def _should_promote_to_hot(self, cache_key: str) -> bool:
        """Determine if a model should be promoted to hot cache"""
        if cache_key not in self.cache_metadata:
            return False
            
        entry = self.cache_metadata[cache_key]
        
        # Promote if accessed frequently or recently
        recent_access = time.time() - entry.last_access < 3600  # 1 hour
        frequent_access = entry.access_count > 3
        
        return recent_access or frequent_access
    
    def _evict_from_cache(self, target_size: int, cache_type: str = "cold"):
        """Evict least recently used items from cache"""
        cache = self.hot_cache if cache_type == "hot" else self.cold_cache
        cache_dir = self.hot_cache_dir if cache_type == "hot" else self.cache_dir
        
        current_size = self._get_cache_size(cache_type)
        
        while current_size > target_size and cache:
            # Remove least recently used
            cache_key, _ = cache.popitem(last=False)
            
            if cache_key in self.cache_metadata:
                entry = self.cache_metadata[cache_key]
                local_path = Path(entry.local_path)
                
                if local_path.exists():
                    file_size = local_path.stat().st_size
                    local_path.unlink()
                    current_size -= file_size
                    
                    logger.info(f"Evicted {entry.s3_key} from {cache_type} cache "
                               f"({file_size / 1024 / 1024:.1f} MB)")
                
                del self.cache_metadata[cache_key]
                self.stats['evictions'] += 1
    
    def _get_cache_size(self, cache_type: str = "total") -> int:
        """Get current cache size in bytes"""
        if cache_type == "hot":
            cache_dir = self.hot_cache_dir
        elif cache_type == "cold":
            cache_dir = self.cache_dir
        else:  # total
            return self._get_cache_size("hot") + self._get_cache_size("cold")
        
        total_size = 0
        if cache_dir.exists():
            for file_path in cache_dir.glob("*.model"):
                try:
                    total_size += file_path.stat().st_size
                except OSError:
                    pass
        
        return total_size
    
    async def get_model(self, s3_key: str, target_path: str = None) -> Optional[str]:
        """
        Get model from cache or download from S3
        Returns local path to the model file
        """
        cache_key = self._get_cache_key(s3_key)
        
        # Check hot cache first
        hot_path = self._get_local_path(cache_key, is_hot=True)
        if hot_path.exists():
            # Update access info
            if cache_key in self.cache_metadata:
                entry = self.cache_metadata[cache_key]
                entry.last_access = time.time()
                entry.access_count += 1
                
                # Move to end of hot cache (most recently used)
                if cache_key in self.hot_cache:
                    del self.hot_cache[cache_key]
                self.hot_cache[cache_key] = True
            
            self.stats['cache_hits'] += 1
            logger.info(f"Hot cache hit: {s3_key}")
            
            # Copy to target path if specified
            if target_path:
                shutil.copy2(hot_path, target_path)
                return target_path
            
            return str(hot_path)
        
        # Check cold cache
        cold_path = self._get_local_path(cache_key, is_hot=False)
        if cold_path.exists():
            # Update access info
            if cache_key in self.cache_metadata:
                entry = self.cache_metadata[cache_key]
                entry.last_access = time.time()
                entry.access_count += 1
                
                # Move to end of cold cache
                if cache_key in self.cold_cache:
                    del self.cold_cache[cache_key]
                self.cold_cache[cache_key] = True
                
                # Consider promoting to hot cache
                if self._should_promote_to_hot(cache_key):
                    await self._promote_to_hot_cache(cache_key)
                    return await self.get_model(s3_key, target_path)
            
            self.stats['cache_hits'] += 1
            logger.info(f"Cold cache hit: {s3_key}")
            
            # Copy to target path if specified
            if target_path:
                shutil.copy2(cold_path, target_path)
                return target_path
            
            return str(cold_path)
        
        # Cache miss - download from S3
        self.stats['cache_misses'] += 1
        logger.info(f"Cache miss: {s3_key}")
        
        # Determine cache tier for new download
        is_hot = self._should_promote_to_hot(cache_key)
        local_path = self._get_local_path(cache_key, is_hot=is_hot)
        
        # Ensure space in appropriate cache
        if is_hot:
            self._evict_from_cache(self.hot_cache_size - 1024*1024*1024, "hot")  # Leave 1GB buffer
        else:
            self._evict_from_cache(self.cold_cache_size - 1024*1024*1024, "cold")
        
        # Download file
        download_start = time.time()
        success = await self._download_from_s3(s3_key, local_path)
        
        if success:
            # Add to cache metadata
            file_size = local_path.stat().st_size
            download_time = time.time() - download_start
            
            entry = CacheEntry(
                path=s3_key,
                size=file_size,
                last_access=time.time(),
                download_time=download_time,
                access_count=1,
                s3_key=s3_key,
                local_path=str(local_path)
            )
            
            self.cache_metadata[cache_key] = entry
            
            # Add to appropriate cache
            if is_hot:
                self.hot_cache[cache_key] = True
            else:
                self.cold_cache[cache_key] = True
            
            # Save metadata
            self._save_metadata()
            
            # Copy to target path if specified
            if target_path:
                shutil.copy2(local_path, target_path)
                return target_path
            
            return str(local_path)
        
        return None
    
    async def _promote_to_hot_cache(self, cache_key: str):
        """Promote a model from cold to hot cache"""
        if cache_key not in self.cache_metadata:
            return
        
        entry = self.cache_metadata[cache_key]
        cold_path = Path(entry.local_path)
        hot_path = self._get_local_path(cache_key, is_hot=True)
        
        if cold_path.exists():
            # Ensure space in hot cache
            self._evict_from_cache(self.hot_cache_size - entry.size, "hot")
            
            # Move file to hot cache
            shutil.move(str(cold_path), str(hot_path))
            
            # Update metadata
            entry.local_path = str(hot_path)
            
            # Update cache tracking
            if cache_key in self.cold_cache:
                del self.cold_cache[cache_key]
            self.hot_cache[cache_key] = True
            
            logger.info(f"Promoted {entry.s3_key} to hot cache")
    
    async def preload_models(self, model_list: List[str]):
        """Preload popular models into cache"""
        logger.info(f"Preloading {len(model_list)} models")
        
        # Download models in parallel (limited concurrency)
        semaphore = asyncio.Semaphore(4)  # Max 4 concurrent downloads
        
        async def download_model(s3_key):
            async with semaphore:
                return await self.get_model(s3_key)
        
        tasks = [download_model(s3_key) for s3_key in model_list]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        successful = sum(1 for r in results if isinstance(r, str))
        logger.info(f"Preloaded {successful}/{len(model_list)} models")
    
    def get_cache_stats(self) -> Dict:
        """Get cache performance statistics"""
        total_requests = self.stats['cache_hits'] + self.stats['cache_misses']
        hit_rate = (self.stats['cache_hits'] / total_requests * 100) if total_requests > 0 else 0
        
        avg_download_speed = 0
        if self.stats['total_download_time'] > 0:
            avg_download_speed = (self.stats['total_download_size'] / 
                                self.stats['total_download_time'] / 1024 / 1024)  # MB/s
        
        return {
            'cache_hit_rate': f"{hit_rate:.1f}%",
            'total_requests': total_requests,
            'cache_hits': self.stats['cache_hits'],
            'cache_misses': self.stats['cache_misses'],
            'downloads': self.stats['downloads'],
            'evictions': self.stats['evictions'],
            'avg_download_speed_mbps': f"{avg_download_speed:.1f}",
            'hot_cache_size_mb': self._get_cache_size("hot") / 1024 / 1024,
            'cold_cache_size_mb': self._get_cache_size("cold") / 1024 / 1024,
            'total_cache_size_mb': self._get_cache_size("total") / 1024 / 1024,
            'hot_cache_entries': len(self.hot_cache),
            'cold_cache_entries': len(self.cold_cache)
        }
    
    def cleanup_cache(self):
        """Clean up cache and save metadata"""
        logger.info("Cleaning up cache...")
        self._save_metadata()
        
        # Log final stats
        stats = self.get_cache_stats()
        logger.info(f"Cache stats: {json.dumps(stats, indent=2)}")

# Global cache manager instance
cache_manager: Optional[IntelligentCacheManager] = None

def get_cache_manager() -> IntelligentCacheManager:
    """Get global cache manager instance"""
    global cache_manager
    if cache_manager is None:
        cache_size_gb = int(os.getenv('CACHE_SIZE_GB', '160'))
        cache_manager = IntelligentCacheManager(max_cache_size_gb=cache_size_gb)
    return cache_manager

async def main():
    """Test the cache manager"""
    manager = get_cache_manager()
    
    # Test model download
    test_model = "models/checkpoints/test_model.safetensors"
    result = await manager.get_model(test_model)
    
    if result:
        print(f"Model cached at: {result}")
    else:
        print("Failed to cache model")
    
    # Print stats
    stats = manager.get_cache_stats()
    print(f"Cache stats: {json.dumps(stats, indent=2)}")

if __name__ == "__main__":
    asyncio.run(main()) 