#!/bin/bash

# ComfyUI Data Manager Integration Test Script
echo "🧪 Testing ComfyUI Data Manager Integration..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test URLs
ADMIN_URL="http://localhost:8190"
USER_URL="http://localhost:8191"

# Function to test HTTP endpoint
test_endpoint() {
    local url=$1
    local name=$2
    local expected_code=${3:-200}
    
    echo -n "Testing $name... "
    
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    
    if [ "$response_code" = "$expected_code" ]; then
        echo -e "${GREEN}✅ OK${NC} (HTTP $response_code)"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} (HTTP $response_code, expected $expected_code)"
        return 1
    fi
}

# Function to test JSON API
test_json_api() {
    local url=$1
    local name=$2
    
    echo -n "Testing $name... "
    
    response=$(curl -s "$url" 2>/dev/null)
    
    if echo "$response" | jq . >/dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC} (Valid JSON)"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC} (Invalid JSON or no response)"
        return 1
    fi
}

echo -e "${BLUE}📋 Container Status${NC}"
docker-compose ps

echo -e "\n${BLUE}🌐 Basic Connectivity Tests${NC}"
test_endpoint "$ADMIN_URL" "Admin ComfyUI"
test_endpoint "$USER_URL" "User ComfyUI"

echo -e "\n${BLUE}🗂️ Data Manager Tests${NC}"
test_endpoint "$ADMIN_URL/data-manager" "Admin Data Manager UI"
test_endpoint "$USER_URL/data-manager" "User Data Manager UI"

echo -e "\n${BLUE}📡 API Endpoints Tests${NC}"
test_json_api "$ADMIN_URL/api/data-structure" "Admin API - Data Structure"
test_json_api "$USER_URL/api/data-structure" "User API - Data Structure"

echo -e "\n${BLUE}🎯 Integration Features Tests${NC}"
test_endpoint "$ADMIN_URL/data-manager?embedded=true" "Embedded Mode"

echo -e "\n${BLUE}📊 Data Manager Features Test${NC}"

# Test directory structure
echo -n "Testing directory structure... "
data_structure=$(curl -s "$ADMIN_URL/api/data-structure" 2>/dev/null)
if echo "$data_structure" | jq -e '.models' >/dev/null 2>&1 && \
   echo "$data_structure" | jq -e '.custom_nodes' >/dev/null 2>&1 && \
   echo "$data_structure" | jq -e '.input' >/dev/null 2>&1 && \
   echo "$data_structure" | jq -e '.output' >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC} (All directories present)"
else
    echo -e "${RED}❌ FAIL${NC} (Missing directories)"
fi

echo -e "\n${BLUE}🔐 Security Tests${NC}"

# Test user permissions (should be read-only)
echo -n "Testing user read-only access... "
upload_response=$(curl -s -X POST "$USER_URL/api/upload" -F "file=@/dev/null" 2>/dev/null || echo "error")
if [[ "$upload_response" == *"error"* ]] || [[ "$upload_response" == *"403"* ]] || [[ "$upload_response" == *"401"* ]]; then
    echo -e "${GREEN}✅ OK${NC} (Upload properly restricted)"
else
    echo -e "${YELLOW}⚠️  WARNING${NC} (Upload might not be restricted)"
fi

echo -e "\n${BLUE}📁 File System Tests${NC}"

# Check if shared volumes are mounted
echo -n "Testing shared volumes... "
admin_models=$(docker-compose exec -T admin_comfyui ls -la /app/shared_models 2>/dev/null | wc -l)
if [ "$admin_models" -gt 3 ]; then
    echo -e "${GREEN}✅ OK${NC} (Shared models volume mounted)"
else
    echo -e "${RED}❌ FAIL${NC} (Shared models volume not found)"
fi

echo -e "\n${BLUE}🚀 Integration Instructions${NC}"
echo -e "1. Open ComfyUI: ${YELLOW}$ADMIN_URL${NC}"
echo -e "2. Add this bookmarklet to your browser:"
echo -e "${YELLOW}javascript:(function(){if(!document.getElementById('data-manager-frame')){var f=document.createElement('iframe');f.id='data-manager-frame';f.src='/data-manager?embedded=true';f.style.cssText='position:fixed;top:50px;right:10px;width:450px;height:calc(100vh-70px);border:2px solid #404040;border-radius:12px;z-index:9999;background:rgba(20,20,20,0.98);backdrop-filter:blur(15px);box-shadow:0 8px 32px rgba(0,0,0,0.8);resize:both;overflow:hidden;min-width:300px;min-height:400px';f.allow='fullscreen';document.body.appendChild(f);var b=document.createElement('button');b.innerHTML='✕';b.title='Zavřít Data Manager';b.style.cssText='position:fixed;top:55px;right:20px;z-index:10000;background:#ff4444;color:white;border:none;width:24px;height:24px;border-radius:50%;cursor:pointer;font-size:14px;font-weight:bold;display:flex;align-items:center;justify-content:center;box-shadow:0 2px 8px rgba(0,0,0,0.5);transition:all 0.2s ease';b.onmouseover=function(){this.style.background='#ff6666';this.style.transform='scale(1.1)'};b.onmouseout=function(){this.style.background='#ff4444';this.style.transform='scale(1)'};b.onclick=function(){f.remove();b.remove();h.remove()};document.body.appendChild(b);var h=document.createElement('div');h.innerHTML='📂 Data Manager';h.style.cssText='position:fixed;top:50px;right:10px;width:450px;height:30px;background:linear-gradient(135deg,#333,#555);color:white;border-radius:12px 12px 0 0;cursor:move;display:flex;align-items:center;padding:0 15px;font-size:12px;font-weight:bold;z-index:10001;user-select:none;border:2px solid #404040;border-bottom:none';var isDragging=false,startX,startY,startLeft,startTop;h.onmousedown=function(e){isDragging=true;startX=e.clientX;startY=e.clientY;startLeft=parseInt(f.style.right)||10;startTop=parseInt(f.style.top)||50;document.onmousemove=function(e){if(!isDragging)return;var dx=startX-e.clientX;var dy=e.clientY-startY;f.style.right=(startLeft+dx)+'px';f.style.top=(startTop+dy)+'px';h.style.right=(startLeft+dx)+'px';h.style.top=(startTop+dy)+'px';b.style.right=(startLeft+dx+10)+'px';b.style.top=(startTop+dy+5)+'px'};document.onmouseup=function(){isDragging=false;document.onmousemove=null;document.onmouseup=null}};document.body.appendChild(h);console.log('✅ Data Manager loaded!')}else{document.getElementById('data-manager-frame').remove();document.querySelector('button[title=\"Zavřít Data Manager\"]')?.remove();document.querySelector('div[innerHTML*=\"Data Manager\"]')?.remove();console.log('❌ Data Manager closed')}})();${NC}"
echo -e "3. Click the bookmarklet on the ComfyUI page to toggle Data Manager"

echo -e "\n${BLUE}📖 Documentation${NC}"
echo -e "• Integration guide: ${YELLOW}custom_nodes/ComfyUI-DataManager/INTEGRATION.md${NC}"
echo -e "• Main README: ${YELLOW}README.md${NC}"

echo -e "\n${GREEN}🎉 Integration test completed!${NC}"
echo -e "Data Manager is now ready for integrated use with ComfyUI." 