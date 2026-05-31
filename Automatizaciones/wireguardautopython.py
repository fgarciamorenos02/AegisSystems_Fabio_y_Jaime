import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import paramiko
import threading
import time

#AJUSTES DE INFRAESTRUCTURA
IP_NODO_CENTRAL = "93.93.115.119"
ADMIN_USER = "root"

def imprimir_en_consola(texto):
    """Muestra eventos en el monitor de la interfaz."""
    monitor_sistema.insert(tk.END, texto + "\n")
    monitor_sistema.see(tk.END)

def ejecucion_remota_bash():
    """Conecta por SSH y lanza el script .sh de forma interactiva."""
    password_root = entrada_pass_ssh.get()
    nombre_dispositivo = entrada_nombre.get()
    clave_publica_vpn = entrada_pubkey.get()

    if not password_root or not nombre_dispositivo or not clave_publica_vpn:
        messagebox.showwarning("Aegis Guard", "Faltan parámetros críticos para el despliegue.")
        return

    boton_accion.config(state="disabled", text="CONECTANDO...")
    monitor_sistema.delete(1.0, tk.END)
    imprimir_en_consola(f"[*] Estableciendo conexión segura con {IP_NODO_CENTRAL}...")

    try:
        # Configuración del Cliente SSH
        cliente_ssh = paramiko.SSHClient()
        cliente_ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        cliente_ssh.connect(hostname=IP_NODO_CENTRAL, username=ADMIN_USER, password=password_root, timeout=15)

        imprimir_en_consola("[OK] Túnel SSH abierto. Iniciando entorno Bash...")
        canal = cliente_ssh.invoke_shell()
        time.sleep(1) # Esperar a que el shell responda

        # Ejecutamos el script alojado en el servidor
        # IMPORTANTE: Asegúrate de que la ruta /root/script_vpn.sh sea la correcta
        canal.send("bash /root/wiresharkauto\n")
        time.sleep(1)

        # Inviamos la Clave Pública cuando el script la pida
        canal.send(f"{clave_publica_vpn}\n")
        time.sleep(1)

        # Enviamos el Nombre del Equipo cuando el script lo pida
        canal.send(f"{nombre_dispositivo}\n")
        time.sleep(2) # Tiempo para que el script procese y genere la salida

        # Capturamos todo lo que escupió la terminal
        salida_final = canal.recv(10000).decode('utf-8')
        
        imprimir_en_consola("\n--- REPORTE DE DESPLIEGUE AEGIS ---")
        imprimir_en_consola(salida_final)

        cliente_ssh.close()
        imprimir_en_consola("\n[!] Operación finalizada. Conexión cerrada.")

    except Exception as error:
        imprimir_en_consola(f"\n[X] ERROR DE SISTEMA: {str(error)}")
        messagebox.showerror("Fallo de Red", f"Error en el protocolo: {error}")
    
    boton_accion.config(state="normal", text="EJECUTAR DESPLIEGUE")

def iniciar_protocolo():
    """Lanza el proceso en segundo plano."""
    hilo_seguridad = threading.Thread(target=ejecucion_remota_bash, daemon=True)
    hilo_seguridad.start()

#DISEÑO DE LA TERMINAL AEGIS
ventana = tk.Tk()
ventana.title("Aegis Secure LAN Manager")
ventana.geometry("600x700")
ventana.configure(bg="#020617") # Azul casi negro

# Titulo Estilo 'Tech'
tk.Label(ventana, text="AEGIS VPN LAN", font=("Arial", 18, "bold"), 
         bg="#020617", fg="#00ffff").pack(pady=20)

# Contenedor de Entradas
marco_datos = tk.Frame(ventana, bg="#0f172a", padx=20, pady=20, highlightbackground="#1e293b", highlightthickness=1)
marco_datos.pack(fill="x", padx=40)

# Password SSH
tk.Label(marco_datos, text="PASSWORD ROOT SSH", bg="#0f172a", fg="#94a3b8", font=("Arial", 9, "bold")).pack()
entrada_pass_ssh = tk.Entry(marco_datos, show="*", width=30, justify="center", bg="#020617", fg="#38bdf8", borderwidth=0)
entrada_pass_ssh.pack(pady=5)

# Nombre Cliente
tk.Label(marco_datos, text="IDENTIFICADOR DEL EQUIPO", bg="#0f172a", fg="#94a3b8", font=("Arial", 9, "bold")).pack(pady=(10,0))
entrada_nombre = tk.Entry(marco_datos, width=40, bg="#1e293b", fg="white", borderwidth=0)
entrada_nombre.pack(pady=5)

# Clave Pública
tk.Label(marco_datos, text="CLAVE PÚBLICA CLIENTE (WIRE GUARD)", bg="#0f172a", fg="#94a3b8", font=("Arial", 9, "bold")).pack(pady=(10,0))
entrada_pubkey = tk.Entry(marco_datos, width=40, bg="#1e293b", fg="white", borderwidth=0)
entrada_pubkey.pack(pady=5)

# Botón Maestro
boton_accion = tk.Button(ventana, text="EJECUTAR DESPLIEGUE", command=iniciar_protocolo, 
                         bg="#2563eb", fg="white", font=("Arial", 11, "bold"), 
                         padx=40, pady=15, relief="flat", activebackground="#1d4ed8", cursor="hand2")
boton_accion.pack(pady=25)

# Monitor de Salida
tk.Label(ventana, text="MONITOR DE ACTIVIDAD REMOTA", bg="#020617", fg="#10b981", font=("Arial", 8)).pack()
monitor_sistema = scrolledtext.ScrolledText(ventana, width=75, height=20, 
                                           bg="#000000", fg="#10b981", font=("Consolas", 9))
monitor_sistema.pack(padx=20, pady=10)

ventana.mainloop()