import { app } from "../../../scripts/app.js";
import { ComfyDialog, $el } from "../../../scripts/ui.js";

class DataManagerDialog extends ComfyDialog {
    constructor() {
        super();
        this.element = $el("dialog", {
            id: "data-manager-dialog",
            parent: document.body,
        }, [
            $el("div.comfy-modal-content", [
                $el("div.comfy-modal-header", [
                    $el("span", { textContent: "🗂️ Data Manager" }),
                    $el("button.comfy-modal-close", {
                        onclick: () => this.close(),
                    }, ["×"])
                ]),
                $el("iframe", {
                    src: "/data-manager",
                    style: {
                        width: "100%",
                        height: "80vh",
                        border: "none",
                        borderRadius: "8px"
                    }
                })
            ])
        ]);
        
        this.element.style.cssText = `
            background: rgba(0, 0, 0, 0.8);
            border: none;
            border-radius: 12px;
            padding: 0;
            max-width: 90vw;
            max-height: 90vh;
            width: 1200px;
            height: 800px;
        `;
        
        this.element.querySelector('.comfy-modal-content').style.cssText = `
            background: #1a1a1a;
            border-radius: 12px;
            overflow: hidden;
            height: 100%;
            display: flex;
            flex-direction: column;
        `;
        
        this.element.querySelector('.comfy-modal-header').style.cssText = `
            background: #2d2d2d;
            padding: 15px 20px;
            border-bottom: 1px solid #404040;
            display: flex;
            justify-content: space-between;
            align-items: center;
            color: white;
            font-weight: 600;
        `;
        
        this.element.querySelector('.comfy-modal-close').style.cssText = `
            background: none;
            border: none;
            color: #888;
            font-size: 24px;
            cursor: pointer;
            padding: 0;
            width: 30px;
            height: 30px;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 6px;
        `;
    }

    show() {
        this.element.showModal();
        this.element.addEventListener("click", (event) => {
            if (event.target === this.element) {
                this.close();
            }
        });
    }

    close() {
        this.element.close();
    }
}

// Create floating data manager widget
class DataManagerWidget {
    constructor() {
        this.isVisible = false;
        this.isMinimized = false;
        this.createWidget();
        this.dialog = new DataManagerDialog();
    }

    createWidget() {
        // Create floating widget container
        this.widget = $el("div", {
            id: "data-manager-widget",
            style: {
                position: "fixed",
                top: "20px",
                right: "20px",
                width: "300px",
                height: "400px",
                background: "#1a1a1a",
                border: "1px solid #404040",
                borderRadius: "8px",
                zIndex: "1000",
                display: "none",
                flexDirection: "column",
                overflow: "hidden",
                boxShadow: "0 4px 20px rgba(0,0,0,0.5)"
            }
        }, [
            $el("div.widget-header", {
                style: {
                    background: "#2d2d2d",
                    padding: "10px 15px",
                    borderBottom: "1px solid #404040",
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    cursor: "move",
                    color: "white",
                    fontSize: "14px",
                    fontWeight: "600"
                }
            }, [
                $el("span", { textContent: "🗂️ Data Manager" }),
                $el("div", [
                    $el("button", {
                        textContent: "⛶",
                        style: {
                            background: "none",
                            border: "none",
                            color: "#888",
                            cursor: "pointer",
                            marginRight: "8px",
                            fontSize: "16px"
                        },
                        onclick: () => this.dialog.show()
                    }),
                    $el("button", {
                        textContent: "−",
                        style: {
                            background: "none",
                            border: "none",
                            color: "#888",
                            cursor: "pointer",
                            marginRight: "8px",
                            fontSize: "16px"
                        },
                        onclick: () => this.toggleMinimize()
                    }),
                    $el("button", {
                        textContent: "×",
                        style: {
                            background: "none",
                            border: "none",
                            color: "#888",
                            cursor: "pointer",
                            fontSize: "16px"
                        },
                        onclick: () => this.hide()
                    })
                ])
            ]),
            $el("div.widget-content", {
                style: {
                    flex: "1",
                    overflow: "hidden"
                }
            }, [
                $el("iframe", {
                    src: "/data-manager",
                    style: {
                        width: "100%",
                        height: "100%",
                        border: "none"
                    }
                })
            ])
        ]);

        document.body.appendChild(this.widget);
        this.makeDraggable();
    }

    makeDraggable() {
        const header = this.widget.querySelector('.widget-header');
        let isDragging = false;
        let startX, startY, startLeft, startTop;

        header.addEventListener('mousedown', (e) => {
            isDragging = true;
            startX = e.clientX;
            startY = e.clientY;
            startLeft = parseInt(this.widget.style.left || this.widget.offsetLeft);
            startTop = parseInt(this.widget.style.top || this.widget.offsetTop);
            
            document.addEventListener('mousemove', onMouseMove);
            document.addEventListener('mouseup', onMouseUp);
        });

        const onMouseMove = (e) => {
            if (!isDragging) return;
            
            const deltaX = e.clientX - startX;
            const deltaY = e.clientY - startY;
            
            this.widget.style.left = (startLeft + deltaX) + 'px';
            this.widget.style.top = (startTop + deltaY) + 'px';
            this.widget.style.right = 'auto';
        };

        const onMouseUp = () => {
            isDragging = false;
            document.removeEventListener('mousemove', onMouseMove);
            document.removeEventListener('mouseup', onMouseUp);
        };
    }

    show() {
        this.isVisible = true;
        this.widget.style.display = "flex";
    }

    hide() {
        this.isVisible = false;
        this.widget.style.display = "none";
    }

    toggle() {
        if (this.isVisible) {
            this.hide();
        } else {
            this.show();
        }
    }

    toggleMinimize() {
        this.isMinimized = !this.isMinimized;
        const content = this.widget.querySelector('.widget-content');
        
        if (this.isMinimized) {
            content.style.display = "none";
            this.widget.style.height = "auto";
        } else {
            content.style.display = "block";
            this.widget.style.height = "400px";
        }
    }
}

// Initialize widget when app loads
app.registerExtension({
    name: "ComfyUI.DataManager",
    async setup() {
        // Create global data manager widget
        window.dataManagerWidget = new DataManagerWidget();
        
        // Add menu item to show/hide data manager
        const menu = document.querySelector(".comfy-menu");
        if (menu) {
            const dataManagerBtn = $el("button.comfy-menu-button", {
                textContent: "🗂️ Data Manager",
                onclick: () => window.dataManagerWidget.toggle()
            });
            
            menu.appendChild(dataManagerBtn);
        }
        
        // Add keyboard shortcut (Ctrl+D)
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey && e.key === 'd') {
                e.preventDefault();
                window.dataManagerWidget.toggle();
            }
        });
        
        console.log("✅ Data Manager extension loaded");
    }
}); 