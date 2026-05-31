#!/bin/bash
#CONFIGURACIÓN
CONF_WG="/etc/wireguard/wg0.conf"
INTERFAZ="wg0"
BASE_SUBRED="10.0.0"
MASCARA_RED="24"
SERVIDOR_DNS="10.0.0.5"
PUERTO_WG="51820"

#VERIFICACIONES DE SEGURIDAD Y ENTORNO
if [[ $EUID -ne 0 ]]; then
   echo "Error: Este script requiere privilegios de root (sudo)."
   exit 1
fi

if [ ! -f "$CONF_WG" ]; then
    echo "Error: No se encuentra el archivo de configuración en $CONF_WG"
    exit 1
fi

if ! command -v wg &> /dev/null; then
    echo "Error: Las herramientas de WireGuard (wg) no están instaladas."
    exit 1
fi

#OBTENER IP PÚBLICA DEL SERVIDOR
echo "Detectando IP Pública del servidor..."
if command -v curl &> /dev/null; then
    IP_PUBLICA_SERVIDOR=$(curl -s --max-time 3 ifconfig.me)
else
    IP_PUBLICA_SERVIDOR="<TU_IP_PUBLICA>"
fi

if [ -z "$IP_PUBLICA_SERVIDOR" ]; then
    echo "Advertencia: No se pudo detectar la IP pública. Se usará un marcador."
    IP_PUBLICA_SERVIDOR="<TU_IP_PUBLICA>"
else
    echo "-> IP Pública detectada: $IP_PUBLICA_SERVIDOR"
fi

#BUSCAR PRIMERA IP LIBRE
NUM_IP=2
echo "Analizando red interna para encontrar huecos libres..."

while [[ $NUM_IP -le 254 ]]; do
    CANDIDATA="${BASE_SUBRED}.${NUM_IP}"

    # Comprobamos si la IP está en uso en líneas activas
    if grep -v "^\s*#" "$CONF_WG" | grep -E "AllowedIPs|Address" | grep -q "${CANDIDATA}/"; then
        ((NUM_IP++))
    else
        NUEVA_IP="$CANDIDATA"
        break
    fi
done

if [[ -z "$NUEVA_IP" ]]; then
    echo "Error: No quedan IPs disponibles en el rango ${BASE_SUBRED}.2 - .254"
    exit 1
fi

#INTERACCIÓN
echo "--- NUEVO CLIENTE CORPORATIVO ---"
echo "IP Interna Asignada: $NUEVA_IP"
echo "================================================"
read -p "Introduce la CLAVE PÚBLICA del cliente (Base64): " CLAVE_PUB_CLIENTE
read -p "Indique un identificativo del equipo (Nombre): " COMENTARIO_CLIENTE

#Validación de clave
if [[ ! "$CLAVE_PUB_CLIENTE" =~ ^[a-zA-Z0-9+/]+={0,2}$ ]]; then
    echo "Error Crítico: El formato de la clave pública no es válido."
    exit 1
fi

#ESCRITURA EN EL SERVIDOR
cp "$CONF_WG" "$CONF_WG.bak"

echo "" >> "$CONF_WG"
{   echo "# Identificador del equipo: $COMENTARIO_CLIENTE"
    echo "[Peer]"
    echo "PublicKey = $CLAVE_PUB_CLIENTE"
    echo "AllowedIPs = $NUEVA_IP/32"
} >> "$CONF_WG"

echo "-> Cliente añadido a $CONF_WG"

#APLICAR CAMBIOS
wg syncconf "$INTERFAZ" <(wg-quick strip "$INTERFAZ")
echo "-> Servicio WireGuard recargado correctamente."

# --- OBTENER CLAVE PÚBLICA DEL SERVIDOR ---
CLAVE_PUB_SERVIDOR=$(wg show "$INTERFAZ" public-key 2>/dev/null)

if [ -z "$CLAVE_PUB_SERVIDOR" ]; then
    if [ -f "/etc/wireguard/privatekey" ]; then
        CLAVE_PUB_SERVIDOR=$(cat /etc/wireguard/privatekey | wg pubkey)
    fi
fi

#MOSTRAR CONFIGURACIÓN DEL CLIENTE
echo ""
echo "COPIA ESTO EN EL EQUIPO DEL EMPLEADO"
echo "========================================================"
echo "[Interface]"
echo "Address = $NUEVA_IP/32"
echo "PrivateKey = <AQUI_VA_LA_CLAVE_PRIVADA_DEL_CLIENTE>"
echo "DNS = $SERVIDOR_DNS"
echo ""
echo "[Peer]"
echo "PublicKey = $CLAVE_PUB_SERVIDOR"
echo "Endpoint = ${IP_PUBLICA_SERVIDOR}:${PUERTO_WG}"
echo "AllowedIPs = ${BASE_SUBRED}.0/${MASCARA_RED}"
echo "PersistentKeepalive = 25"
echo "========================================================"
