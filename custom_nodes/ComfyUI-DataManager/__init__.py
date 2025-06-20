import os
from .data_manager_node import NODE_CLASS_MAPPINGS, NODE_DISPLAY_NAME_MAPPINGS
from .web_handler import setup_web_routes

__all__ = ['NODE_CLASS_MAPPINGS', 'NODE_DISPLAY_NAME_MAPPINGS', 'WEB_DIRECTORY']

# Setup web routes when the node is loaded
setup_web_routes()

# Specify the web directory for JavaScript files
WEB_DIRECTORY = os.path.join(os.path.dirname(__file__), "js") 