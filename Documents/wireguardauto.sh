#!/bin/bash
# ==============================================================================
#  WIREGUARD CLIENT GENERATOR
# ==============================================================================

# --- CONFIGURACIÓN ---
WG_CONF="/etc/wireguard/wg0.conf"
INTERFACE="wg0"
SUBNET_BASE="10.0.0"
NETWORK_MASK="24"
DNS_SERVER="10.0.0.5"
WG_PORT="51820"

# --- VERIFICACIONES DE SEGURIDAD Y ENTORNO ---
if [[ $EUID -ne 0 ]]; then
   echo "Error: Este script requiere privilegios de root (sudo)." 
   exit 1
fi

if [ ! -f "$WG_CONF" ]; then
    echo "Error: No se encuentra el archivo de configuración en $WG_CONF"
    exit 1
fi

if ! command -v wg &> /dev/null; then
    echo "Error: Las herramientas de WireGuard (wg) no están instaladas."
    exit 1
fi

# --- Check de SaveConfig para evitar borrado accidental ---
if grep -q "SaveConfig\s*=\s*true" "$WG_CONF"; then
    echo "Error: 'SaveConfig = true' detectado en $WG_CONF"
    echo "Esto borraría los usuarios añadidos. Cambialo a false antes de continuar."
    exit 1
fi

# --- Detectar Curl para obtener IP pública ---
if ! command -v curl &> /dev/null; then
    echo "Advertencia: 'curl' no está instalado. No se podrá detectar la IP pública automáticamente."
fi

# --- OBTENER IP PÚBLICA DEL SERVIDOR ---
echo "Detectando IP Pública del servidor..."
if command -v curl &> /dev/null; then
    SERVER_PUBLIC_IP=$(curl -s --max-time 3 ifconfig.me)
else
    SERVER_PUBLIC_IP="<TU_IP_PUBLICA>"
fi

if [ -z "$SERVER_PUBLIC_IP" ]; then
    echo "Advertencia: No se pudo detectar la IP pública. Se usará un marcador."
    SERVER_PUBLIC_IP="<TU_IP_PUBLICA>"
else
    echo "-> IP Pública detectada: $SERVER_PUBLIC_IP"
fi

# --- BUSCAR PRIMERA IP LIBRE (Lógica Estricta AllowedIPs) ---
IP_NUM=2 
echo "Analizando red interna para encontrar huecos libres..."

while [[ $IP_NUM -le 254 ]]; do
    CANDIDATE="${SUBNET_BASE}.${IP_NUM}"
    
    # Comprobamos si la IP está en uso en líneas activas de AllowedIPs o Address
    if grep -v "^\s*#" "$WG_CONF" | grep -E "AllowedIPs|Address" | grep -q "${CANDIDATE}/"; then
        ((IP_NUM++))
    else
        # Si no se encuentra, hemos dado con una libre
        NEW_IP="$CANDIDATE"
        break
    fi
done

# Verificación final: si NEW_IP sigue vacío, es que recorrió todo sin éxito
if [[ -z "$NEW_IP" ]]; then
    echo "Error: No quedan IPs disponibles en el rango ${SUBNET_BASE}.2 - .254"
    exit 1
fi

# --- INTERACCIÓN ---
echo "================================================"
echo " NUEVO CLIENTE CORPORATIVO"
echo " IP Interna Asignada: $NEW_IP"
echo "================================================"
echo "Introduce la CLAVE PÚBLICA del cliente (Base64):"
read -p "> " CLIENT_PUB_KEY
read -p "Indique un identificativo del equipo: " CLIENT_COMMENT

# --- Validación estricta ---
if [[ ! "$CLIENT_PUB_KEY" =~ ^[a-zA-Z0-9+/]+={0,2}$ ]]; then
    echo "Error Crítico: El formato de la clave pública no es válido."
    exit
fi

# --- ESCRITURA EN EL SERVIDOR ---
cp "$WG_CONF" "$WG_CONF.bak"

# Asegurar salto de línea antes de escribir
echo "" >> "$WG_CONF"
{   echo "# Identificador del equipo: $CLIENT_COMMENT" 
    echo "[Peer]"
    echo "PublicKey = $CLIENT_PUB_KEY"
    echo "AllowedIPs = $NEW_IP/32"
} >> "$WG_CONF"

echo "-> Cliente añadido a $WG_CONF"

# --- APLICAR CAMBIOS---
wg syncconf "$INTERFACE" <(wg-quick strip "$INTERFACE")
echo "-> Servicio WireGuard recargado correctamente."

# --- OBTENER CLAVE PÚBLICA DEL SERVIDOR ---
SERVER_PUB_KEY=$(wg show "$INTERFACE" public-key 2>/dev/null)

if [ -z "$SERVER_PUB_KEY" ]; then
    if [ -f "/etc/wireguard/privatekey" ]; then
        SERVER_PUB_KEY=$(cat /etc/wireguard/privatekey | wg pubkey)
    fi
fi

# --- MOSTRAR CONFIGURACIÓN DEL CLIENTE ---
echo ""
echo "========================================================"
echo " COPIA ESTO EN EL EQUIPO DEL EMPLEADO" 
echo "========================================================"
echo "[Interface]"
echo "Address = $NEW_IP/32"
echo "PrivateKey = <AQUI_VA_LA_CLAVE_PRIVADA_DEL_CLIENTE>"
echo ""
echo "[Peer]"
echo "PublicKey = $SERVER_PUB_KEY"
echo "Endpoint = ${SERVER_PUBLIC_IP}:${WG_PORT}"
echo "AllowedIPs = ${SUBNET_BASE}.0/${NETWORK_MASK}"
echo "PersistentKeepalive = 25"
echo "========================================================"
