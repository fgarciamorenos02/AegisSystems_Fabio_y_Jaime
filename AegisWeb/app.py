import os
import datetime
from flask import Flask, render_template, request, redirect, url_for, session, flash
from flask_sqlalchemy import SQLAlchemy
from dotenv import load_dotenv

# Cargar variables de entorno desde .env
load_dotenv()

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'aegis-web-super-secret-key-1234')

# --- Conexión a Base de Datos MariaDB ---
# Las credenciales se leen del .env (DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME)
_db_host = os.environ.get('DB_HOST', '192.168.20.50')
_db_port = os.environ.get('DB_PORT', '3306')
_db_user = os.environ.get('DB_USER', 'root')
_db_pass = os.environ.get('DB_PASSWORD', 'root')
_db_name = os.environ.get('DB_NAME', 'aegis_web')

app.config['SQLALCHEMY_DATABASE_URI'] = (
    f"mysql+pymysql://{_db_user}:{_db_pass}@{_db_host}:{_db_port}/{_db_name}"
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# --- Modelos SQLAlchemy ---

class Usuario(db.Model):
    __tablename__ = 'usuarios'
    id = db.Column('id', db.Integer, primary_key=True)
    nombre_usuario = db.Column('username', db.String(50), unique=True, nullable=False)
    contrasena = db.Column('password', db.String(100), nullable=False)
    rol = db.Column('role', db.String(20), nullable=False)

class Incidencia(db.Model):
    __tablename__ = 'incidencias'
    id = db.Column('id', db.String(20), primary_key=True) # YYYYMMDDHHMMSS
    nombre_usuario = db.Column('username', db.String(50), nullable=False)
    asunto = db.Column('subject', db.String(200), nullable=False)
    descripcion = db.Column('description', db.Text, nullable=False)
    categoria = db.Column('category', db.String(50), nullable=False)
    prioridad = db.Column('priority', db.String(20), nullable=False)
    estado = db.Column('status', db.String(50), default='Pendiente')
    fecha_creacion = db.Column('timestamp', db.String(50), nullable=False)
    asignado_a = db.Column('assigned_to', db.String(50), default='Sin asignar')

# --- Helper Functions (Adaptadas a ORM) ---

def cargar_incidencias():
    incidencias = Incidencia.query.all()
    # Retornamos como lista de diccionarios para no romper los templates de Jinja2
    return [{
        'id': i.id, 'nombre_usuario': i.nombre_usuario, 'asunto': i.asunto, 
        'descripcion': i.descripcion, 'categoria': i.categoria, 
        'prioridad': i.prioridad, 'estado': i.estado, 
        'fecha_creacion': i.fecha_creacion, 'asignado_a': i.asignado_a
    } for i in incidencias]

def guardar_incidencia(nombre_usuario, asunto, descripcion, categoria, prioridad):
    id_incidencia = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    fecha_creacion = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    estado = 'Pendiente'
    asignado_a = 'Sin asignar'
    
    nueva_incidencia = Incidencia(
        id=id_incidencia, nombre_usuario=nombre_usuario, asunto=asunto, 
        descripcion=descripcion, categoria=categoria, prioridad=prioridad, 
        estado=estado, fecha_creacion=fecha_creacion, asignado_a=asignado_a
    )
    db.session.add(nueva_incidencia)
    db.session.commit()

def actualizar_incidencia_completa(id_incidencia, nuevo_estado, nueva_prioridad, nuevo_asignado):
    incidencia = Incidencia.query.get(id_incidencia)
    if incidencia:
        if nuevo_estado: incidencia.estado = nuevo_estado
        if nueva_prioridad: incidencia.prioridad = nueva_prioridad
        if nuevo_asignado: incidencia.asignado_a = nuevo_asignado
        db.session.commit()

# Routes
@app.route('/')
def inicio():
    return render_template('inicio.html')

@app.route('/precios')
def precios():
    return render_template('precios.html')

@app.route('/seguridad')
def seguridad():
    return render_template('seguridad.html')

@app.route('/contacto')
def contacto():
    return render_template('contacto.html')

@app.route('/iniciar_sesion', methods=['GET', 'POST'])
def iniciar_sesion():
    if request.method == 'POST':
        nombre_usuario = request.form.get('nombre_usuario')
        contrasena = request.form.get('contrasena')
        
        usuario = Usuario.query.filter_by(nombre_usuario=nombre_usuario).first()
        
        if usuario and usuario.contrasena == contrasena:
            session['usuario'] = usuario.nombre_usuario
            session['rol'] = usuario.rol
            return redirect(url_for('panel_control'))
        else:
            flash('Credenciales incorrectas', 'error')
            
    return render_template('iniciar_sesion.html')

@app.route('/registro', methods=['GET', 'POST'])
def registro():
    if request.method == 'POST':
        nombre_usuario = request.form.get('nombre_usuario')
        contrasena = request.form.get('contrasena')
        
        # Check if user exists
        usuario_existente = Usuario.query.filter_by(nombre_usuario=nombre_usuario).first()
        
        if usuario_existente:
            flash('El nombre de usuario ya existe. Por favor, elige otro.', 'error')
        elif len(nombre_usuario) < 3 or len(contrasena) < 3:
            flash('El usuario y la contraseña deben tener al menos 3 caracteres.', 'error')
        else:
            # Create new user
            nuevo_usuario = Usuario(nombre_usuario=nombre_usuario, contrasena=contrasena, rol='cliente')
            db.session.add(nuevo_usuario)
            db.session.commit()
            
            flash('Cuenta creada correctamente. ¡Ya puedes iniciar sesión!', 'success')
            return redirect(url_for('iniciar_sesion'))
            
    return render_template('registro.html')

@app.route('/cerrar_sesion')
def cerrar_sesion():
    session.clear()
    return redirect(url_for('inicio'))

@app.route('/panel_control')
def panel_control():
    if 'usuario' not in session:
        return redirect(url_for('iniciar_sesion'))
    
    rol = session.get('rol')
    nombre_usuario = session.get('usuario')
    
    todas_incidencias = cargar_incidencias()
    
    if rol == 'admin':
        # Get list of other admins for assignment
        admins = [u.nombre_usuario for u in Usuario.query.filter_by(rol='admin').all()]
        return render_template('panel_admin.html', incidencias=todas_incidencias, usuario=nombre_usuario, admins=admins)
    else:
        # Client sees only their incidents
        mis_incidencias = [i for i in todas_incidencias if i['nombre_usuario'] == nombre_usuario]
        return render_template('panel_cliente.html', incidencias=mis_incidencias, usuario=nombre_usuario)

@app.route('/crear_incidencia', methods=['POST'])
def crear_incidencia():
    if 'usuario' not in session:
        return redirect(url_for('iniciar_sesion'))
        
    asunto = request.form.get('asunto')
    descripcion = request.form.get('descripcion')
    categoria = request.form.get('categoria')
    prioridad = request.form.get('prioridad')
    
    if asunto and descripcion and categoria and prioridad:
        guardar_incidencia(session['usuario'], asunto, descripcion, categoria, prioridad)
        flash('Incidencia creada correctamente', 'success')
    
    return redirect(url_for('panel_control'))

@app.route('/gestionar_incidencia', methods=['POST'])
def gestionar_incidencia():
    if 'usuario' not in session or session.get('rol') != 'admin':
        return redirect(url_for('iniciar_sesion'))
        
    id_incidencia = request.form.get('id_incidencia')
    nuevo_estado = request.form.get('estado')
    nueva_prioridad = request.form.get('prioridad')
    nuevo_asignado = request.form.get('asignado_a')
    
    if id_incidencia:
        if nuevo_estado == 'Resuelto':
            incidencia = Incidencia.query.get(id_incidencia)
            if incidencia:
                db.session.delete(incidencia)
                db.session.commit()
                flash('Incidencia resuelta y eliminada', 'success')
        else:
            actualizar_incidencia_completa(id_incidencia, nuevo_estado, nueva_prioridad, nuevo_asignado)
            flash('Cambios guardados correctamente', 'success')
        
    return redirect(url_for('panel_control'))

# Catálogo de máquinas Ubuntu disponibles
CATALOGO_VMS = [
    {
        'id': 'ubuntu-micro',
        'nombre': 'Ubuntu Micro',
        'vcpu': 1,
        'ram': '1 GB',
        'disco': '20 GB SSD',
        'red': '100 Mbps',
        'precio': '4.99',
        'descripcion': 'Perfecto para empezar, hacer pruebas o montar una web pequeña.',
        'so': 'Ubuntu 24.04 LTS',
        'badge': 'STARTER'
    },
    {
        'id': 'ubuntu-small',
        'nombre': 'Ubuntu Small',
        'vcpu': 2,
        'ram': '2 GB',
        'disco': '40 GB SSD',
        'red': '250 Mbps',
        'precio': '9.99',
        'descripcion': 'Ideal para páginas de empresas, blogs con visitas y aplicaciones web.',
        'so': 'Ubuntu 24.04 LTS',
        'badge': 'POPULAR'
    },
    {
        'id': 'ubuntu-medium',
        'nombre': 'Ubuntu Medium',
        'vcpu': 4,
        'ram': '4 GB',
        'disco': '80 GB SSD',
        'red': '500 Mbps',
        'precio': '19.99',
        'descripcion': 'Potencia para tiendas online, sistemas principales y bases de datos.',
        'so': 'Ubuntu 24.04 LTS',
        'badge': 'RECOMENDADO'
    },
    {
        'id': 'ubuntu-large',
        'nombre': 'Ubuntu Large',
        'vcpu': 8,
        'ram': '8 GB',
        'disco': '160 GB SSD',
        'red': '1 Gbps',
        'precio': '39.99',
        'descripcion': 'Alto rendimiento para procesar datos, mucho tráfico y aplicaciones pesadas.',
        'so': 'Ubuntu 24.04 LTS',
        'badge': 'PRO'
    },
    {
        'id': 'ubuntu-xlarge',
        'nombre': 'Ubuntu XLarge',
        'vcpu': 12,
        'ram': '16 GB',
        'disco': '320 GB SSD',
        'red': '1 Gbps',
        'precio': '74.99',
        'descripcion': 'Nuestra opción más potente para sistemas complejos y máxima exigencia.',
        'so': 'Ubuntu 24.04 LTS',
        'badge': 'ENTERPRISE'
    },
]

@app.route('/contratacion', methods=['GET'])
def contratacion():
    if 'usuario' not in session:
        return redirect(url_for('iniciar_sesion'))
    return render_template('contratacion.html', vms=CATALOGO_VMS, usuario=session.get('usuario'))

@app.route('/contratar_vm', methods=['POST'])
def contratar_vm():
    if 'usuario' not in session:
        return redirect(url_for('iniciar_sesion'))

    vm_id   = request.form.get('vm_id')
    hostname = request.form.get('hostname', '').strip()

    # Buscar la VM en el catálogo
    vm = next((v for v in CATALOGO_VMS if v['id'] == vm_id), None)
    if not vm or not hostname:
        flash('Datos de contratación inválidos.', 'error')
        return redirect(url_for('contratacion'))

    asunto = f"[CONTRATACIÓN] {vm['nombre']} — hostname: {hostname}"
    descripcion = (
        f"Solicitud de aprovisionamiento de máquina virtual:\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━\n"
        f"  Usuario:      {session['usuario']}\n"
        f"  Plan:         {vm['nombre']} ({vm['badge']})\n"
        f"  Hostname:     {hostname}\n"
        f"  SO:           {vm['so']}\n"
        f"  vCPU:         {vm['vcpu']} cores\n"
        f"  RAM:          {vm['ram']}\n"
        f"  Disco:        {vm['disco']}\n"
        f"  Red:          {vm['red']}\n"
        f"  Precio/mes:   {vm['precio']} €\n"
        f"━━━━━━━━━━━━━━━━━━━━━━━━"
    )

    guardar_incidencia(
        nombre_usuario=session['usuario'],
        asunto=asunto,
        descripcion=descripcion,
        categoria='Contratacion',
        prioridad='Alta'
    )

    flash(f'¡Solicitud enviada! Tu máquina "{hostname}" será aprovisionada en breve.', 'success')
    return redirect(url_for('panel_control'))

if __name__ == '__main__':
    app.run(
        debug=os.environ.get('FLASK_DEBUG', 'false').lower() == 'true',
        port=int(os.environ.get('FLASK_PORT', 5000)),
        host=os.environ.get('FLASK_HOST', '0.0.0.0')
    )
