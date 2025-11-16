"""
Distributed Architecture for 100K+ Users
Microservices, load balancing, caching, and auto-scaling
"""

import asyncio
import aioredis
import aiokafka
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass
from enum import Enum
import hashlib
import json
import uuid
from collections import defaultdict
import psutil
import numpy as np


class ServiceType(Enum):
    """Microservice types"""
    API_GATEWAY = "api_gateway"
    AUTH_SERVICE = "auth"
    CHAT_SERVICE = "chat"
    CRISIS_SERVICE = "crisis"
    ANALYTICS_SERVICE = "analytics"
    BILLING_SERVICE = "billing"
    NOTIFICATION_SERVICE = "notifications"
    ML_SERVICE = "ml_inference"
    

@dataclass
class ServiceInstance:
    """Service instance metadata"""
    service_type: ServiceType
    instance_id: str
    host: str
    port: int
    health_endpoint: str
    load: float
    capacity: int
    status: str
    region: str
    

class LoadBalancer:
    """Intelligent load balancer with health checks"""
    
    def __init__(self):
        self.services: Dict[ServiceType, List[ServiceInstance]] = defaultdict(list)
        self.health_checks = {}
        self.circuit_breakers = {}
        self.request_counts = defaultdict(int)
        
    def register_service(self, instance: ServiceInstance):
        """Register a new service instance"""
        self.services[instance.service_type].append(instance)
        self.circuit_breakers[instance.instance_id] = CircuitBreaker()
        
    def get_instance(self, 
                    service_type: ServiceType,
                    strategy: str = "least_connections") -> Optional[ServiceInstance]:
        """Get best instance using load balancing strategy"""
        
        available = [
            inst for inst in self.services[service_type]
            if inst.status == "healthy" and 
            not self.circuit_breakers[inst.instance_id].is_open()
        ]
        
        if not available:
            return None
            
        if strategy == "round_robin":
            # Simple round-robin
            self.request_counts[service_type] += 1
            index = self.request_counts[service_type] % len(available)
            return available[index]
            
        elif strategy == "least_connections":
            # Return instance with lowest load
            return min(available, key=lambda x: x.load)
            
        elif strategy == "weighted":
            # Weight by capacity and current load
            weights = [
                inst.capacity * (1 - inst.load) 
                for inst in available
            ]
            
            if sum(weights) == 0:
                return available[0]
                
            # Weighted random selection
            probabilities = [w/sum(weights) for w in weights]
            return np.random.choice(available, p=probabilities)
            
        elif strategy == "geographic":
            # Prefer instances in same region
            # This would use actual geo data
            return available[0]
            
        return available[0]
        
    async def health_check(self, instance: ServiceInstance) -> bool:
        """Perform health check on instance"""
        # This would make actual HTTP health check
        # For now, simulate based on load
        
        if instance.load > 0.9:
            instance.status = "unhealthy"
            return False
            
        instance.status = "healthy"
        return True
        

class CircuitBreaker:
    """Circuit breaker pattern for fault tolerance"""
    
    def __init__(self, 
                failure_threshold: int = 5,
                recovery_timeout: int = 60,
                expected_exception: type = Exception):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.expected_exception = expected_exception
        self.failure_count = 0
        self.last_failure_time = None
        self.state = "closed"  # closed, open, half_open
        
    def is_open(self) -> bool:
        """Check if circuit is open"""
        if self.state == "open":
            # Check if recovery timeout has passed
            if self.last_failure_time:
                if datetime.utcnow() - self.last_failure_time > timedelta(seconds=self.recovery_timeout):
                    self.state = "half_open"
                    return False
            return True
        return False
        
    def record_success(self):
        """Record successful request"""
        self.failure_count = 0
        self.state = "closed"
        
    def record_failure(self):
        """Record failed request"""
        self.failure_count += 1
        self.last_failure_time = datetime.utcnow()
        
        if self.failure_count >= self.failure_threshold:
            self.state = "open"
            

