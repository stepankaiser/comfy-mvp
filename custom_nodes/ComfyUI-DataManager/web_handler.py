import os
import json
import shutil
import tempfile
from pathlib import Path
from aiohttp import web
import aiofiles
import mimetypes

class DataManagerWebHandler:
    def __init__(self):
        self.base_paths = {
            'models': Path("/app/models"),
            'custom_nodes': Path("/app/custom_nodes"), 
            'output': Path("/app/output"),
            'input': Path("/app/input")
        }

    async def get_directory_structure(self, request):
        """API endpoint to get directory structure"""
        try:
            from .data_manager_node import DataManagerNode
            manager = DataManagerNode()
            
            data_structure = {
                'models': manager.get_directory_structure(manager.models_path),
                'custom_nodes': manager.get_directory_structure(manager.custom_nodes_path),
                'output': manager.get_directory_structure(manager.output_path),
                'input': manager.get_directory_structure(manager.input_path),
            }
            
            return web.json_response(data_structure)
        except Exception as e:
            return web.json_response({'error': str(e)}, status=500)

    async def upload_file(self, request):
        """API endpoint to handle file uploads"""
        try:
            reader = await request.multipart()
            field = await reader.next()
            
            if field.name != 'file':
                return web.json_response({'error': 'No file provided'}, status=400)
            
            # Get target directory from form data
            target_dir = None
            while field:
                if field.name == 'target_dir':
                    target_dir = await field.text()
                elif field.name == 'file':
                    filename = field.filename
                    if not filename:
                        return web.json_response({'error': 'No filename provided'}, status=400)
                    
                    # Validate target directory
                    if target_dir not in self.base_paths:
                        return web.json_response({'error': 'Invalid target directory'}, status=400)
                    
                    # Create subdirectory if specified
                    subdir = request.query.get('subdir', '')
                    target_path = self.base_paths[target_dir]
                    if subdir:
                        target_path = target_path / subdir
                        target_path.mkdir(parents=True, exist_ok=True)
                    
                    file_path = target_path / filename
                    
                    # Save file
                    async with aiofiles.open(file_path, 'wb') as f:
                        while True:
                            chunk = await field.read_chunk()
                            if not chunk:
                                break
                            await f.write(chunk)
                    
                    return web.json_response({
                        'success': True,
                        'filename': filename,
                        'path': str(file_path.relative_to(Path("/app"))),
                        'size': file_path.stat().st_size
                    })
                
                field = await reader.next()
            
            return web.json_response({'error': 'No file received'}, status=400)
            
        except Exception as e:
            return web.json_response({'error': str(e)}, status=500)

    async def delete_file(self, request):
        """API endpoint to delete files"""
        try:
            data = await request.json()
            file_path = Path("/app") / data.get('path', '')
            
            if not file_path.exists():
                return web.json_response({'error': 'File not found'}, status=404)
            
            # Security check - ensure path is within allowed directories
            allowed = False
            for base_path in self.base_paths.values():
                try:
                    file_path.relative_to(base_path)
                    allowed = True
                    break
                except ValueError:
                    continue
            
            if not allowed:
                return web.json_response({'error': 'Access denied'}, status=403)
            
            if file_path.is_file():
                file_path.unlink()
            elif file_path.is_dir():
                shutil.rmtree(file_path)
            
            return web.json_response({'success': True})
            
        except Exception as e:
            return web.json_response({'error': str(e)}, status=500)

    async def create_directory(self, request):
        """API endpoint to create directories"""
        try:
            data = await request.json()
            dir_path = Path("/app") / data.get('path', '')
            
            # Security check
            allowed = False
            for base_path in self.base_paths.values():
                try:
                    dir_path.relative_to(base_path)
                    allowed = True
                    break
                except ValueError:
                    continue
            
            if not allowed:
                return web.json_response({'error': 'Access denied'}, status=403)
            
            dir_path.mkdir(parents=True, exist_ok=True)
            return web.json_response({'success': True})
            
        except Exception as e:
            return web.json_response({'error': str(e)}, status=500)

    async def serve_data_manager_ui(self, request):
        """Serve the data manager UI"""
        ui_path = Path(__file__).parent / "web" / "data_manager.html"
        if ui_path.exists():
            return web.FileResponse(ui_path)
        else:
            return web.Response(text="Data Manager UI not found", status=404)

# Global handler instance
handler = DataManagerWebHandler()

def setup_web_routes():
    """Setup web routes for the data manager"""
    try:
        import server
        
        # Add routes to ComfyUI's web server
        server.PromptServer.instance.app.router.add_get('/data-manager', handler.serve_data_manager_ui)
        server.PromptServer.instance.app.router.add_get('/api/data-structure', handler.get_directory_structure)
        server.PromptServer.instance.app.router.add_post('/api/upload', handler.upload_file)
        server.PromptServer.instance.app.router.add_delete('/api/delete', handler.delete_file)
        server.PromptServer.instance.app.router.add_post('/api/create-dir', handler.create_directory)
        
        print("✅ Data Manager web routes registered")
    except Exception as e:
        print(f"❌ Failed to register Data Manager web routes: {e}") 