#!/bin/bash

################################################################################
# Herramienta Unificada de Gestión y Aprovisionamiento para Proxmox VE
# Versión de Producción - Aislamiento Cloud (Tenant Isolation)
################################################################################

set -euo pipefail

# ============================================================================
# 1. SECCIÓN DE CONFIGURACIÓN (PLANTILLA LIMPIA)
# ============================================================================

# Datos de conexión al clúster de Proxmox
IP_PROXMOX="10.0.0.3"
PUERTO_PROXMOX="8006"
USUARIO_PROXMOX="usuario"     # Ejemplo: "root@pam"
REALM_PROXMOX="realmd"       # Ejemplo: "pam"
CONTRASENA_PROXMOX="contraseña"  # Introducir por entorno o gestor de secretos antes de ejecutar

# Valores por defecto para el aprovisionamiento
NODO_POR_DEFECTO="homeserver"
MEMORIA_POR_DEFECTO="2048"    
CORES_POR_DEFECTO="2"         

# Configuración del control de acceso (RBAC Nativo y Aislado)
ROL_ASIGNADO="PVEVMAdmin"     

# Rutas de archivos temporales y logs
ARCHIVO_LOG="/var/log/proxmox_manager_$(date +%Y%m%d).log"
ARCHIVO_TICKET="/tmp/proxmox_ticket_$$.txt"
ARCHIVO_CSRF="/tmp/proxmox_csrf_$$.txt"

# ============================================================================
# VARIABLES INTERNAS 
# ============================================================================
NUEVO_ID_VM=""

# ============================================================================
# FUNCIONES BASE DE UTILIDAD Y COMUNICACIÓN API
# ============================================================================

registrar_log() {
    local nivel="$1"
    shift
    local mensaje="$*"
    local marca_tiempo=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${marca_tiempo}] [${nivel}] ${mensaje}" | tee -a "$ARCHIVO_LOG"
}

salida_error() {
    registrar_log "ERROR" "$1"
    limpieza
    exit 1
}

limpieza() {
    [[ -f "$ARCHIVO_TICKET" ]] && rm -f "$ARCHIVO_TICKET"
    [[ -f "$ARCHIVO_CSRF" ]] && rm -f "$ARCHIVO_CSRF"
}

trap limpieza EXIT

pve_get() {
    local endpoint="$1"
    curl -s -k -H "Cookie: PVEAuthCookie=$(cat "$ARCHIVO_TICKET")" "https://$IP_PROXMOX:$PUERTO_PROXMOX/api2/json$endpoint"
}

pve_post() {
    local endpoint="$1"
    local data="$2"
    curl -s -k -H "Cookie: PVEAuthCookie=$(cat "$ARCHIVO_TICKET")" -H "CSRFPreventionToken: $(cat "$ARCHIVO_CSRF")" -d "$data" "https://$IP_PROXMOX:$PUERTO_PROXMOX/api2/json$endpoint"
}

pve_put() {
    local endpoint="$1"
    local data="$2"
    # El método PUT es obligatorio en la API de Proxmox para actualizar ACLs
    curl -s -k -X PUT -H "Cookie: PVEAuthCookie=$(cat "$ARCHIVO_TICKET")" -H "CSRFPreventionToken: $(cat "$ARCHIVO_CSRF")" -d "$data" "https://$IP_PROXMOX:$PUERTO_PROXMOX/api2/json$endpoint"
}

