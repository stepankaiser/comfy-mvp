# 🗂️ ComfyUI Data Manager

A comprehensive file management system for ComfyUI that provides drag & drop functionality, directory browsing, and seamless integration with the ComfyUI interface.

## ✨ Features

### 🎯 **Core Functionality**
- **Directory Browser**: View and navigate through all ComfyUI data directories
- **Drag & Drop Upload**: Simply drag files into the interface to upload
- **File Management**: Delete files and folders with confirmation
- **Real-time Updates**: Automatic refresh after operations
- **Progress Tracking**: Visual upload progress indicators

### 🖥️ **Interface Options**
- **Floating Widget**: Compact side panel that can be dragged around
- **Full-Screen Dialog**: Large modal for detailed file management
- **ComfyUI Integration**: Menu button and keyboard shortcuts
- **Responsive Design**: Works on desktop and mobile devices

### 📁 **Supported Directories**
- **🎯 Models**: All model types (checkpoints, LoRA, VAE, etc.)
- **🔧 Custom Nodes**: Extensions and custom functionality
- **📥 Input**: Input files for workflows
- **📤 Output**: Generated images and results

## 🚀 Quick Start

### Access Methods

1. **Menu Button**: Click "🗂️ Data Manager" in the ComfyUI menu
2. **Keyboard Shortcut**: Press `Ctrl+D` to toggle the widget
3. **Direct URL**: Visit `/data-manager` endpoint

### Basic Usage

1. **View Files**: Browse through the directory tree
2. **Upload Files**: 
   - Drag files onto the drop zone
   - Or click the drop zone to select files
3. **Delete Files**: Click the 🗑️ button next to any file
4. **Refresh**: Click the 🔄 button to update the view

## 🎨 User Interface

### Floating Widget
- **Position**: Top-right corner by default
- **Draggable**: Click and drag the header to move
- **Resizable**: Resize by dragging corners
- **Minimize**: Click the `−` button
- **Fullscreen**: Click the `⛶` button for full dialog

### Directory Structure
```
🎯 Models/
├── checkpoints/
├── loras/
├── vae/
└── ...

🔧 Custom Nodes/
├── ComfyUI-Manager/
├── ComfyUI-DataManager/
└── ...

📥 Input/
└── (user uploaded files)

📤 Output/
└── (generated images)
```

## 🔧 Technical Details

### API Endpoints

- `GET /data-manager` - Main UI interface
- `GET /api/data-structure` - Get directory structure JSON
- `POST /api/upload` - Upload files
- `DELETE /api/delete` - Delete files/folders
- `POST /api/create-dir` - Create directories

### File Upload
- **Method**: Multipart form data
- **Target Selection**: Click directories to set upload target
- **Progress**: Real-time upload progress display
- **Error Handling**: Clear error messages for failed uploads

### Security Features
- **Path Validation**: Only allows access to designated directories
- **File Type Checking**: MIME type detection
- **Size Limits**: Configurable upload size limits
- **Permission Checks**: Respects container role permissions

## 🛠️ Installation

The Data Manager is automatically included in the ComfyUI Golden Image system. No manual installation required.

### Manual Installation (if needed)

1. Copy the `ComfyUI-DataManager` folder to your `custom_nodes` directory
2. Install dependencies: `pip install -r requirements.txt`
3. Restart ComfyUI

## ⚙️ Configuration

### Container Roles
- **Admin**: Full read/write access to all directories
- **User**: Read-only access (upload disabled)

### Customization
Edit `web/data_manager.css` to customize the appearance:
- Colors and themes
- Layout and spacing
- Responsive breakpoints

## 🔍 Troubleshooting

### Common Issues

**Widget not appearing**
- Check browser console for JavaScript errors
- Ensure ComfyUI is fully loaded
- Try refreshing the page

**Upload failures**
- Check file permissions
- Verify disk space
- Check container role permissions

**API errors**
- Ensure all dependencies are installed
- Check ComfyUI server logs
- Verify network connectivity

### Debug Mode
Add `?debug=1` to the URL for additional logging:
```
http://localhost:8190/data-manager?debug=1
```

## 🎯 Use Cases

### For Administrators
- **Model Management**: Upload and organize model files
- **Custom Node Installation**: Install and manage extensions
- **System Maintenance**: Clean up old files and organize structure
- **Backup Management**: Prepare files for S3 sync

### For Users
- **File Discovery**: Browse available models and resources
- **Input Management**: Upload images and other input files
- **Output Review**: View and manage generated content
- **Resource Planning**: See what's available before creating workflows

## 🔄 Integration with Golden Image System

The Data Manager seamlessly integrates with the Golden Image architecture:

- **Admin Container**: Full management capabilities
- **User Container**: Read-only browsing
- **S3 Sync**: Files are automatically synchronized to cloud storage
- **Shared Volumes**: Changes are immediately visible across containers

## 🚀 Advanced Features

### Keyboard Shortcuts
- `Ctrl+D` - Toggle Data Manager widget
- `Escape` - Close full-screen dialog
- `F5` - Refresh directory structure

### Drag & Drop Enhancements
- **Visual Feedback**: Drop zones highlight on drag over
- **Multi-file Upload**: Select multiple files at once
- **Directory Upload**: Drag entire folders (browser dependent)

### Mobile Support
- **Touch-friendly**: Large touch targets
- **Responsive Layout**: Adapts to screen size
- **Gesture Support**: Swipe to navigate

## 📈 Performance

### Optimization Features
- **Lazy Loading**: Directory contents loaded on demand
- **Caching**: Structure cached for faster subsequent loads
- **Efficient API**: Minimal data transfer
- **Background Operations**: Non-blocking file operations

### Scalability
- **Large Directories**: Handles thousands of files
- **Concurrent Uploads**: Multiple file uploads
- **Memory Efficient**: Streaming file operations
- **Network Resilient**: Retry logic for failed operations

## 🔐 Security

### Access Control
- **Role-based Permissions**: Admin vs User access
- **Path Restrictions**: Limited to designated directories
- **File Validation**: Safe file type checking
- **CSRF Protection**: Secure API endpoints

### Best Practices
- Regular cleanup of temporary files
- Monitor disk usage
- Review uploaded content
- Maintain access logs

## 🤝 Contributing

To contribute to the Data Manager:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Development Setup
```bash
# Install development dependencies
pip install -r requirements-dev.txt

# Run tests
python -m pytest tests/

# Start development server
python -m http.server 8000
```

## 📄 License

This project is part of the ComfyUI Golden Image system and follows the same licensing terms.

---

**🎉 Happy File Managing!** 

For support and questions, please open an issue in the repository. 