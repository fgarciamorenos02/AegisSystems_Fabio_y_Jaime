from flask import Flask, render_template, jsonify, request, session, redirect, url_for
import urllib3
from proxmoxer import ProxmoxAPI
import os
import datetime

# Desactivar advertencias de certificados no válidos (común en Proxmox)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

app = Flask(__name__)
app.secret_key = os.urandom(24)

# --- UTILIDADES ---

def get_proxmox_connection():
    """Recupera los datos de la sesión y crea la conexión a la API"""
    if 'proxmox_auth' not in session:
        return None
    
    auth = session['proxmox_auth']
    try:
        proxmox = ProxmoxAPI(
            auth['host'],
            user=auth['user'],
            password=auth['password'],
            verify_ssl=False,
            port=8006,
            timeout=5
        )
        return proxmox
    except:
        return None

def formatear_tiempo(seconds):
    return str(datetime.timedelta(seconds=int(seconds)))

# --- RUTAS DE NAVEGACIÓN ---

@app.route('/')
@app.route('/login')
def login_page():
    return render_template('inicio_sesion.html')

@app.route('/panel')
def panel_page():
    if 'proxmox_auth' not in session:
        return redirect(url_for('login_page'))
    return render_template('panel_control.html')

@app.route('/detalle-maquina')
def detalle_maquina_page():
    if 'proxmox_auth' not in session:
        return redirect(url_for('login_page'))
    return render_template('detalle_maquina.html')

# --- RUTAS DE API ---

@app.route('/api/iniciar-sesion', methods=['POST'])
def api_login():
    data = request.json
    host = data.get('host')
    username = data.get('username')
    password = data.get('password')
    realm = data.get('realm', 'pam')
    
    full_user = f"{username}@{realm}"

    try:
        # Intento de conexión para validar credenciales y OBTENER TICKET
        # Usamos una instancia temporal para esto
        proxmox = ProxmoxAPI(host, user=full_user, password=password, verify_ssl=False, port=8006, timeout=5)
        
        # Obtener el ticket explícitamente para pasarlo al frontend (necesario para VNC/Consola)
        # El endpoint es /access/ticket
        ticket_data = proxmox.access.ticket.post(username=full_user, password=password)
        ticket = ticket_data.get('ticket')
        csrf_token = ticket_data.get('CSRFPreventionToken')
        
        # Guardar en sesión para uso del proxy Flask
        session['proxmox_auth'] = {
            'host': host, 'user': full_user, 'password': password,
            # 'csrf': csrf_token # Podríamos guardarlo si fuera necesario
        }
        
        return jsonify({'ticket': ticket, 'CSRFPreventionToken': csrf_token, 'message': 'Login exitoso'})
    except Exception as e:
        return jsonify({'detalle': f"Error de conexión: {str(e)}"}), 401

@app.route('/api/nodos', methods=['GET'])
def api_nodos():
    proxmox = get_proxmox_connection()
    if not proxmox: return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        nodes = proxmox.nodes.get()
        # Filtrar datos necesarios
        resultado = []
        for n in nodes:
            resultado.append({
                'node': n.get('node'),
                'status': n.get('status', 'unknown'),
                'cpu': n.get('cpu', 0),
                'maxcpu': n.get('maxcpu', 1),
                'mem': n.get('mem', 0),
                'maxmem': n.get('maxmem', 1),
                'uptime': n.get('uptime', 0)
            })
        return jsonify(resultado)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/nodos/<node>/estado', methods=['GET'])
def api_nodo_estado(node):
    proxmox = get_proxmox_connection()
    if not proxmox: return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        status = proxmox.nodes(node).status.get()
        # Formato esperado por el frontend
        return jsonify({
            'cpu': status.get('cpu', 0),
            'memory': {
                'used': status.get('memory', {}).get('used', 0),
                'total': status.get('memory', {}).get('total', 1)
            },
            'uptime': status.get('uptime', 0),
            'status': 'online' # Si responde, está online
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/nodos/<node>/maquinas', methods=['GET'])
def api_nodo_maquinas(node):
    proxmox = get_proxmox_connection()
    if not proxmox: return jsonify({'error': 'Unauthorized'}), 401
    
    try:
        vms = proxmox.nodes(node).qemu.get()
        lxc = proxmox.nodes(node).lxc.get()
        
        lista = []
        for vm in vms:
            lista.append({
                'vmid': vm.get('vmid'),
                'name': vm.get('name'),
                'status': vm.get('status'),
                'type': 'qemu',
                'cpu': vm.get('cpu', 0),
                'mem': vm.get('mem', 0),
                'maxmem': vm.get('maxmem', 0)
            })
        for ct in lxc:
            lista.append({
                'vmid': ct.get('vmid'),
                'name': ct.get('name'),
                'status': ct.get('status'),
                'type': 'lxc',
                'cpu': ct.get('cpu', 0),
                'mem': ct.get('mem', 0),
                'maxmem': ct.get('maxmem', 0)
            })
            
        return jsonify(lista)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/nodos/<node>/maquinas/<int:vmid>/configuracion', methods=['GET'])
def api_vm_config(node, vmid):
    proxmox = get_proxmox_connection()
    if not proxmox: return jsonify({'error': 'Unauthorized'}), 401
    
    tipo_req = request.args.get('tipo', 'qemu')
    
    try:
        if tipo_req == 'lxc':
            config = proxmox.nodes(node).lxc(vmid).config.get()
            config['type'] = 'lxc'
        else:
            config = proxmox.nodes(node).qemu(vmid).config.get()
            config['type'] = 'qemu'
            
        return jsonify(config)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/nodos/<node>/maquinas/<int:vmid>/estado', methods=['GET'])
def api_vm_estado(node, vmid):
    proxmox = get_proxmox_connection()
    if not proxmox: return jsonify({'error': 'Unauthorized'}), 401
    
    tipo_req = request.args.get('tipo', 'qemu')
    
    try:
        if tipo_req == 'lxc':
            status = proxmox.nodes(node).lxc(vmid).status.current.get()
        else:
            status = proxmox.nodes(node).qemu(vmid).status.current.get()
            
        return jsonify(status)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/nodos/<node>/maquinas/<int:vmid>/accion', methods=['POST'])
def api_vm_accion(node, vmid):
    proxmox = get_proxmox_connection()
    if not proxmox: return jsonify({'error': 'Unauthorized'}), 401
    
    data = request.json
    accion = data.get('accion') # start, stop, shutdown, reboot, etc.
    tipo = data.get('tipo', 'qemu')
    
    try:
        if tipo == 'lxc':
            target = proxmox.nodes(node).lxc(vmid)
        else:
            target = proxmox.nodes(node).qemu(vmid)
            
        if hasattr(target.status, accion):
            getattr(target.status, accion).post()
            return jsonify({'success': True})
        else:
            return jsonify({'error': 'Acción no soportada'}), 400
            
    except Exception as e:
        return jsonify({'detalle': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=8000, host='0.0.0.0')