class CacheManager:
    """Distributed caching with Redis"""
    
    def __init__(self, redis_urls: List[str]):
        """Initialize with Redis cluster URLs"""
        self.redis_urls = redis_urls
        self.connections = {}
        self.cache_stats = defaultdict(lambda: {"hits": 0, "misses": 0})
        
    async def connect(self):
        """Connect to Redis instances"""
        for url in self.redis_urls:
            self.connections[url] = await aioredis.create_redis_pool(url)
            
    def get_shard(self, key: str) -> aioredis.Redis:
        """Get Redis shard for key using consistent hashing"""
        hash_val = int(hashlib.md5(key.encode()).hexdigest(), 16)
        shard_index = hash_val % len(self.connections)
        return list(self.connections.values())[shard_index]
        
    async def get(self, key: str, namespace: str = "default") -> Optional[Any]:
        """Get value from cache"""
        full_key = f"{namespace}:{key}"
        shard = self.get_shard(full_key)
        
        value = await shard.get(full_key)
        
        if value:
            self.cache_stats[namespace]["hits"] += 1
            return json.loads(value)
        else:
            self.cache_stats[namespace]["misses"] += 1
            return None
            
    async def set(self, 
                  key: str, 
                  value: Any,
                  ttl: int = 3600,
                  namespace: str = "default"):
        """Set value in cache"""
        full_key = f"{namespace}:{key}"
        shard = self.get_shard(full_key)
        
        await shard.setex(
            full_key,
            ttl,
            json.dumps(value)
        )
        
    async def invalidate_pattern(self, pattern: str, namespace: str = "default"):
        """Invalidate cache keys matching pattern"""
        full_pattern = f"{namespace}:{pattern}"
        
        for redis in self.connections.values():
            keys = await redis.keys(full_pattern)
            if keys:
                await redis.delete(*keys)
                

class DatabaseSharding:
    """Database sharding for horizontal scaling"""
    
    def __init__(self, shard_configs: List[Dict]):
        """Initialize with shard configurations"""
        self.shards = {}
        self.shard_count = len(shard_configs)
        
        for i, config in enumerate(shard_configs):
            self.shards[i] = {
                'config': config,
                'connection': None,
                'load': 0.0,
            }
            
    def get_shard_for_user(self, user_id: str) -> int:
        """Get shard number for user using consistent hashing"""
        hash_val = int(hashlib.md5(user_id.encode()).hexdigest(), 16)
        return hash_val % self.shard_count
        
    def get_connection(self, user_id: str):
        """Get database connection for user"""
        shard_num = self.get_shard_for_user(user_id)
        return self.shards[shard_num]['connection']
        
    async def rebalance_shards(self):
        """Rebalance data across shards"""
        # Calculate average load
        total_load = sum(s['load'] for s in self.shards.values())
        avg_load = total_load / self.shard_count
        
        # Identify overloaded shards
        overloaded = [
            shard_id for shard_id, shard in self.shards.items()
            if shard['load'] > avg_load * 1.2
        ]
        
        # Identify underutilized shards
        underutilized = [
            shard_id for shard_id, shard in self.shards.items()
            if shard['load'] < avg_load * 0.8
        ]
        
        # Move data from overloaded to underutilized
        # This would actually migrate data
        for source in overloaded:
            for target in underutilized:
                await self._migrate_data(source, target, avg_load)
                
    async def _migrate_data(self, source: int, target: int, target_load: float):
        """Migrate data between shards"""
        # This would actually move data
        pass
        

