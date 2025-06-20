import os
import json
import shutil
from pathlib import Path
import mimetypes

class DataManagerNode:
    """
    ComfyUI Data Manager Node - Provides file management capabilities
    """
    
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {},
            "optional": {
                "refresh": ("BOOLEAN", {"default": False}),
            }
        }

    RETURN_TYPES = ("STRING",)
    RETURN_NAMES = ("status",)
    FUNCTION = "manage_data"
    CATEGORY = "Data Management"

    def __init__(self):
        # Define paths for shared data
        self.models_path = Path("/app/models")
        self.custom_nodes_path = Path("/app/custom_nodes")
        self.output_path = Path("/app/output")
        self.input_path = Path("/app/input")
        
        # Create paths if they don't exist
        for path in [self.models_path, self.custom_nodes_path, self.output_path, self.input_path]:
            path.mkdir(parents=True, exist_ok=True)

    def get_directory_structure(self, path, max_depth=3, current_depth=0):
        """Get directory structure as nested dict"""
        if current_depth >= max_depth:
            return {}
            
        structure = {}
        try:
            if path.is_dir():
                for item in sorted(path.iterdir()):
                    if item.name.startswith('.'):
                        continue
                        
                    item_info = {
                        'name': item.name,
                        'type': 'directory' if item.is_dir() else 'file',
                        'path': str(item.relative_to(Path("/app"))),
                        'size': 0 if item.is_dir() else item.stat().st_size,
                    }
                    
                    if item.is_file():
                        item_info['mime_type'] = mimetypes.guess_type(str(item))[0] or 'application/octet-stream'
                    
                    if item.is_dir() and current_depth < max_depth - 1:
                        item_info['children'] = self.get_directory_structure(item, max_depth, current_depth + 1)
                    
                    structure[item.name] = item_info
        except PermissionError:
            pass
            
        return structure

    def manage_data(self, refresh=False):
        """Main function to manage data and return directory structure"""
        try:
            # Get directory structures
            data_structure = {
                'models': self.get_directory_structure(self.models_path),
                'custom_nodes': self.get_directory_structure(self.custom_nodes_path),
                'output': self.get_directory_structure(self.output_path),
                'input': self.get_directory_structure(self.input_path),
                'timestamp': str(Path.cwd())  # Just for refresh trigger
            }
            
            # Save structure to temp file for web interface
            temp_file = Path("/tmp/comfyui_data_structure.json")
            with open(temp_file, 'w') as f:
                json.dump(data_structure, f, indent=2)
            
            return (f"Data structure updated. Found {len(data_structure['models'])} model categories, "
                   f"{len(data_structure['custom_nodes'])} custom node categories.")
            
        except Exception as e:
            return f"Error managing data: {str(e)}"

# Register the node
NODE_CLASS_MAPPINGS = {
    "DataManagerNode": DataManagerNode
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "DataManagerNode": "Data Manager"
} 