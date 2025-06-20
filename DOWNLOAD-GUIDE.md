# 📥 Download Funkcionalita - Kompletní návod

## 🎯 Přehled

Data Manager nyní podporuje **stahování souborů a složek** přímo z webového rozhraní! Můžete stahovat jednotlivé soubory nebo celé adresáře jako ZIP archivy.

## ✨ Nové funkce

### 📥 Stahování souborů
- **Jednotlivé soubory**: Přímé stažení s originálním názvem
- **Automatická detekce typu**: Správné MIME typy pro všechny formáty
- **Rychlé stahování**: Efektivní stream bez kopírování do paměti

### 📦 Stahování složek
- **ZIP archivy**: Celé složky se stáhnou jako ZIP soubory
- **Zachování struktury**: Všechny podsložky a soubory zůstávají organizované
- **Automatické pojmenování**: ZIP soubor má název podle složky

### 🔒 Bezpečnost
- **Validace cest**: Pouze povolené adresáře jsou přístupné
- **Ochrana systému**: Nemožnost stáhnout systémové soubory
- **Role-based přístup**: Funguje pro admin i user kontejnery

## 🎮 Použití

### V Data Manager UI

1. **Otevřete Data Manager**:
   - Admin: http://localhost:8190/data-manager
   - User: http://localhost:8191/data-manager
   - Nebo použijte bookmarklet/Chrome extension

2. **Procházejte soubory**:
   - Rozbalte sekce (Models, Custom Nodes, Input, Output)
   - Najděte soubor nebo složku, kterou chcete stáhnout

3. **Stáhněte obsah**:
   - **📥 Soubor**: Klikněte na modré tlačítko 📥 vedle souboru
   - **📦 Složka**: Klikněte na modré tlačítko 📦 vedle složky

### Příklad workflow

```
1. Otevřete Data Manager
2. Rozbalte "Output" sekci
3. Najděte vygenerovaný obrázek
4. Klikněte 📥 tlačítko
5. Soubor se stáhne do Downloads složky
```

## 🔧 API Endpointy

### Stahování souboru
```bash
GET /api/download?path=<relativní_cesta>

# Příklady:
curl "http://localhost:8190/api/download?path=output/image.png" -o image.png
curl "http://localhost:8190/api/download?path=models/checkpoints/model.safetensors" -o model.safetensors
```

### Stahování složky (ZIP)
```bash
GET /api/download-dir?path=<relativní_cesta>

# Příklady:
curl "http://localhost:8190/api/download-dir?path=output/my_images" -o my_images.zip
curl "http://localhost:8190/api/download-dir?path=models/loras" -o loras.zip
```

## 📂 Podporované adresáře

### ✅ Dostupné pro download:
- **📤 output/**: Vygenerované obrázky a výsledky
- **📥 input/**: Vstupní soubory pro workflows  
- **🎯 models/**: Všechny typy modelů
  - `checkpoints/` - Hlavní modely
  - `loras/` - LoRA modely
  - `vae/` - VAE modely
  - `controlnet/` - ControlNet modely
  - `embeddings/` - Textual Inversion
  - `upscale_models/` - Upscale modely
- **🔧 custom_nodes/**: Custom rozšíření

### ❌ Omezené přístup:
- Systémové soubory mimo `/app/`
- Konfigurace kontejnerů
- Privátní klíče a hesla

## 🎯 Praktické použití

### Pro Administrátory
```bash
# Zálohování modelů
1. Otevřete Data Manager
2. Jděte do Models > checkpoints
3. Klikněte 📦 u složky checkpoints
4. Stáhne se checkpoints.zip s všemi modely

# Export custom nodes
1. Jděte do Custom Nodes
2. Klikněte 📦 u konkrétního node
3. Stáhne se ZIP s kompletním node včetně kódu
```

### Pro Uživatele
```bash
# Stažení vygenerovaných obrázků
1. Otevřete Data Manager
2. Jděte do Output
3. Klikněte 📥 u konkrétního obrázku
4. Nebo 📦 u celé složky s obrázky

# Získání workflow výsledků
1. Najděte složku s vaším workflow
2. Klikněte 📦 pro stažení všech výsledků jako ZIP
```

## 🔍 Technické detaily

### Implementace
- **Backend**: Python aiohttp s FileResponse
- **Frontend**: JavaScript Fetch API s Blob handling
- **ZIP**: Python shutil.make_archive pro komprimaci
- **Cleanup**: Automatické mazání dočasných souborů

### Performance
- **Streaming**: Soubory se streamují bez načítání do paměti
- **Async**: Neblokující operace pro lepší responsivitu
- **Compression**: ZIP komprese šetří bandwidth

### Bezpečnost
```python
# Validace cest
allowed_paths = ['/app/models', '/app/output', '/app/input', '/app/custom_nodes']
file_path.relative_to(allowed_path)  # Vyhodí ValueError pokud není povoleno

# MIME type detection
mime_type = mimetypes.guess_type(file_path)
```

## 🧪 Testování

### Automatické testy
```bash
# Spusťte test script
./test-download.sh

# Testuje:
# ✅ File download API
# ✅ Directory download API  
# ✅ Security restrictions
# ✅ MIME type detection
# ✅ ZIP archive creation
# ✅ Both admin and user containers
```

### Manuální testování
```bash
# Test file download
curl -f "http://localhost:8190/api/download?path=output/test.png" -o test.png

# Test directory download
curl -f "http://localhost:8190/api/download-dir?path=output/folder" -o folder.zip

# Test security (should fail)
curl "http://localhost:8190/api/download?path=../etc/passwd"
```

## 🎨 UI Komponenty

### Tlačítka
- **📥 Download souboru**: Modré tlačítko s hover efektem
- **📦 Download složky**: Modré tlačítko s ZIP ikonou
- **Tooltips**: "Download file" / "Download as ZIP"

### Styling
```css
.download-btn {
    background: #2196F3;
    color: white;
    margin-right: 4px;
}

.download-btn:hover {
    background: #42A5F5;
    transform: translateY(-1px);
}
```

## 📋 Checklista funkcí

### ✅ Implementováno
- [x] File download API endpoint
- [x] Directory download API endpoint  
- [x] UI tlačítka pro download
- [x] JavaScript download handling
- [x] Security path validation
- [x] MIME type detection
- [x] ZIP archive creation
- [x] Temporary file cleanup
- [x] Error handling
- [x] Progress feedback
- [x] Test suite

### 🔄 Možná vylepšení
- [ ] Progress bar pro velké soubory
- [ ] Batch download více souborů
- [ ] Resume capability pro přerušené downloads
- [ ] Compression level options
- [ ] Download history/log

## 🎉 Závěr

Download funkcionalita je nyní plně integrována do Data Manager! Poskytuje:

- **🎯 Jednoduché použití**: Jen klikněte na tlačítko
- **🔒 Bezpečné**: Validované cesty a přístupy
- **⚡ Rychlé**: Efektivní streaming a compression
- **🎨 Intuitivní**: Jasné ikony a tooltips
- **🧪 Testované**: Kompletní test suite

**Začněte používat download funkcionalitu už dnes!** 🚀 