class AutoScaler:
    """Auto-scaling based on metrics"""
    
    def __init__(self, 
                min_instances: int = 2,
                max_instances: int = 20,
                target_cpu: float = 0.7,
                target_memory: float = 0.8):
        self.min_instances = min_instances
        self.max_instances = max_instances
        self.target_cpu = target_cpu
        self.target_memory = target_memory
        self.current_instances = {}
        self.scaling_history = []
        
    async def check_scaling_needed(self, service_type: ServiceType) -> Dict:
        """Check if scaling is needed"""
        metrics = await self._get_service_metrics(service_type)
        
        current_count = len(self.current_instances.get(service_type, []))
        
        # Calculate average metrics
        avg_cpu = metrics.get('avg_cpu', 0)
        avg_memory = metrics.get('avg_memory', 0)
        avg_response_time = metrics.get('avg_response_time', 0)
        queue_depth = metrics.get('queue_depth', 0)
        
        scaling_decision = {
            'action': 'none',
            'current_instances': current_count,
            'target_instances': current_count,
            'reason': '',
        }
        
        # Scale up conditions
        if avg_cpu > self.target_cpu or avg_memory > self.target_memory:
            if current_count < self.max_instances:
                scaling_decision['action'] = 'scale_up'
                scaling_decision['target_instances'] = min(
                    current_count + 2,
                    self.max_instances
                )
                scaling_decision['reason'] = f'High resource usage: CPU={avg_cpu:.2f}, Mem={avg_memory:.2f}'
                
        elif avg_response_time > 1000:  # 1 second
            if current_count < self.max_instances:
                scaling_decision['action'] = 'scale_up'
                scaling_decision['target_instances'] = min(
                    current_count + 1,
                    self.max_instances
                )
                scaling_decision['reason'] = f'High response time: {avg_response_time}ms'
                
        elif queue_depth > current_count * 100:
            if current_count < self.max_instances:
                scaling_decision['action'] = 'scale_up'
                scaling_decision['target_instances'] = min(
                    current_count * 2,
                    self.max_instances
                )
                scaling_decision['reason'] = f'High queue depth: {queue_depth}'
                
        # Scale down conditions
        elif avg_cpu < self.target_cpu * 0.3 and avg_memory < self.target_memory * 0.3:
            if current_count > self.min_instances:
                scaling_decision['action'] = 'scale_down'
                scaling_decision['target_instances'] = max(
                    current_count - 1,
                    self.min_instances
                )
                scaling_decision['reason'] = f'Low resource usage: CPU={avg_cpu:.2f}, Mem={avg_memory:.2f}'
                
        return scaling_decision
        
    async def _get_service_metrics(self, service_type: ServiceType) -> Dict:
        """Get metrics for service"""
        # This would query actual metrics from monitoring
        # For now, return simulated metrics
        
        cpu = psutil.cpu_percent() / 100
        memory = psutil.virtual_memory().percent / 100
        
        return {
            'avg_cpu': cpu,
            'avg_memory': memory,
            'avg_response_time': np.random.randint(100, 500),
            'queue_depth': np.random.randint(0, 1000),
        }
        
    async def execute_scaling(self, service_type: ServiceType, decision: Dict):
        """Execute scaling decision"""
        if decision['action'] == 'none':
            return
            
        self.scaling_history.append({
            'timestamp': datetime.utcnow().isoformat(),
            'service': service_type.value,
            'action': decision['action'],
            'from_count': decision['current_instances'],
            'to_count': decision['target_instances'],
            'reason': decision['reason'],
        })
        
        if decision['action'] == 'scale_up':
            await self._launch_instances(
                service_type,
                decision['target_instances'] - decision['current_instances']
            )
        elif decision['action'] == 'scale_down':
            await self._terminate_instances(
                service_type,
                decision['current_instances'] - decision['target_instances']
            )
            
    async def _launch_instances(self, service_type: ServiceType, count: int):
        """Launch new instances"""
        # This would actually launch containers/VMs
        # For now, simulate
        
        for i in range(count):
            instance_id = str(uuid.uuid4())[:8]
            instance = ServiceInstance(
                service_type=service_type,
                instance_id=instance_id,
                host=f"{service_type.value}-{instance_id}.internal",
                port=8000 + i,
                health_endpoint="/health",
                load=0.0,
                capacity=1000,
                status="healthy",
                region="us-west-2"
            )
            
            if service_type not in self.current_instances:
                self.current_instances[service_type] = []
                
            self.current_instances[service_type].append(instance)
            
    async def _terminate_instances(self, service_type: ServiceType, count: int):
        """Terminate instances"""
        # This would actually terminate containers/VMs
        # For now, simulate
        
        if service_type in self.current_instances:
            # Remove instances with lowest load first
            instances = sorted(
                self.current_instances[service_type],
                key=lambda x: x.load
            )
            
            for i in range(min(count, len(instances))):
                self.current_instances[service_type].remove(instances[i])
                

class MessageQueue:
    """Distributed message queue with Kafka"""
    
    def __init__(self, brokers: List[str]):
        """Initialize with Kafka brokers"""
        self.brokers = brokers
        self.producer = None
        self.consumers = {}
        self.message_counts = defaultdict(int)
        
    async def connect(self):
        """Connect to Kafka"""
        self.producer = aiokafka.AIOKafkaProducer(
            bootstrap_servers=','.join(self.brokers),
            value_serializer=lambda v: json.dumps(v).encode()
        )
        await self.producer.start()
        
    async def publish(self, topic: str, message: Dict, key: Optional[str] = None):
        """Publish message to topic"""
        await self.producer.send(
            topic,
            value=message,
            key=key.encode() if key else None
        )
        
        self.message_counts[topic] += 1
        
    async def subscribe(self, topic: str, group_id: str, handler):
        """Subscribe to topic"""
        consumer = aiokafka.AIOKafkaConsumer(
            topic,
            bootstrap_servers=','.join(self.brokers),
            group_id=group_id,
            value_deserializer=lambda m: json.loads(m.decode())
        )
        
        await consumer.start()
        self.consumers[f"{topic}:{group_id}"] = consumer
        
        # Start consuming
        async for msg in consumer:
            await handler(msg.value)
            

