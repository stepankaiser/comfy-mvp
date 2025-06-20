// Improved ComfyUI Data Manager Bookmarklet
javascript:(function(){
    if(!document.getElementById('data-manager-frame')){
        // Create larger iframe
        var f=document.createElement('iframe');
        f.id='data-manager-frame';
        f.src='/data-manager?embedded=true';
        f.style.cssText='position:fixed;top:50px;right:10px;width:450px;height:calc(100vh-70px);border:2px solid #404040;border-radius:12px;z-index:9999;background:rgba(20,20,20,0.98);backdrop-filter:blur(15px);box-shadow:0 8px 32px rgba(0,0,0,0.8);resize:both;overflow:hidden;min-width:300px;min-height:400px';
        f.allow='fullscreen';
        document.body.appendChild(f);
        
        // Create improved close button
        var b=document.createElement('button');
        b.innerHTML='✕';
        b.title='Zavřít Data Manager';
        b.style.cssText='position:fixed;top:55px;right:20px;z-index:10000;background:#ff4444;color:white;border:none;width:24px;height:24px;border-radius:50%;cursor:pointer;font-size:14px;font-weight:bold;display:flex;align-items:center;justify-content:center;box-shadow:0 2px 8px rgba(0,0,0,0.5);transition:all 0.2s ease';
        b.onmouseover=function(){this.style.background='#ff6666';this.style.transform='scale(1.1)'};
        b.onmouseout=function(){this.style.background='#ff4444';this.style.transform='scale(1)'};
        b.onclick=function(){f.remove();b.remove();h.remove()};
        document.body.appendChild(b);
        
        // Create drag handle
        var h=document.createElement('div');
        h.innerHTML='📂 Data Manager';
        h.style.cssText='position:fixed;top:50px;right:10px;width:450px;height:30px;background:linear-gradient(135deg,#333,#555);color:white;border-radius:12px 12px 0 0;cursor:move;display:flex;align-items:center;padding:0 15px;font-size:12px;font-weight:bold;z-index:10001;user-select:none;border:2px solid #404040;border-bottom:none';
        
        // Make draggable
        var isDragging=false,startX,startY,startLeft,startTop;
        h.onmousedown=function(e){
            isDragging=true;
            startX=e.clientX;
            startY=e.clientY;
            startLeft=parseInt(f.style.right)||10;
            startTop=parseInt(f.style.top)||50;
            document.onmousemove=function(e){
                if(!isDragging)return;
                var dx=startX-e.clientX;
                var dy=e.clientY-startY;
                f.style.right=(startLeft+dx)+'px';
                f.style.top=(startTop+dy)+'px';
                h.style.right=(startLeft+dx)+'px';
                h.style.top=(startTop+dy)+'px';
                b.style.right=(startLeft+dx+10)+'px';
                b.style.top=(startTop+dy+5)+'px';
            };
            document.onmouseup=function(){isDragging=false;document.onmousemove=null;document.onmouseup=null};
        };
        document.body.appendChild(h);
        
        // Add resize observer
        if(window.ResizeObserver){
            new ResizeObserver(function(){
                var rect=f.getBoundingClientRect();
                h.style.width=rect.width+'px';
                b.style.right=(parseInt(f.style.right)||10)+10+'px';
            }).observe(f);
        }
        
        console.log('✅ Data Manager loaded - resizable and draggable!');
    }else{
        document.getElementById('data-manager-frame').remove();
        document.querySelector('button[title="Zavřít Data Manager"]')?.remove();
        document.querySelector('div[innerHTML*="Data Manager"]')?.remove();
        console.log('❌ Data Manager closed');
    }
})(); 