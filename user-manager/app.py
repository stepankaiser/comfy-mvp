#!/usr/bin/env python3
"""
ComfyUI User Environment Manager
Simple web UI for managing user containers in AWS ECS
"""

import os
import json
import boto3
import logging
from flask import Flask, render_template, request, jsonify, redirect, url_for
from datetime import datetime
import uuid

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# AWS Configuration
AWS_REGION = os.getenv('AWS_REGION', 'eu-central-1')
ECS_CLUSTER = os.getenv('ECS_CLUSTER', 'comfyui-golden-image-dev-cluster')
ALB_DNS = os.getenv('ALB_DNS_NAME', '')
ADMIN_URL = f"http://{ALB_DNS}/admin/" if ALB_DNS else "http://localhost:8190"

# Initialize AWS clients
ecs_client = boto3.client('ecs', region_name=AWS_REGION)
ec2_client = boto3.client('ec2', region_name=AWS_REGION)

class UserEnvironmentManager:
    """Manages user ComfyUI environments in ECS"""
    
    def __init__(self):
        self.cluster_name = ECS_CLUSTER
        
    def list_user_environments(self):
        """List all running user environments"""
        try:
            # List all services in the cluster
            services = ecs_client.list_services(cluster=self.cluster_name)
            
            environments = []
            for service_arn in services['serviceArns']:
                service_name = service_arn.split('/')[-1]
                
                # Skip admin service
                if 'admin' in service_name:
                    continue
                
                # Get service details
                service_details = ecs_client.describe_services(
                    cluster=self.cluster_name,
                    services=[service_arn]
                )
                
                if service_details['services']:
                    service = service_details['services'][0]
                    
                    # Get task details
                    tasks = ecs_client.list_tasks(
                        cluster=self.cluster_name,
                        serviceName=service_name
                    )
                    
                    running_tasks = len(tasks['taskArns'])
                    
                    env_info = {
                        'id': service_name.replace('comfyui-golden-image-dev-', '').replace('-service', ''),
                        'service_name': service_name,
                        'status': service['status'],
                        'desired_count': service['desiredCount'],
                        'running_count': service['runningCount'],
                        'pending_count': service['pendingCount'],
                        'created_at': service['createdAt'].isoformat() if service.get('createdAt') else None,
                        'url': f"http://{ALB_DNS}/user/{service_name}/" if ALB_DNS else None
                    }
                    environments.append(env_info)
            
            return environments
            
        except Exception as e:
            logger.error(f"Error listing environments: {e}")
            return []
    
    def create_user_environment(self, user_id=None):
        """Create a new user environment"""
        if not user_id:
            user_id = f"user-{uuid.uuid4().hex[:8]}"
        
        service_name = f"comfyui-golden-image-dev-{user_id}-service"
        
        try:
            # Try to get shared GPU task definition first, then fall back to dedicated
            task_def_names = [
                'comfyui-golden-image-dev-user-shared-gpu',
                'comfyui-golden-image-dev-user-dedicated-gpu',
                'comfyui-golden-image-dev-user'
            ]
            
            task_def_arn = None
            for task_def_name in task_def_names:
                try:
                    task_def_response = ecs_client.describe_task_definition(
                        taskDefinition=task_def_name
                    )
                    task_def_arn = task_def_response['taskDefinition']['taskDefinitionArn']
                    logger.info(f"Using task definition: {task_def_name}")
                    break
                except Exception:
                    continue
            
            if not task_def_arn:
                raise Exception("No suitable task definition found")
            
            # Get network configuration from existing user service
            existing_services = ecs_client.describe_services(
                cluster=self.cluster_name,
                services=['comfyui-golden-image-dev-user-service']
            )
            
            if not existing_services['services']:
                raise Exception("Base user service not found")
            
            base_service = existing_services['services'][0]
            network_config = base_service['networkConfiguration']
            
            # Create new service
            response = ecs_client.create_service(
                cluster=self.cluster_name,
                serviceName=service_name,
                taskDefinition=task_def_arn,
                desiredCount=1,
                launchType='FARGATE',
                networkConfiguration=network_config,
                tags=[
                    {
                        'key': 'Environment',
                        'value': 'dev'
                    },
                    {
                        'key': 'UserID',
                        'value': user_id
                    },
                    {
                        'key': 'CreatedBy',
                        'value': 'UserManager'
                    }
                ]
            )
            
            logger.info(f"Created user environment: {service_name}")
            return {
                'success': True,
                'user_id': user_id,
                'service_name': service_name,
                'message': f"User environment {user_id} created successfully"
            }
            
        except Exception as e:
            logger.error(f"Error creating environment: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def delete_user_environment(self, service_name):
        """Delete a user environment"""
        try:
            # Scale down to 0
            ecs_client.update_service(
                cluster=self.cluster_name,
                service=service_name,
                desiredCount=0
            )
            
            # Wait a moment then delete
            import time
            time.sleep(5)
            
            # Delete the service
            ecs_client.delete_service(
                cluster=self.cluster_name,
                service=service_name
            )
            
            logger.info(f"Deleted user environment: {service_name}")
            return {
                'success': True,
                'message': f"Environment {service_name} deleted successfully"
            }
            
        except Exception as e:
            logger.error(f"Error deleting environment: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_cluster_status(self):
        """Get overall cluster status"""
        try:
            cluster_info = ecs_client.describe_clusters(clusters=[self.cluster_name])
            
            if cluster_info['clusters']:
                cluster = cluster_info['clusters'][0]
                return {
                    'name': cluster['clusterName'],
                    'status': cluster['status'],
                    'running_tasks': cluster['runningTasksCount'],
                    'pending_tasks': cluster['pendingTasksCount'],
                    'active_services': cluster['activeServicesCount']
                }
            
            return None
            
        except Exception as e:
            logger.error(f"Error getting cluster status: {e}")
            return None

# Initialize manager
env_manager = UserEnvironmentManager()

@app.route('/')
def index():
    """Main dashboard"""
    environments = env_manager.list_user_environments()
    cluster_status = env_manager.get_cluster_status()
    
    return render_template('dashboard.html', 
                         environments=environments,
                         cluster_status=cluster_status,
                         admin_url=ADMIN_URL,
                         alb_dns=ALB_DNS)

@app.route('/api/environments')
def api_list_environments():
    """API endpoint to list environments"""
    environments = env_manager.list_user_environments()
    return jsonify(environments)

@app.route('/api/environments', methods=['POST'])
def api_create_environment():
    """API endpoint to create new environment"""
    data = request.get_json() or {}
    user_id = data.get('user_id')
    
    result = env_manager.create_user_environment(user_id)
    return jsonify(result)

@app.route('/api/environments/<service_name>', methods=['DELETE'])
def api_delete_environment(service_name):
    """API endpoint to delete environment"""
    result = env_manager.delete_user_environment(service_name)
    return jsonify(result)

@app.route('/create', methods=['POST'])
def create_environment():
    """Web form handler for creating environment"""
    user_id = request.form.get('user_id', '').strip()
    
    if not user_id:
        user_id = None  # Will generate random ID
    
    result = env_manager.create_user_environment(user_id)
    
    if result['success']:
        return redirect(url_for('index'))
    else:
        return f"Error: {result['error']}", 500

@app.route('/delete/<service_name>', methods=['POST'])
def delete_environment(service_name):
    """Web form handler for deleting environment"""
    result = env_manager.delete_user_environment(service_name)
    
    if result['success']:
        return redirect(url_for('index'))
    else:
        return f"Error: {result['error']}", 500

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'cluster': ECS_CLUSTER,
        'region': AWS_REGION
    })

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('DEBUG', 'false').lower() == 'true'
    
    app.run(host='0.0.0.0', port=port, debug=debug) 