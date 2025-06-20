#!/bin/bash

# Test script for ComfyUI Data Manager
echo "🧪 Testing ComfyUI Data Manager functionality..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
ADMIN_URL="http://localhost:8190"
USER_URL="http://localhost:8191"
TEST_FILE="test_model.txt"

# Helper functions
print_test() {
    echo -e "${BLUE}🔍 Testing: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

# Check if containers are running
check_containers() {
    print_test "Container status"
    
    if docker-compose ps | grep -q "admin_comfyui.*Up"; then
        print_success "Admin container is running"
    else
        print_error "Admin container is not running"
        return 1
    fi
    
    if docker-compose ps | grep -q "user_comfyui.*Up"; then
        print_success "User container is running"
    else
        print_error "User container is not running"
        return 1
    fi
}

# Test web endpoints
test_endpoints() {
    print_test "Web endpoints accessibility"
    
    # Test admin endpoints
    if curl -s -o /dev/null -w "%{http_code}" "$ADMIN_URL" | grep -q "200"; then
        print_success "Admin ComfyUI accessible"
    else
        print_error "Admin ComfyUI not accessible"
    fi
    
    if curl -s -o /dev/null -w "%{http_code}" "$ADMIN_URL/data-manager" | grep -q "200"; then
        print_success "Admin Data Manager accessible"
    else
        print_error "Admin Data Manager not accessible"
    fi
    
    # Test user endpoints
    if curl -s -o /dev/null -w "%{http_code}" "$USER_URL" | grep -q "200"; then
        print_success "User ComfyUI accessible"
    else
        print_error "User ComfyUI not accessible"
    fi
    
    if curl -s -o /dev/null -w "%{http_code}" "$USER_URL/data-manager" | grep -q "200"; then
        print_success "User Data Manager accessible"
    else
        print_error "User Data Manager not accessible"
    fi
}

# Test API endpoints
test_api_endpoints() {
    print_test "Data Manager API endpoints"
    
    # Test directory structure API
    if curl -s "$ADMIN_URL/api/data-structure" | jq . > /dev/null 2>&1; then
        print_success "Directory structure API working"
    else
        print_error "Directory structure API failed"
    fi
    
    # Test the same for user
    if curl -s "$USER_URL/api/data-structure" | jq . > /dev/null 2>&1; then
        print_success "User directory structure API working"
    else
        print_error "User directory structure API failed"
    fi
}

# Test file upload (admin only)
test_file_upload() {
    print_test "File upload functionality (admin only)"
    
    # Create a test file
    echo "This is a test model file" > "$TEST_FILE"
    
    # Test upload to admin
    upload_response=$(curl -s -X POST \
        -F "file=@$TEST_FILE" \
        -F "target_dir=models" \
        "$ADMIN_URL/api/upload")
    
    if echo "$upload_response" | jq -r '.success' | grep -q "true"; then
        print_success "File upload to admin successful"
        
        # Check if file appears in user container
        sleep 2
        user_structure=$(curl -s "$USER_URL/api/data-structure")
        if echo "$user_structure" | jq -r '.models' | grep -q "$TEST_FILE"; then
            print_success "Uploaded file visible in user container"
        else
            print_warning "Uploaded file not yet visible in user container (may need time to sync)"
        fi
    else
        print_error "File upload to admin failed: $upload_response"
    fi
    
    # Test upload to user (should fail)
    user_upload_response=$(curl -s -X POST \
        -F "file=@$TEST_FILE" \
        -F "target_dir=models" \
        "$USER_URL/api/upload" 2>/dev/null)
    
    if echo "$user_upload_response" | jq -r '.error' | grep -q "error\|failed"; then
        print_success "User upload correctly restricted"
    else
        print_warning "User upload restriction may not be working properly"
    fi
    
    # Cleanup
    rm -f "$TEST_FILE"
}

# Test directory structure
test_directory_structure() {
    print_test "Directory structure completeness"
    
    structure=$(curl -s "$ADMIN_URL/api/data-structure")
    
    # Check for expected directories
    if echo "$structure" | jq -r '.models' | grep -q "null\|{}"; then
        print_warning "Models directory appears empty"
    else
        print_success "Models directory structure available"
    fi
    
    if echo "$structure" | jq -r '.custom_nodes' | grep -q "null\|{}"; then
        print_warning "Custom nodes directory appears empty"
    else
        print_success "Custom nodes directory structure available"
    fi
    
    if echo "$structure" | jq -r '.input' | grep -q "null\|{}"; then
        print_success "Input directory initialized (empty is normal)"
    else
        print_success "Input directory structure available"
    fi
    
    if echo "$structure" | jq -r '.output' | grep -q "null\|{}"; then
        print_success "Output directory initialized (empty is normal)"
    else
        print_success "Output directory structure available"
    fi
}

# Test Data Manager integration in ComfyUI
test_comfyui_integration() {
    print_test "ComfyUI integration"
    
    # Check if Data Manager JavaScript is loaded
    admin_page=$(curl -s "$ADMIN_URL")
    if echo "$admin_page" | grep -q "data-manager\|DataManager"; then
        print_success "Data Manager integration detected in admin interface"
    else
        print_warning "Data Manager integration not clearly visible (may be loaded dynamically)"
    fi
    
    user_page=$(curl -s "$USER_URL")
    if echo "$user_page" | grep -q "data-manager\|DataManager"; then
        print_success "Data Manager integration detected in user interface"
    else
        print_warning "Data Manager integration not clearly visible (may be loaded dynamically)"
    fi
}

# Test shared volumes
test_shared_volumes() {
    print_test "Shared volumes functionality"
    
    # Check if shared volumes are mounted
    admin_models=$(docker-compose exec -T admin_comfyui ls -la /app/models 2>/dev/null | wc -l)
    user_models=$(docker-compose exec -T user_comfyui ls -la /app/models 2>/dev/null | wc -l)
    
    if [ "$admin_models" -gt 1 ] && [ "$user_models" -gt 1 ]; then
        print_success "Shared volumes properly mounted"
    else
        print_error "Shared volumes may not be properly mounted"
    fi
    
    # Check if both containers see the same content
    admin_count=$(docker-compose exec -T admin_comfyui find /app/models -type f 2>/dev/null | wc -l)
    user_count=$(docker-compose exec -T user_comfyui find /app/models -type f 2>/dev/null | wc -l)
    
    if [ "$admin_count" -eq "$user_count" ]; then
        print_success "Both containers see the same model files ($admin_count files)"
    else
        print_warning "File count mismatch: Admin=$admin_count, User=$user_count"
    fi
}

# Main test execution
main() {
    echo "🚀 Starting ComfyUI Data Manager tests..."
    echo "========================================"
    
    # Check prerequisites
    if ! command -v curl &> /dev/null; then
        print_error "curl is required for testing"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is required for testing"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "docker-compose is required for testing"
        exit 1
    fi
    
    # Run tests
    check_containers || exit 1
    sleep 5  # Give containers time to fully start
    
    test_endpoints
    test_api_endpoints
    test_directory_structure
    test_shared_volumes
    test_file_upload
    test_comfyui_integration
    
    echo ""
    echo "========================================"
    echo "🎉 Data Manager testing completed!"
    echo ""
    echo "📍 Access points:"
    echo "   Admin Data Manager: $ADMIN_URL/data-manager"
    echo "   User Data Manager:  $USER_URL/data-manager"
    echo ""
    echo "🔧 Manual testing suggestions:"
    echo "   1. Open Data Manager in browser"
    echo "   2. Try drag & drop file upload (admin only)"
    echo "   3. Browse directory structure"
    echo "   4. Test keyboard shortcut Ctrl+D"
    echo "   5. Try floating widget vs full-screen mode"
}

# Run main function
main "$@" 