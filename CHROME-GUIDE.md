# 🌐 ComfyUI Data Manager - Návod pro Chrome

## 🚀 Rychlý start (5 minut)

### Krok 1: Otevřete ComfyUI
```
http://localhost:8190
```

### Krok 2: Vytvořte bookmarklet

**📌 Nejjednodušší způsob:**

1. **Zkopírujte tento kód** (celý):
```javascript
javascript:(function(){if(!document.getElementById('data-manager-frame')){var f=document.createElement('iframe');f.id='data-manager-frame';f.src='/data-manager?embedded=true';f.style.cssText='position:fixed;top:50px;right:10px;width:450px;height:calc(100vh-70px);border:2px solid #404040;border-radius:12px;z-index:9999;background:rgba(20,20,20,0.98);backdrop-filter:blur(15px);box-shadow:0 8px 32px rgba(0,0,0,0.8);resize:both;overflow:hidden;min-width:300px;min-height:400px';f.allow='fullscreen';document.body.appendChild(f);var b=document.createElement('button');b.innerHTML='✕';b.title='Zavřít Data Manager';b.style.cssText='position:fixed;top:55px;right:20px;z-index:10000;background:#ff4444;color:white;border:none;width:24px;height:24px;border-radius:50%;cursor:pointer;font-size:14px;font-weight:bold;display:flex;align-items:center;justify-content:center;box-shadow:0 2px 8px rgba(0,0,0,0.5);transition:all 0.2s ease';b.onmouseover=function(){this.style.background='#ff6666';this.style.transform='scale(1.1)'};b.onmouseout=function(){this.style.background='#ff4444';this.style.transform='scale(1)'};b.onclick=function(){f.remove();b.remove();h.remove()};document.body.appendChild(b);var h=document.createElement('div');h.innerHTML='📂 Data Manager';h.style.cssText='position:fixed;top:50px;right:10px;width:450px;height:30px;background:linear-gradient(135deg,#333,#555);color:white;border-radius:12px 12px 0 0;cursor:move;display:flex;align-items:center;padding:0 15px;font-size:12px;font-weight:bold;z-index:10001;user-select:none;border:2px solid #404040;border-bottom:none';var isDragging=false,startX,startY,startLeft,startTop;h.onmousedown=function(e){isDragging=true;startX=e.clientX;startY=e.clientY;startLeft=parseInt(f.style.right)||10;startTop=parseInt(f.style.top)||50;document.onmousemove=function(e){if(!isDragging)return;var dx=startX-e.clientX;var dy=e.clientY-startY;f.style.right=(startLeft+dx)+'px';f.style.top=(startTop+dy)+'px';h.style.right=(startLeft+dx)+'px';h.style.top=(startTop+dy)+'px';b.style.right=(startLeft+dx+10)+'px';b.style.top=(startTop+dy+5)+'px'};document.onmouseup=function(){isDragging=false;document.onmousemove=null;document.onmouseup=null}};document.body.appendChild(h);console.log('✅ Data Manager loaded!')}else{document.getElementById('data-manager-frame').remove();document.querySelector('button[title="Zavřít Data Manager"]')?.remove();document.querySelector('div[innerHTML*="Data Manager"]')?.remove();console.log('❌ Data Manager closed')}})();
```

2. **Stiskněte** `Ctrl+Shift+O` (Bookmark Manager)

3. **Klikněte** na "Add new bookmark" (tři tečky → Add new bookmark)

4. **Vyplňte:**
   - **Name**: `📂 Data Manager`
   - **URL**: Vložte zkopírovaný kód

5. **Klikněte** "Save"

### Krok 3: Použijte bookmarklet

1. **Jděte na** ComfyUI stránku: `http://localhost:8190`
2. **Klikněte** na bookmarklet "📂 Data Manager" v bookmarks bar
3. **Hotovo!** Data Manager se zobrazí jako velký panel vpravo

## ✨ Co nového v vylepšené verzi:

### 🔧 Vylepšení:
- **📏 Větší velikost**: 450px široký (místo 350px)
- **🎯 Resize možnost**: Můžete měnit velikost tažením za roh
- **🖱️ Drag & Drop**: Přetahování za title bar
- **🎨 Lepší design**: Gradient header, rounded corners
- **🔴 Lepší close tlačítko**: Kruhové s hover efekty
- **📱 Responzivní**: Minimální velikost 300x400px

### 🎮 Ovládání:
- **🖱️ Přetahování**: Uchopte za "📂 Data Manager" header
- **📏 Změna velikosti**: Tažení za pravý dolní roh
- **✕ Zavření**: Kliknutí na červené tlačítko
- **🔄 Toggle**: Opětovné kliknutí na bookmarklet

## 🎯 Alternativní metody:

### Metoda 2: Bookmarks Bar (rychlejší přístup)

1. **Zobrazte bookmarks bar**: `Ctrl+Shift+B`
2. **Pravý klik** na bookmarks bar → "Add page..."
3. **Vyplňte** stejné údaje jako výše
4. **Bookmarklet** bude viditelný přímo v horní liště

### Metoda 3: Developer Console

