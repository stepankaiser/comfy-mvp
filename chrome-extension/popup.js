document.addEventListener('DOMContentLoaded', function() {
    const toggleBtn = document.getElementById('toggleBtn');
    
    toggleBtn.addEventListener('click', function() {
        chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
            chrome.scripting.executeScript({
                target: {tabId: tabs[0].id},
                function: toggleDataManager
            });
        });
    });
});

function toggleDataManager() {
    if (!document.getElementById('data-manager-frame')) {
        // Create larger iframe with improved styling
        const frame = document.createElement('iframe');
        frame.id = 'data-manager-frame';
        frame.src = '/data-manager?embedded=true';
        frame.style.cssText = 'position:fixed;top:50px;right:10px;width:450px;height:calc(100vh-70px);border:2px solid #404040;border-radius:12px;z-index:9999;background:rgba(20,20,20,0.98);backdrop-filter:blur(15px);box-shadow:0 8px 32px rgba(0,0,0,0.8);resize:both;overflow:hidden;min-width:300px;min-height:400px';
        frame.allow = 'fullscreen';
        document.body.appendChild(frame);
        
        // Create improved close button
        const closeBtn = document.createElement('button');
        closeBtn.innerHTML = '✕';
        closeBtn.title = 'Zavřít Data Manager';
        closeBtn.style.cssText = 'position:fixed;top:55px;right:20px;z-index:10000;background:#ff4444;color:white;border:none;width:24px;height:24px;border-radius:50%;cursor:pointer;font-size:14px;font-weight:bold;display:flex;align-items:center;justify-content:center;box-shadow:0 2px 8px rgba(0,0,0,0.5);transition:all 0.2s ease';
        closeBtn.onmouseover = function() { this.style.background = '#ff6666'; this.style.transform = 'scale(1.1)'; };
        closeBtn.onmouseout = function() { this.style.background = '#ff4444'; this.style.transform = 'scale(1)'; };
        closeBtn.onclick = () => { frame.remove(); closeBtn.remove(); header.remove(); };
        document.body.appendChild(closeBtn);
        
        // Create drag handle
        const header = document.createElement('div');
        header.innerHTML = '📂 Data Manager';
        header.style.cssText = 'position:fixed;top:50px;right:10px;width:450px;height:30px;background:linear-gradient(135deg,#333,#555);color:white;border-radius:12px 12px 0 0;cursor:move;display:flex;align-items:center;padding:0 15px;font-size:12px;font-weight:bold;z-index:10001;user-select:none;border:2px solid #404040;border-bottom:none';
        
        // Make draggable
        let isDragging = false, startX, startY, startLeft, startTop;
        header.onmousedown = function(e) {
            isDragging = true;
            startX = e.clientX;
            startY = e.clientY;
            startLeft = parseInt(frame.style.right) || 10;
            startTop = parseInt(frame.style.top) || 50;
            
            document.onmousemove = function(e) {
                if (!isDragging) return;
                const dx = startX - e.clientX;
                const dy = e.clientY - startY;
                frame.style.right = (startLeft + dx) + 'px';
                frame.style.top = (startTop + dy) + 'px';
                header.style.right = (startLeft + dx) + 'px';
                header.style.top = (startTop + dy) + 'px';
                closeBtn.style.right = (startLeft + dx + 10) + 'px';
                closeBtn.style.top = (startTop + dy + 5) + 'px';
            };
            
            document.onmouseup = function() {
                isDragging = false;
                document.onmousemove = null;
                document.onmouseup = null;
            };
        };
        document.body.appendChild(header);
        
        console.log('✅ Data Manager loaded - resizable and draggable!');
    } else {
        document.getElementById('data-manager-frame')?.remove();
        document.querySelector('button[title="Zavřít Data Manager"]')?.remove();
        document.querySelector('div[innerHTML*="Data Manager"]')?.remove();
        console.log('❌ Data Manager closed');
    }
} 