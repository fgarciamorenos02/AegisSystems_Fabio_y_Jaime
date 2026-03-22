# 🛡️ Guía de AEGIS MANAGER

¡Bienvenido al manual de arquitectura y construcción de **AEGIS MANAGER**! Esta guía ha sido diseñada para que cualquier persona con conocimientos básicos de Python y HTML pueda no solo usar la aplicación, sino **reconstruirla desde cero**.

---

## 1. Visión del Proyecto
**AEGIS MANAGER** es una consola de administración ligera para infraestructuras **Proxmox Virtual Environment (PVE)**. Su objetivo es proporcionar una interfaz visual corporativa, ultra-rápida y fácil de usar para monitorizar y controlar máquinas virtuales (VM) y contenedores (LXC) sin la complejidad de la interfaz oficial de Proxmox.

### Características Clave:
*   **Diseño Corporativo**: Estética premium bajo la marca "Aegis Systems".
*   **Modo Dual Real**: Soporte completo para Tema Claro y Oscuro con persistencia.
*   **Monitorización en Vivo**: Estadísticas de CPU, memoria y uptime actualizadas cada 0.5s.
*   **Control Total**: Encendido, apagado, reinicio, suspensión y consola remota integrada.

---

## 2. Arquitectura del Sistema
La aplicación se divide en dos capas principales siguiendo el modelo Cliente-Servidor:

### 2.1 Backend (El Cerebro - Python/Flask)
Usa el framework **Flask** para servir los archivos y gestionar las llamadas a la API de Proxmox.
*   **Librería Principal**: `proxmoxer` (permite hablar con Proxmox de forma nativa).
*   **Seguridad**: No guarda credenciales en el servidor; actúa como un túnel seguro entre el usuario y la API.

### 2.2 Frontend (La Cara - HTML/Tailwind/JS)
Una "Single Page Application" (SPA) simplificada que usa **Tailwind CSS** para el diseño sin necesidad de compilar archivos CSS.
*   **UI/UX**: Uso intensivo de clases dinámicas para el cambio de tema.
*   **Lógica**: Javascript Vanilla (puro) para máxima velocidad y mínima carga.

---

## 3. Estructura de Archivos (El Mapa)
La estructura de la aplicación es la siguiente:

```text
MONITOR-POR-ANTIGRAVITI/
├── app/                        # Capa lógica del servidor
│   ├── __init__.py             # Indica que es un paquete Python
│   ├── servicios_proxmox.py    # Clase que conecta con la API de Proxmox
│   └── servidor_web.py         # Rutas de Flask y API interna
├── static/                     # Archivos que ve el navegador
│   ├── css/                    # (Opcional) Estilos personalizados
│   ├── js/
│   │   └── controlador_interfaz.js # Lógica de la web, botones y gráficos
│   ├── inicio_sesion.html      # Pantalla de Login
│   ├── panel_control.html      # Dashboard principal (Lista de máquinas)
│   └── detalle_maquina.html    # Panel de control de una máquina específica
└── requirements.txt            # Lista de librerías necesarias
```

---

## 4. Diccionario Técnico de Funciones

### ⚙️ Backend: `app.py`
| Función | Propósito |
| :--- | :--- |
| `get_proxmox_connection` | Recupera datos de sesión y crea conexión a API Proxmox. |
| `formatear_tiempo` | Convierte segundos a formato de tiempo legible. |
| `login_page` | Renderiza `inicio_sesion.html` (Ruta `/`). |
| `panel_page` | Renderiza `panel_control.html` si hay sesión activa. |
| `detalle_maquina_page` | Renderiza `detalle_maquina.html` si hay sesión. |
| `api_login` | Endpoint `/api/iniciar-sesion`. Valida credenciales y obtiene ticket. |
| `api_nodos` | Obtiene lista de nodos con métricas básicas (CPU, RAM). |
| `api_nodo_estado` | Obtiene estado detallado de un nodo específico. |
| `api_nodo_maquinas` | Lista VMs y CTs de un nodo con su estado. |
| `api_vm_config` | Obtiene configuración de hardware de una máquina. |
| `api_vm_estado` | Obtiene métricas en tiempo real de una máquina. |
| `api_vm_accion` | Ejecuta acciones (start, stop, etc.) en una máquina. |

### 🎨 Interfaz: `static/js/controlador_interfaz.js`
| Función | Propósito |
| :--- | :--- |
| `alternarTema` | Cambia entre tema claro/oscuro y persiste en local. |
| `cerrarSesion` | Elimina datos de sesión y redirige al login. |
| `formatearBytes` | Formatea bytes a unidades (KB, MB, GB). |
| `cargarNodos` | Obtiene nodos de API y renderiza sidebar. |
| `seleccionarNodo` | Selecciona nodo visualmente y carga sus datos. |
| `cargarEstadisticasNodo` | Inicia polling de estadísticas del nodo. |
| `cargarMaquinas` | Obtiene y renderiza tarjetas de máquinas del nodo. |
| `accionMaquina` | Envía orden de energía al backend (con confirmación). |
| `cargarConfiguracionVM` | Carga detalles de hardware en vista de máquina. |
| `iniciarSondeoEstadisticas` | Inicia polling de métricas de una máquina. |
| `actualizarInterfazEstadisticas` | Actualiza DOM con nuevos datos de máquina. |
| `formatearSegundos` | Formatea tiempo uptime a formato legible. |
| `lanzarConsola` | Abre consola VNC/NoVNC en nueva ventana. |