1. **Otevřete konzoli**: `F12` → Console tab
2. **Vložte a spusťte**:
```javascript
if (!document.getElementById('data-manager-frame')) {
    var f=document.createElement('iframe');
    f.id='data-manager-frame';
    f.src='/data-manager?embedded=true';
    f.style.cssText='position:fixed;top:50px;right:10px;width:450px;height:calc(100vh-70px);border:2px solid #404040;border-radius:12px;z-index:9999;background:rgba(20,20,20,0.98);backdrop-filter:blur(15px);box-shadow:0 8px 32px rgba(0,0,0,0.8);resize:both;overflow:hidden;min-width:300px;min-height:400px';
    f.allow='fullscreen';
    document.body.appendChild(f);
    
    var b=document.createElement('button');
    b.innerHTML='✕';
    b.title='Zavřít Data Manager';
    b.style.cssText='position:fixed;top:55px;right:20px;z-index:10000;background:#ff4444;color:white;border:none;width:24px;height:24px;border-radius:50%;cursor:pointer;font-size:14px;font-weight:bold;display:flex;align-items:center;justify-content:center;box-shadow:0 2px 8px rgba(0,0,0,0.5)';
    b.onclick=function(){f.remove();b.remove();h.remove()};
    document.body.appendChild(b);
    
    var h=document.createElement('div');
    h.innerHTML='📂 Data Manager';
    h.style.cssText='position:fixed;top:50px;right:10px;width:450px;height:30px;background:linear-gradient(135deg,#333,#555);color:white;border-radius:12px 12px 0 0;cursor:move;display:flex;align-items:center;padding:0 15px;font-size:12px;font-weight:bold;z-index:10001;user-select:none;border:2px solid #404040;border-bottom:none';
    document.body.appendChild(h);
    
    console.log('✅ Data Manager loaded!');
}
```

## 🔧 Tipy pro Chrome:

### ⌨️ Užitečné zkratky:
- `Ctrl+Shift+B` - Zobrazit/skrýt bookmarks bar
- `Ctrl+Shift+O` - Bookmark manager
- `F12` - Developer tools
- `Ctrl+Shift+I` - Developer console

### 🎨 Přizpůsobení:
- **Velikost**: Změňte `width:450px` na požadovanou šířku
- **Pozice**: Upravte `top:50px` a `right:10px`
- **Barvy**: Změňte `#404040` (border) a `#ff4444` (close button)

### 🛠️ Řešení problémů:

**Data Manager se nezobrazuje:**
1. Zkontrolujte, že jste na `http://localhost:8190`
2. Obnovte stránku (F5)
3. Zkontrolujte konzoli (F12) pro chyby

**Bookmarklet nefunguje:**
1. Zkontrolujte, že kód začíná `javascript:`
2. Ujistěte se, že jste zkopírovali celý kód
3. Zkuste metodu přes konzoli

**Iframe je prázdný:**
1. Zkontrolujte, že kontejnery běží: `docker-compose ps`
2. Otestujte přímý přístup: `http://localhost:8190/data-manager`

## 🎉 Výsledek:

Po úspěšném nastavení budete mít:
- ✅ **Velký, použitelný Data Manager** (450x vysoký)
- ✅ **Drag & drop funkcionalitu** pro soubory
- ✅ **Přetahovatelné okno** s resize možností
- ✅ **Jeden klik toggle** pro zobrazení/skrytí
- ✅ **Plnou integraci** do ComfyUI rozhraní

**Doporučení**: Přidejte bookmarklet do bookmarks bar pro nejrychlejší přístup! 🚀

---

## 🔧 Chrome Extension v2.0 (Vylepšená verze)

### 🚀 Instalace Chrome Extension:

1. **Otevřete Chrome** a jděte na `chrome://extensions/`
2. **Zapněte "Developer mode"** (vpravo nahoře)
3. **Klikněte "Load unpacked"**
4. **Vyberte složku** `chrome-extension/`
5. **Extension se přidá** do Chrome

### ✨ Nové funkce v extension v2.0:

- **🎯 Automatické tlačítko**: Plovoucí 📂 tlačítko se objeví na ComfyUI stránkách
- **⌨️ Klávesová zkratka**: `Ctrl+Shift+D` pro toggle Data Manager
- **🎨 Moderní popup**: Vylepšený design s gradient pozadím
- **📱 Automatické načtení**: Extension se aktivuje na localhost:8190 a 8191
- **🔄 Inteligentní toggle**: Automatické rozpoznání stavu Data Manageru
- **📏 Větší velikost**: 450px široký Data Manager
- **🖱️ Drag & Drop**: Přetahovatelné okno s resize funkcí

### 🎮 Způsoby použití:

1. **Extension popup**: Klikněte na ikonu extension v toolbar
2. **Plovoucí tlačítko**: Automaticky se objeví na ComfyUI stránkách (vpravo nahoře)
3. **Klávesová zkratka**: `Ctrl+Shift+D` kdekoli na ComfyUI stránce

### 🎯 Výhody extension oproti bookmarklet:

- ✅ **Automatické načtení** na ComfyUI stránkách
- ✅ **Klávesová zkratka** funguje vždy
- ✅ **Plovoucí tlačítko** pro rychlý přístup
- ✅ **Moderní UI** s vylepšeným designem
- ✅ **Žádné kopírování kódu** - jen instalace

### 📂 Soubory extension:

```
chrome-extension/
├── manifest.json     # Konfigurace extension
├── popup.html        # UI popup okna
├── popup.js          # Logika popup
└── content.js        # Automatické funkce na stránkách
```

**Pro pokročilé uživatele doporučujeme Chrome Extension, pro ostatní bookmarklet!** 🎯 