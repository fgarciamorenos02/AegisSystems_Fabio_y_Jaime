# 🛡️ Guía Maestra de AEGIS MANAGER

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
Para reconstruir la app, organiza tus carpetas así:

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

## 4. Cómo Reconstruir la Aplicación (Paso a Paso)

### Paso 1: Configurar el Entorno
Instala Python 3 y las librerías necesarias:
```bash
pip install flask proxmoxer requests flask-cors
```

### Paso 2: Crear el Cliente Proxmox (`app/servicios_proxmox.py`)
Aquí debes implementar una clase `ProxmoxClient` que use `proxmoxer.ProxmoxAPI`. Esta clase debe manejar:
1.  **Login**: Autenticación con Token o Usuario/Pass.
2.  **Get nodes/vms**: Listar recursos del servidor.
3.  **Actions**: Enviar comandos de estado (`start`, `stop`, etc).

### Paso 3: Lanzar el Servidor (`app/servidor_web.py`)
Define las rutas para servir los HTMLs y las rutas `/api/...` que llamen a tu clase del Paso 2. 
> [!TIP]
> Asegúrate de manejar errores 401 (No autorizado) para redirigir al login si la sesión caduca.

### Paso 4: Crear la Interfaz Atómica (Frontend)
Usa **Tailwind CSS** mediante su CDN en el `head` de tus HTMLs para poder usar clases como `dark:bg-black`.
1.  **Header**: Incluye el logo de AEGIS y el botón de alternar tema (`alternarTema()`).
2.  **Dashboard**: Un menú lateral para los nodos y un área central para las tarjetas de máquinas.
3.  **Tarjetas**: Deben generarse dinámicamente con JS basándose en los datos de la API.

### Paso 5: Programar la Interactividad (`static/js/controlador_interfaz.js`)
Esta es la parte más importante. Debes crear funciones para:
*   **Fetch**: Pedir datos a tu servidor cada pocos segundos.
*   **DOM Manipulation**: Borrar y volver a dibujar las tarjetas o las barras de progreso.
*   **LocalStorage**: Guardar si el usuario prefiere el modo claro u oscuro.

---

## 5. Diseño y Estética (Corporate Aegis)
AEGIS se basa en una paleta de colores minimalista:
*   **Oscuro**: Fondo negro puro (`#000000`), tarjetas gris oscuro (`#0a0a0a`), bordes sutiles.
*   **Claro**: Fondo blanco, tarjetas gris muy claro por arriba, bordes definidos pero suaves.
*   **Branding**: Siempre incluye el pie de página centrando: `© 2026 AEGIS SYSTEMS | AEGISSYSTEM.ES`.

---

## 6. Puesta en Marcha (Despliegue)
Para arrancar el motor de Aegis:
1.  Abre la terminal en la raíz del proyecto.
2.  Ejecuta: `python3 -m app.servidor_web`.
3.  Abre en tu navegador: `http://localhost:8000`.

---

## 7. Diccionario Técnico de Funciones
Para facilitar la modificación del código, aquí tienes un desglose de qué hace cada función importante:

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

---
*Documentación oficial de AEGIS SYSTEMS. La virtualización profesional, simplificada al máximo.*
