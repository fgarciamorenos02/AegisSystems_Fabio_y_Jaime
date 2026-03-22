import os
import datetime
from flask import Flask, render_template, request, redirect, url_for, session, flash
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)
app.secret_key = 'supersecretkey'  # In production, use environment variable

# Conexión a Base de Datos MariaDB (192.168.20.50 en VL20 BACKEND)
# Fallback a SQLite para desarrollo local si no hay variable de entorno
default_db_uri = 'sqlite:///' + os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data', 'aegis.db')
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'mysql+pymysql://root:root@192.168.20.50/aegis_web')
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
        actualizar_incidencia_completa(id_incidencia, nuevo_estado, nueva_prioridad, nuevo_asignado)
        flash('Cambios guardados correctamente', 'success')
        
    return redirect(url_for('panel_control'))

if __name__ == '__main__':
    app.run(debug=True, port=5000)
