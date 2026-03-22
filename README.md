# 🚀 AegisSystems

<p align="center">
  <img src="AegisWeb/static/img/aegisSystems-simplew.png" alt="AegisSystems Logo" />
</p>

## 📋 Descripción

# Aegis Systems

**Aegis Systems** es una plataforma innovadora de **gestión de infraestructura en la nube (IaaS)** diseñada para las **pequeñas empresas**, ofreciendo una solución tecnológica **accesible, flexible y eficiente** que permite concentrarse en el crecimiento sin complicaciones técnicas.

Su **interfaz web intuitiva y automatizada** permite a usuarios con **conocimientos limitados** desplegar y administrar **máquinas virtuales** y **contenedores** de manera sencilla, democratizando el acceso a tecnologías avanzadas.

La plataforma integra la gestión de servicios esenciales como **DNS, DHCP y servidores web**, centralizando su administración en un solo panel y garantizando un manejo eficiente de la infraestructura.

Además, cuenta con un sistema de **monitoreo y alertas proactivas**, que supervisa continuamente los recursos y notifica eventos críticos, ayudando a prevenir problemas antes de que afecten la operación.

En resumen, **Aegis Systems** simplifica la administración en la nube, **reduce la complejidad tecnológica**, **optimiza la eficiencia** y **garantiza seguridad y confiabilidad** para las pequeñas empresas.

---

## 🌟 Características clave

- 🔍 Monitorización en tiempo real de múltiples servicios  
- 🖥️ Interfaz web responsiva y amigable  
- ⚠️ Alertas automáticas configurables  
- 🗂️ Registro y análisis histórico de eventos  
- 🔄 Automatización de tareas repetitivas (copias de seguridad, reinicios)

---

## 🖥️ Requisitos mínimos

### Hardware
- 💻 Servidor con CPU de 64-bit, 16 GB RAM  
- 💾 Almacenamiento SSD de al menos 256 GB  
- 🌐 Red estable para comunicaciones

### Software
- 🐧 Linux (Ubuntu, Debian) y  🪟 Windows Server  
- 🌐 Servidor web  
- 🖥️ Hipervisor  
- 🧱 Firewall  
- 🛡️ Servidor bastión  
- 🗄️ MariaDB  
- 📡 Protocolos de monitoreo (SNMP, ICMP)
- ⚙️ API's del sistema operativo
- 🖥️ Lenguaje: Python

---

## 🏗️ Arquitectura del Sistema

El sistema Aegis se compone de dos módulos principales que interactúan para proporcionar una solución completa de gestión e interfaz de usuario:

1.  **AegisManager**: El núcleo de gestión que interactúa directamente con el hipervisor Proxmox VE. Funciona como un backend que expone una API REST para realizar operaciones sobre nodos y máquinas virtuales.
2.  **AegisWeb**: La cara visible para los clientes y administradores. Es un portal web que permite la gestión de incidencias, visualización de servicios y acceso al monitor de infraestructura (a través de AegisManager).

### Flujo de Datos
1.  **Usuario Final** -> Accede a **AegisWeb** para ver su dashboard y reportar incidencias.
2.  **Administrador** -> Accede a **AegisWeb** para gestionar incidencias y visualizar el estado del sistema.
3.  **AegisWeb** -> Integra **AegisManager** mediante un iframe o consultando sus APIs para mostrar el estado de la virtualización.
4.  **AegisManager** -> Se conecta a la API de **Proxmox** (`proxmoxer`) para obtener datos en tiempo real (CPU, RAM, Estado) y ejecutar comandos (Start, Stop, Console).

#### REALIZADO POR JAIME IGLESIAS Y FABIO GARCÍA-MORENO
---