class RateLimiter:
    """Distributed rate limiting"""
    
    def __init__(self, redis_client):
        self.redis = redis_client
        self.limits = {
            'default': {'requests': 1000, 'window': 3600},
            'crisis': {'requests': 10000, 'window': 3600},
            'api': {'requests': 100, 'window': 60},
        }
        
    async def check_limit(self, 
                         user_id: str,
                         limit_type: str = 'default') -> Tuple[bool, Dict]:
        """Check if request is within rate limit"""
        
        limit = self.limits.get(limit_type, self.limits['default'])
        
        # Use sliding window algorithm
        key = f"rate_limit:{limit_type}:{user_id}"
        current_time = int(datetime.utcnow().timestamp())
        window_start = current_time - limit['window']
        
        # Remove old entries
        await self.redis.zremrangebyscore(key, 0, window_start)
        
        # Count requests in window
        request_count = await self.redis.zcard(key)
        
        if request_count < limit['requests']:
            # Add current request
            await self.redis.zadd(key, current_time, str(uuid.uuid4()))
            await self.redis.expire(key, limit['window'])
            
            return True, {
                'allowed': True,
                'remaining': limit['requests'] - request_count - 1,
                'reset': current_time + limit['window'],
            }
        else:
            return False, {
                'allowed': False,
                'remaining': 0,
                'reset': current_time + limit['window'],
                'retry_after': limit['window'],
            }
            

class DistributedArchitecture:
    """Main distributed architecture orchestrator"""
    
    def __init__(self):
        self.load_balancer = LoadBalancer()
        self.cache_manager = None
        self.db_sharding = None
        self.auto_scaler = AutoScaler()
        self.message_queue = None
        self.rate_limiter = None
        
    async def initialize(self, config: Dict):
        """Initialize all components"""
        
        # Initialize cache
        if 'redis_urls' in config:
            self.cache_manager = CacheManager(config['redis_urls'])
            await self.cache_manager.connect()
            
        # Initialize database sharding
        if 'db_shards' in config:
            self.db_sharding = DatabaseSharding(config['db_shards'])
            
        # Initialize message queue
        if 'kafka_brokers' in config:
            self.message_queue = MessageQueue(config['kafka_brokers'])
            await self.message_queue.connect()
            
        # Initialize rate limiter
        if self.cache_manager:
            self.rate_limiter = RateLimiter(
                list(self.cache_manager.connections.values())[0]
            )
            
    async def handle_request(self, 
                           request_type: ServiceType,
                           user_id: str,
                           request_data: Dict) -> Dict:
        """Handle incoming request with full architecture"""
        
        # 1. Rate limiting
        if self.rate_limiter:
            allowed, limit_info = await self.rate_limiter.check_limit(user_id)
            if not allowed:
                return {'error': 'Rate limit exceeded', 'retry_after': limit_info['retry_after']}
                
        # 2. Check cache
        if self.cache_manager:
            cache_key = f"{request_type.value}:{user_id}:{hash(str(request_data))}"
            cached = await self.cache_manager.get(cache_key)
            if cached:
                return cached
                
        # 3. Get service instance
        instance = self.load_balancer.get_instance(request_type)
        if not instance:
            return {'error': 'No service available'}
            
        # 4. Check circuit breaker
        circuit_breaker = self.load_balancer.circuit_breakers[instance.instance_id]
        if circuit_breaker.is_open():
            # Try another instance
            instance = self.load_balancer.get_instance(request_type, strategy="round_robin")
            if not instance:
                return {'error': 'All services unavailable'}
                
        # 5. Route to appropriate shard
        if self.db_sharding:
            db_connection = self.db_sharding.get_connection(user_id)
            request_data['db_connection'] = db_connection
            
        # 6. Process request (simulated)
        try:
            # This would make actual service call
            response = await self._process_request(instance, request_data)
            
            # Record success
            circuit_breaker.record_success()
            
            # 7. Cache response
            if self.cache_manager:
                await self.cache_manager.set(cache_key, response, ttl=300)
                
            # 8. Publish event
            if self.message_queue:
                await self.message_queue.publish(
                    'request_processed',
                    {
                        'user_id': user_id,
                        'service': request_type.value,
                        'timestamp': datetime.utcnow().isoformat(),
                    }
                )
                
            return response
            
        except Exception as e:
            # Record failure
            circuit_breaker.record_failure()
            return {'error': str(e)}
            
    async def _process_request(self, instance: ServiceInstance, request_data: Dict) -> Dict:
        """Process request on service instance"""
        # Simulate processing
        await asyncio.sleep(0.1)
        
        return {
            'status': 'success',
            'instance_id': instance.instance_id,
            'response': 'Processed successfully',
        }
        
    async def monitor_and_scale(self):
        """Continuous monitoring and auto-scaling"""
        while True:
            for service_type in ServiceType:
                decision = await self.auto_scaler.check_scaling_needed(service_type)
                
                if decision['action'] != 'none':
                    await self.auto_scaler.execute_scaling(service_type, decision)
                    
            # Check every 30 seconds
            await asyncio.sleep(30)