autenticar() {
    if [[ -z "$CONTRASENA_PROXMOX" || -z "$USUARIO_PROXMOX" ]]; then
        salida_error "Variables de credenciales no configuradas. Por favor, rellénalas en el script."
    fi

    registrar_log "INFO" "Autenticando en Proxmox VE ($IP_PROXMOX:$PUERTO_PROXMOX)..."
    
    local respuesta=$(curl -s -k -d "username=$USUARIO_PROXMOX&password=$CONTRASENA_PROXMOX&realm=$REALM_PROXMOX" "https://$IP_PROXMOX:$PUERTO_PROXMOX/api2/json/access/ticket")
    
    if ! echo "$respuesta" | grep -q '"ticket"'; then
        salida_error "Fallo en la autenticación. Respuesta del servidor: $respuesta"
    fi
    
    local ticket=$(echo "$respuesta" | grep -o '"ticket":"[^"]*"' | cut -d'"' -f4)
    local csrf=$(echo "$respuesta" | grep -o '"CSRFPreventionToken":"[^"]*"' | cut -d'"' -f4)
    
    echo "$ticket" > "$ARCHIVO_TICKET"
    echo "$csrf" > "$ARCHIVO_CSRF"
    
    registrar_log "INFO" "Autenticación exitosa. Tokens inyectados en cabeceras."
}

# ============================================================================
# GESTIÓN DE USUARIOS
# ============================================================================

