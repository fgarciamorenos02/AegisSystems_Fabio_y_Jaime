-- TABLA EMPLEADO
-- Empleados que administran nodos.
CREATE TABLE EMPLEADO (
    IDEmpleado INT PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    Oficina VARCHAR(100),
    Telefono VARCHAR(20),
    FechaIngreso DATE NOT NULL
);

-- TABLA NODO
-- Servidores físicos o virtuales.
CREATE TABLE NODO (
    IDNodo INT PRIMARY KEY,
    IP VARCHAR(45) UNIQUE NOT NULL, -- La IP debe ser única
    Host VARCHAR(100) NOT NULL,
    IDEmpleado INT NOT NULL,

    FOREIGN KEY (IDEmpleado)
        REFERENCES EMPLEADO(IDEmpleado)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- TABLA TIPO_MAQUINA
-- Estandariza las especificaciones de hardware para evitar redundancia en MAQUINA.
CREATE TABLE TIPO_MAQUINA (
    IDTipoMaquina INT PRIMARY KEY,
    NombreTipo VARCHAR(100) UNIQUE NOT NULL,
    Memoria INT NOT NULL, -- Especificaciones se guardan aquí
    Almacenamiento INT NOT NULL,
    Nucleos INT NOT NULL,
    Descripcion TEXT
);

-- TABLA MAQUINA
-- Instancias (VMs, Contenedores) que se ejecutan en un NODO.
CREATE TABLE MAQUINA (
    IDMaquina INT PRIMARY KEY,
    Tipo ENUM('MAQUINA', 'CONTENEDOR') NOT NULL,
    IDNodo INT NOT NULL,
    IDTipoMaquina INT NOT NULL,

    FOREIGN KEY (IDNodo)
        REFERENCES NODO(IDNodo)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    FOREIGN KEY (IDTipoMaquina)
        REFERENCES TIPO_MAQUINA(IDTipoMaquina)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- TABLA CLIENTE
CREATE TABLE CLIENTE (
    IDCliente INT PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    FechaNacimiento DATE,
    Pais VARCHAR(50),
    DNI VARCHAR(20) UNIQUE NOT NULL -- El DNI debe ser único
);

-- TABLA CONTACTO
-- Permite múltiples contactos por cliente.
CREATE TABLE CONTACTO (
    IDContacto INT PRIMARY KEY,
    IDCliente INT NOT NULL,
    Telefono VARCHAR(20),
    Email VARCHAR(100),

    FOREIGN KEY (IDCliente)
        REFERENCES CLIENTE(IDCliente)
        ON DELETE CASCADE -- Si el cliente se elimina, sus contactos también
        ON UPDATE CASCADE
);

-- TABLA METODOPAGO
CREATE TABLE METODOPAGO (
    IDMetodoPago INT PRIMARY KEY,
    Metodo VARCHAR(100) UNIQUE NOT NULL
);

-- TABLA CONTRATO
-- Incluye historialidad con fechas de inicio y fin.
CREATE TABLE CONTRATO (
    IDContrato INT PRIMARY KEY,
    Importe DECIMAL(10, 2) NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin DATE,
    IDCliente INT NOT NULL,
    IDMetodoPago INT NOT NULL,

    FOREIGN KEY (IDCliente)
        REFERENCES CLIENTE(IDCliente)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    FOREIGN KEY (IDMetodoPago)
        REFERENCES METODOPAGO(IDMetodoPago)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CHECK (FechaFin IS NULL OR FechaFin >= FechaInicio)
);

-- TABLA PROVEEDOR
CREATE TABLE PROVEEDOR (
    IDProveedor INT PRIMARY KEY,
    Nombre VARCHAR(100) UNIQUE NOT NULL
);

-- TABLA SERVICIO
CREATE TABLE SERVICIO (
    IDServicio INT PRIMARY KEY,
    NombreServicio VARCHAR(100) UNIQUE NOT NULL
);

-- --- TABLAS DE UNIÓN (M:M) ---

-- TABLA CONTRATO_SERVICIO
-- Asocia servicios a un contrato e incluye el precio acordado para historialidad.
CREATE TABLE CONTRATO_SERVICIO (
    IDContrato INT NOT NULL,
    IDServicio INT NOT NULL,
    PrecioAcordado DECIMAL(10, 2) NOT NULL,

    PRIMARY KEY (IDContrato, IDServicio),

    FOREIGN KEY (IDContrato)
        REFERENCES CONTRATO(IDContrato)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    FOREIGN KEY (IDServicio)
        REFERENCES SERVICIO(IDServicio)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- TABLA CONTRATO_MAQUINA
-- Asigna las máquinas específicas a un contrato.
CREATE TABLE CONTRATO_MAQUINA (
    IDContrato INT NOT NULL,
    IDMaquina INT NOT NULL,

    PRIMARY KEY (IDContrato, IDMaquina),

    FOREIGN KEY (IDContrato)
        REFERENCES CONTRATO(IDContrato)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    FOREIGN KEY (IDMaquina)
        REFERENCES MAQUINA(IDMaquina)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- TABLA SERVICIO_PROVEEDOR
-- Detalla qué proveedor suministra qué servicio.
CREATE TABLE SERVICIO_PROVEEDOR (
    IDServicio INT NOT NULL,
    IDProveedor INT NOT NULL,

    PRIMARY KEY (IDServicio, IDProveedor),

    FOREIGN KEY (IDServicio)
        REFERENCES SERVICIO(IDServicio)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    FOREIGN KEY (IDProveedor)
        REFERENCES PROVEEDOR(IDProveedor)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- ==========================================
-- INTEGRACIÓN CON AEGISWEB (PORTAL FRONTEND)
-- ==========================================
-- Estas tablas abastecen la Autenticación Web y 
-- el Gestor de Incidencias desde la API (app.py)

-- TABLA usuarios
-- Sistema de autenticación de clientes y administradores.
-- Un usuario con rol 'admin' corresponde a un técnico en la tabla EMPLEADO.
-- Un usuario con rol 'client' corresponde a los accesos web de un CLIENTE.
-- El código de AegisWeb (app.py) utiliza estar tabla mediante SQLAlchemy.
CREATE TABLE IF NOT EXISTS usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(100) NOT NULL,
    role VARCHAR(20) NOT NULL,
    IDCliente INT NULL,
    IDEmpleado INT NULL,

    FOREIGN KEY (IDCliente) REFERENCES CLIENTE(IDCliente) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (IDEmpleado) REFERENCES EMPLEADO(IDEmpleado) ON DELETE SET NULL ON UPDATE CASCADE
);

-- TABLA incidencias
-- Registro transaccional de los tickets de soporte web.
CREATE TABLE IF NOT EXISTS incidencias (
    id VARCHAR(20) PRIMARY KEY, -- Formato: YYYYMMDDHHMMSS
    username VARCHAR(50) NOT NULL,
    subject VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL,
    priority VARCHAR(20) NOT NULL,
    status VARCHAR(50) DEFAULT 'Pendiente',
    timestamp VARCHAR(50) NOT NULL,
    assigned_to VARCHAR(50) DEFAULT 'Sin asignar',

    FOREIGN KEY (username)
        REFERENCES usuarios(username)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
