# Documentación Técnica: Aegis Web

Esta documentación proporciona una visión detallada de los archivos y funciones que componen la aplicación **Aegis Web**.

## Estructura de Archivos

### Archivos Principales
* **`app.py`**: Archivo principal de la aplicación Flask. Configura la base de datos MariaDB (vía SQLAlchemy), los modelos de datos, las utilidades de negocio y todas las rutas (vistas públicas y paneles de gestión).
* **`.env` / `.env.example`**: Configuración de entorno. Aquí se definen los parámetros de conexión a la base de datos MariaDB (`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`) y opciones de Flask.
* **`requirements.txt`**: Dependencias del proyecto (Flask, Werkzeug, Flask-SQLAlchemy, pymysql, python-dotenv).

### Directorios
* **`templates/`**: Contiene las plantillas HTML para el frontend.
  * `base.html`: Plantilla base con el layout común (navbar, footer).
  * `inicio.html`, `precios.html`, `seguridad.html`, `contacto.html`: Páginas públicas de información corporativa.
  * `iniciar_sesion.html`: Pantalla de inicio de sesión de clientes y administradores.
  * `panel_cliente.html`: Vista de dashboard para clientes, desde la cual reportan incidencias y ven su historial.
  * `panel_admin.html`: Vista de dashboard para administradores, donde se gestionan las incidencias y contrataciones pendientes.
  * `contratacion.html`: Catálogo de Máquinas Virtuales donde los clientes pueden solicitar el aprovisionamiento de un nuevo servidor.
* **`static/`**: Recursos estáticos como imágenes y hojas de estilo adicionales.

---

## Modelos de Base de Datos (SQLAlchemy)

### `Usuario`
* **Tabla**: `usuarios`
* **Campos**: `id` (PK), `username` (nombre de usuario, único), `password` (contraseña), `role` (rol: admin o cliente).
* **Propósito**: Gestión de usuarios para inicio de sesión en la plataforma.

### `Incidencia`
* **Tabla**: `incidencias`
* **Campos**: `id` (PK, formato YYYYMMDDHHMMSS), `username` (creador), `subject` (asunto), `description` (detalle), `category` (categoría, incluye 'Contratacion'), `priority` (prioridad), `status` (estado actual), `timestamp` (fecha), `assigned_to` (admin encargado).
* **Propósito**: Seguimiento de tickets de soporte y peticiones de contratación.

---

## Funciones Helper en `app.py`

#### `cargar_incidencias()`
* **Descripción**: Consulta todas las incidencias de la base de datos y las serializa a una lista de diccionarios. Esto facilita la iteración segura dentro de las plantillas de Jinja2.
* **Retorno**: Lista de diccionarios de incidencias.

#### `guardar_incidencia(nombre_usuario, asunto, descripcion, categoria, prioridad)`
* **Descripción**: Crea un nuevo registro de `Incidencia` en la base de datos con los datos proporcionados.
* **Generación automática**: El `id` se genera a partir de la fecha y hora actual, el estado inicial es "Pendiente" y la asignación es "Sin asignar".
* **Retorno**: None (escribe en base de datos).

#### `actualizar_incidencia_completa(id_incidencia, nuevo_estado, nueva_prioridad, nuevo_asignado)`
* **Descripción**: Modifica un registro existente de `Incidencia` buscando por ID. Actualiza estado, prioridad o asignado solo si se proporcionan nuevos valores.
* **Retorno**: None (commit en base de datos).

---

## Rutas de la Aplicación (Views)

### Páginas Públicas
* **`inicio()`** (`/`): Renderiza `inicio.html`.
* **`precios()`** (`/precios`): Renderiza `precios.html`.
* **`seguridad()`** (`/seguridad`): Renderiza `seguridad.html`.
* **`contacto()`** (`/contacto`): Renderiza `contacto.html`.

### Sesión de Usuarios
* **`iniciar_sesion()`** (`/iniciar_sesion`, GET/POST): Comprueba las credenciales contra el modelo `Usuario`. Si son correctas, almacena el `usuario` y el `rol` en la sesión y redirige al panel.
* **`cerrar_sesion()`** (`/cerrar_sesion`): Limpia todos los datos de la sesión (logout).

### Panel de Control
* **`panel_control()`** (`/panel_control`): Protegida por sesión. Verifica el rol:
  * Si es **admin**, obtiene todas las incidencias y renderiza `panel_admin.html`.
  * Si es **cliente**, filtra las incidencias para que solo vea las suyas y renderiza `panel_cliente.html`.

### Gestión de Incidencias
* **`crear_incidencia()`** (`/crear_incidencia`, POST): Llamada desde el panel del cliente para registrar una nueva incidencia de soporte técnico, facturación, etc.
* **`gestionar_incidencia()`** (`/gestionar_incidencia`, POST): Restringida a rol **admin**. Modifica los parámetros de un ticket existente (estado, asignado, prioridad) desde el modal de gestión del panel.

### Contratación de Máquinas
* **`CATALOGO_VMS` (Variable global)**: Lista de diccionarios con la definición de los planes de servidores Ubuntu (Micro, Small, Medium, Large, XLarge).
* **`contratacion()`** (`/contratacion`, GET): Muestra el catálogo de máquinas a los clientes logueados. Renderiza `contratacion.html`.
* **`contratar_vm()`** (`/contratar_vm`, POST): Recibe la petición del formulario del modal de contratación (VM ID y Hostname). Forma un ticket con detalles completos del servidor elegido y lo guarda como incidencia tipo `Contratacion` con prioridad `Alta`.

---

## Funciones JavaScript (Embebidas en Plantillas)

### En `panel_admin.html`

#### `openModal(id, subject, desc, priority, status, assigned)`
* **Descripción**: Se ejecuta al hacer clic en el botón "Gestionar" de una incidencia o contratación. Recoge los datos proporcionados por Jinja2, los carga en los campos de formulario e inputs del modal (`manageModal`), y hace visible el modal modificando sus clases CSS de Tailwind.

#### `closeModal()`
* **Descripción**: Oculta el modal de gestión `manageModal` quitando la clase CSS `flex` y agregando `hidden`.

### En `contratacion.html`

#### `abrirModal(id, nombre, vcpu, ram, disco, red, precio, so, badge)`
* **Descripción**: Activada al seleccionar una tarjeta de Máquina Virtual del catálogo. Rellena dinámicamente un resumen de las especificaciones (`modalSpecs`) y el nombre (`modalNombreVM`), establece el ID oculto de la VM a enviar al servidor, muestra el modal (`modalContratacion`) y auto-enfoca el campo de texto `hostname` para mejorar la accesibilidad.

#### `cerrarModal()`
* **Descripción**: Oculta el modal de contratación modificando las clases de Tailwind. Además, esta función se asocia a "event listeners" adicionales (tecla `Escape` y click fuera del modal en el "backdrop") para mejorar la experiencia de usuario.