crear_usuario() {
    local nombre_usuario="$1"
    local usr_sin_realm="${nombre_usuario%@*}"
    local correo="${2:-$usr_sin_realm@example.com}"
    local contrasena="${3:-$(openssl rand -base64 12)}"
    
    registrar_log "INFO" "Verificando/Creando usuario: $nombre_usuario"
    
    local respuesta=$(pve_post "/access/users" "userid=$nombre_usuario&password=$contrasena&email=$correo&enable=1")
    
    if echo "$respuesta" | grep -q '"error"'; then
        registrar_log "WARN" "El usuario podría existir o se detectó un aviso: $(echo "$respuesta" | grep -o '"message":"[^"]*"')"
    else
        registrar_log "INFO" "Usuario procesado correctamente. Contraseña temporal generada: $contrasena"
    fi
}

listar_usuarios() {
    registrar_log "INFO" "Listando usuarios..."
    pve_get "/access/users" | grep -o '"userid":"[^"]*"' | cut -d'"' -f4
}

listar_vms() {
    registrar_log "INFO" "Listando VMs y plantillas..."
    pve_get "/cluster/resources?type=vm" | grep -E '"vmid"|"name"|"template"'
}

# ============================================================================
# APROVISIONAMIENTO Y ASIGNACIÓN AISLADA
# ============================================================================

esperar_tarea() {
    local upid="$1"
    local nodo="$2"
    local intentos_maximos=60
    
    registrar_log "INFO" "Esperando finalización de clonación (máx 5 minutos)..."
    
    for (( intento=1; intento<=intentos_maximos; intento++ )); do
        local respuesta=$(pve_get "/nodes/$nodo/tasks/$upid/status")
        
        if echo "$respuesta" | grep -q '"status":"stopped"'; then
            if echo "$respuesta" | grep -q '"exitstatus":"OK"'; then
                registrar_log "INFO" "Tarea finalizada exitosamente."
                return 0
            else
                local error=$(echo "$respuesta" | grep -o '"exitstatus":"[^"]*"')
                salida_error "La tarea finalizó con error: $error"
            fi
        fi
        
        sleep 5
    done
    
    salida_error "Tiempo de espera excedido."
}

aprovisionar_vm() {
    local id_plantilla="$1"
    local propietario_vm="$2"
    local nombre_vm="${3:-vm-$(date +%Y%m%d-%H%M%S)}"
    local nodo="${4:-$NODO_POR_DEFECTO}"
    local memoria="${5:-$MEMORIA_POR_DEFECTO}"
    local cores="${6:-$CORES_POR_DEFECTO}"

    # 1. Validar plantilla 
    local resp_plantilla=$(pve_get "/nodes/$nodo/qemu/$id_plantilla/config")
    
    if ! echo "$resp_plantilla" | grep -E -q '"template"\s*:\s*1'; then
        salida_error "La máquina $id_plantilla no es una plantilla válida. Respuesta cruda: $resp_plantilla"
    fi

    # 2. Asegurar existencia de usuario
    crear_usuario "$propietario_vm"

    # 3. Obtener siguiente ID disponible
    local resp_recursos=$(pve_get "/cluster/resources?type=vm")
    local id_maximo=$(echo "$resp_recursos" | grep -oE '"vmid":\s*[0-9]+' | awk -F':' '{print $2}' | tr -d ' ' | sort -n | tail -1)
    NUEVO_ID_VM=$((id_maximo + 1))
    registrar_log "INFO" "Siguiente ID libre detectado: $NUEVO_ID_VM"

    # 4. Clonar Plantilla
    registrar_log "INFO" "Clonando plantilla $id_plantilla hacia VM $NUEVO_ID_VM ($nombre_vm)..."
    local resp_clonacion=$(pve_post "/nodes/$nodo/qemu/$id_plantilla/clone" "newid=$NUEVO_ID_VM&name=$nombre_vm&full=1")
    
    if echo "$resp_clonacion" | grep -q '"error"'; then
        salida_error "Fallo al clonar: $(echo "$resp_clonacion" | grep -o '"message":"[^"]*"')"
    fi
    
    local upid=$(echo "$resp_clonacion" | grep -o 'UPID:[^"]*')
    esperar_tarea "$upid" "$nodo"

    # 5. Configurar recursos de hardware
    registrar_log "INFO" "Configurando recursos (Memoria: $memoria MB, Cores: $cores)..."
    local resp_config=$(pve_post "/nodes/$nodo/qemu/$NUEVO_ID_VM/config" "memory=$memoria&cores=$cores")
    if echo "$resp_config" | grep -q '"error"'; then
        registrar_log "WARN" "Se detectó un error ajustando la configuración: $resp_config"
    fi

    # 6. Asignar Permisos RBAC Aislados (Tenant Isolation)
    registrar_log "INFO" "Enjaulando permisos sobre /vms/$NUEVO_ID_VM con el rol $ROL_ASIGNADO para $propietario_vm..."
    
    # Se utiliza PUT obligatoriamente para escribir en la lista ACL
    local resp_acl=$(pve_put "/access/acl" "path=/vms/$NUEVO_ID_VM&users=$propietario_vm&roles=$ROL_ASIGNADO")
    
    if echo "$resp_acl" | grep -q '"error"'; then
        salida_error "Fallo al asignar el acceso ACL. Respuesta de Proxmox: $resp_acl"
    fi

    registrar_log "INFO" "====== PROVISIONAMIENTO COMPLETADO ======"
    registrar_log "INFO" "ID Asignado: $NUEVO_ID_VM | Nombre: $nombre_vm | Propietario: $propietario_vm"
}

asignar_vm_existente() {
    local nombre_usuario="$1"
    local id_vm="$2"
    
    registrar_log "INFO" "Asignando acceso aislado a la VM $id_vm para el usuario $nombre_usuario..."
    
    local resp_acl=$(pve_put "/access/acl" "path=/vms/$id_vm&users=$nombre_usuario&roles=$ROL_ASIGNADO")
    
    if echo "$resp_acl" | grep -q '"error"'; then
        salida_error "Fallo al asignar el acceso. Respuesta de Proxmox: $resp_acl"
    else
        registrar_log "INFO" "Acceso asignado correctamente."
    fi
}

# ============================================================================
# INTERFAZ DE MENÚ INTERACTIVO 
# ============================================================================

mostrar_menu() {
    for iteracion in {1..100000}; do
        echo "========================================================="
        echo "       GESTOR DE APROVISIONAMIENTO CLOUD (10.0.0.3)      "
        echo "========================================================="
        echo " 1) Aprovisionar una nueva máquina virtual (VM aislada)"
        echo " 2) Crear o verificar un usuario en el realm pam o pve"
        echo " 3) Asignar permisos ACL aislados a una VM existente"
        echo " 4) Listar todos los usuarios del sistema"
        echo " 5) Listar las máquinas virtuales y plantillas"
        echo " 6) Salir de la aplicación"
        echo "========================================================="
        
        local opcion=""
        read -p "Seleccione una opción [1-6]: " opcion
        echo ""

        case "$opcion" in
            1)
                local id_tpl="" propietario="" nombre="" nodo="" memoria="" cores=""
                read -p "ID de la plantilla origen (obligatorio): " id_tpl
                if [[ -z "$id_tpl" ]]; then echo "Error: El ID es obligatorio."; echo ""; continue; fi
                
                read -p "Nombre del usuario propietario (ej: cliente1@pve o admin@pam): " propietario
                if [[ -z "$propietario" ]]; then echo "Error: El propietario es obligatorio."; echo ""; continue; fi
                
                if [[ "$propietario" != *@* ]]; then
                    propietario="${propietario}@pve"
                fi
                
                read -p "Nombre de la nueva VM (Enter para usar auto-generado): " nombre
                read -p "Nodo Proxmox destino [Por defecto: $NODO_POR_DEFECTO]: " nodo
                read -p "Memoria RAM en MB [Por defecto: $MEMORIA_POR_DEFECTO]: " memoria
                read -p "Cores de CPU [Por defecto: $CORES_POR_DEFECTO]: " cores
                
                autenticar
                aprovisionar_vm "$id_tpl" "$propietario" "$nombre" "${nodo:-$NODO_POR_DEFECTO}" "${memoria:-$MEMORIA_POR_DEFECTO}" "${cores:-$CORES_POR_DEFECTO}"
                ;;
            2)
                local usuario_nuevo="" correo_nuevo="" pass_nuevo=""
                read -p "Nombre del nuevo usuario (ej: cliente1@pve o admin@pam): " usuario_nuevo
                if [[ -z "$usuario_nuevo" ]]; then echo "Error: El nombre es obligatorio."; echo ""; continue; fi
                
                if [[ "$usuario_nuevo" != *@* ]]; then
                    usuario_nuevo="${usuario_nuevo}@pve"
                fi
                
                read -p "Correo electrónico [Enter para usar por defecto]: " correo_nuevo
                read -p "Contraseña personalizada [Enter para generar aleatoria]: " pass_nuevo
                
                autenticar
                crear_usuario "$usuario_nuevo" "$correo_nuevo" "$pass_nuevo"
                ;;
            3)
                local usuario_acl="" id_vm_acl=""
                read -p "Nombre del usuario (ej: cliente1@pve o admin@pam): " usuario_acl
                if [[ -z "$usuario_acl" ]]; then echo "Error: El usuario es obligatorio."; echo ""; continue; fi
                
                if [[ "$usuario_acl" != *@* ]]; then
                    usuario_acl="${usuario_acl}@pve"
                fi
                
                read -p "ID de la máquina virtual (VM ID): " id_vm_acl
                if [[ -z "$id_vm_acl" ]]; then echo "Error: El ID de la VM es obligatorio."; echo ""; continue; fi
                
                autenticar
                asignar_vm_existente "$usuario_acl" "$id_vm_acl"
                ;;
            4)
                autenticar
                listar_usuarios
                ;;
            5)
                autenticar
                listar_vms
                ;;
            6)
                registrar_log "INFO" "Cierre manual."
                echo "Saliendo del gestor. ¡Hasta pronto!"
                exit 0
                ;;
            *)
                echo "Opción inválida. Intente de nuevo introduciendo un número del 1 al 6."
                ;;
        esac
        echo ""
    done
}

# ============================================================================
# CONTROL DE ARRANQUE
# ============================================================================

if [[ "${1:-}" =~ ^(-h|--help|help)$ ]]; then
    echo "Uso interactivo: ejecute el script sin parámetros para iniciar el menú."
    exit 0
fi

mostrar_menu