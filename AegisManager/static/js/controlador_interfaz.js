// Gestión de Temas
function alternarTema() {
    // Tailwind usa clase 'dark' en html
    const html = document.documentElement;
    if (html.classList.contains('dark')) {
        html.classList.remove('dark');
        localStorage.setItem('tema', 'light');
    } else {
        html.classList.add('dark');
        localStorage.setItem('tema', 'dark');
    }
}

// Inicializar Tema (Default Dark)
const temaGuardado = localStorage.getItem('tema');
// Si no hay tema guardado o es dark, poner dark. 
if (temaGuardado === 'dark' || !temaGuardado) {
    document.documentElement.classList.add('dark');
} else {
    document.documentElement.classList.remove('dark');
}

// Autenticación y Compartido
let nodoActual = null;

function cerrarSesion() {
    localStorage.removeItem('proxmox_host');
    window.location.href = '/';
}

function formatearBytes(bytes, decimales = 2) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const dm = decimales < 0 ? 0 : decimales;
    const tamanios = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + tamanios[i];
}

// Lógica del Panel de Control
async function cargarNodos() {
    const lista = document.getElementById('node-list');
    if (!lista) return; // No estamos en el dashboard

    try {
        const respuesta = await fetch('/api/nodos');
        if (respuesta.status === 401) {
            cerrarSesion();
            return;
        }
        if (!respuesta.ok) throw new Error('Fallo al obtener nodos');

        const nodos = await respuesta.json();
        lista.innerHTML = '';

        nodos.forEach(nodo => {
            const li = document.createElement('li');
            // Tailwind Classes:
            // .node-item logic -> cursor-pointer p-3 rounded flex justify-between items-center hover:bg-white/5 transition-colors
            // active -> bg-white/10 border-l-2 border-primary

            const isOnline = nodo.status === 'online';
            const statusColor = isOnline ? 'bg-success' : 'bg-muted';
            const statusShadow = isOnline ? 'shadow-[0_0_10px_white]' : '';

            li.className = `cursor-pointer p-3 rounded flex justify-between items-center hover:bg-white/5 transition-colors mb-1`;
            if (nodo.node === nodoActual) {
                li.classList.add('bg-white/10', 'border-l-2', 'border-primary');
            }

            li.innerHTML = `
                <div class="flex items-center gap-2">
                    <i class="fa-solid fa-server"></i>
                    <span>${nodo.node}</span>
                </div>
                <span class="w-2.5 h-2.5 rounded-full inline-block ${statusColor} ${statusShadow}"></span>
            `;
            li.onclick = () => seleccionarNodo(nodo.node, li);
            lista.appendChild(li);
        });

        // Seleccionar automáticamente el primer nodo si no hay selección
        if (nodos.length > 0 && !nodoActual) {
            seleccionarNodo(nodos[0].node, lista.firstChild); // Note: this might need adjustment if li class update logic is strict
        }

    } catch (error) {
        lista.innerHTML = `<li class="text-danger text-center">Error: ${error.message}</li>`;
    }
}

function seleccionarNodo(nombreNodo, elementoLi) {
    nodoActual = nombreNodo;

    // Actualizar UI activa manualmente (re-render simple o manipulación de clases)
    const items = document.getElementById('node-list').children;
    for (let item of items) {
        item.classList.remove('bg-white/10', 'border-l-2', 'border-primary');
    }
    elementoLi.classList.add('bg-white/10', 'border-l-2', 'border-primary');

    document.getElementById('current-view-title').textContent = `Máquinas en ${nombreNodo}`;
    cargarMaquinas();
    cargarEstadisticasNodo();
}

let intervaloNodeStats;

async function cargarEstadisticasNodo() {
    if (!nodoActual) return;

    // Show panel
    document.getElementById('node-stats-panel').classList.remove('hidden');

    const actualizar = async () => {
        if (!nodoActual) return;
        try {
            const res = await fetch(`/api/nodos/${nodoActual}/estado`);
            if (!res.ok) return;
            const data = await res.json();

            // Proxmox node status returns cpu usage directly (0.0 to 1.0) and memory in bytes
            const cpu = (data.cpu * 100).toFixed(1);
            const memBytes = data.memory.used;
            const maxMem = data.memory.total;
            const memPercent = ((memBytes / maxMem) * 100).toFixed(1);

            document.getElementById('node-cpu-val').textContent = `${cpu}%`;
            document.getElementById('node-cpu-bar').style.width = `${Math.min(cpu, 100)}%`;

            document.getElementById('node-mem-val').textContent = `${memPercent}%`;
            document.getElementById('node-mem-bar').style.width = `${Math.min(memPercent, 100)}%`;
            document.getElementById('node-mem-txt').textContent = `${formatearBytes(memBytes)} / ${formatearBytes(maxMem)}`;

            document.getElementById('node-uptime').textContent = formatearSegundos(data.uptime);

        } catch (e) { console.error(e); }
    };

    actualizar();
    if (intervaloNodeStats) clearInterval(intervaloNodeStats);
    intervaloNodeStats = setInterval(actualizar, 500);
}

async function cargarMaquinas() {
    if (!nodoActual) return;

    const cuadricula = document.getElementById('vm-grid');
    cuadricula.innerHTML = '<div class="col-span-full text-center text-muted"><i class="fa-solid fa-circle-notch fa-spin"></i> Cargando...</div>';

    try {
        const respuesta = await fetch(`/api/nodos/${nodoActual}/maquinas`);
        if (respuesta.status === 401) {
            cerrarSesion();
            return;
        }
        if (!respuesta.ok) throw new Error('Fallo al obtener máquinas');

        const maquinas = await respuesta.json();
        console.log("Cargando máquinas:", maquinas);
        cuadricula.innerHTML = '';

        if (maquinas.length === 0) {
            cuadricula.innerHTML = '<div class="col-span-full text-center text-muted">No se encontraron máquinas en este nodo.</div>';
            return;
        }

        maquinas.forEach((vm, indice) => {
            const estaEjecutando = vm.status === 'running';
            const statusClass = estaEjecutando ? 'bg-black dark:bg-white shadow-[0_0_5px_rgba(0,0,0,0.2)] dark:shadow-[0_0_8px_white/50]' : 'bg-slate-200 dark:bg-zinc-800';

            const tarjeta = document.createElement('div');
            // Tailwind card classes
            tarjeta.className = 'bg-white dark:bg-card border border-gray-200 dark:border-border rounded overflow-hidden cursor-pointer hover:border-black dark:hover:border-primary hover:bg-black/5 dark:hover:bg-white/5 transition-all shadow-sm dark:shadow-none';
            // tarjeta.style.animationDelay = `${indice * 0.05}s`;

            tarjeta.onclick = () => {
                window.location.href = `/detalle-maquina?nodo=${nodoActual}&id_vm=${vm.vmid}&tipo=${vm.type}`; // Fixed param name
            };

            tarjeta.innerHTML = `
                <div class="p-5 border-b border-gray-100 dark:border-border bg-slate-50 dark:bg-black/20 flex justify-between items-center">
                    <div class="font-bold flex gap-2 items-center">
                        <i class="fa-solid ${vm.type === 'lxc' ? 'fa-box' : 'fa-computer'}"></i>
                        ${vm.name || `VM ${vm.vmid}`}
                    </div>
                    <span class="w-2.5 h-2.5 rounded-full ${statusClass}"></span>
                </div>
                <div class="p-5">
                     <div class="flex justify-between mb-3 text-sm text-muted">
                        <span>ID</span> <span>${vm.vmid}</span>
                    </div>
                    <div class="flex justify-between mb-3 text-sm text-muted">
                        <span>CPU</span> <span>${(vm.cpu * 100).toFixed(1)}%</span>
                    </div>
                    <div class="flex justify-between mb-3 text-sm text-muted">
                        <span>Mem</span> <span>${formatearBytes(vm.mem)}</span>
                    </div>
                    <div class="mt-4 flex gap-2">
                        <button class="w-full py-1.5 rounded text-[10px] font-extrabold border border-black dark:border-white bg-black dark:bg-white text-white dark:text-black hover:bg-gray-800 dark:hover:bg-gray-200 transition-all uppercase tracking-widest">DETAILS</button>
                    </div>
                </div>
            `;
            cuadricula.appendChild(tarjeta);
        });

    } catch (error) {
        cuadricula.innerHTML = `<div class="col-span-full text-center text-danger">Error cargando máquinas: ${error.message}</div>`;
    }
}

// Lógica Detalle VM
async function accionMaquina(nodo, id_vm, tipo, accion) {
    if (!confirm(`¿Estás seguro de que quieres ejecutar "${accion}" en esta máquina?`)) return;

    try {
        const respuesta = await fetch(`/api/nodos/${nodo}/maquinas/${id_vm}/accion`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ accion: accion, tipo: tipo })
        });

        if (!respuesta.ok) {
            const data = await respuesta.json();
            throw new Error(data.detalle || 'Acción fallida');
        }

        // Mostrar alerta simple
        alert(`Acción ${accion} iniciada exitosamente.`);

    } catch (error) {
        alert(`Error: ${error.message}`);
    }
}

async function cargarConfiguracionVM(nodo, id_vm, tipo) {
    try {
        const respuesta = await fetch(`/api/nodos/${nodo}/maquinas/${id_vm}/configuracion?tipo=${tipo}`);
        if (respuesta.status === 401) {
            cerrarSesion();
            return;
        }
        const config = await respuesta.json();

        document.getElementById('vm-name').textContent = config.name || `VM ${id_vm}`;
        document.getElementById('vm-id').textContent = `ID: ${id_vm}`;

        // Status badge updates usually happen in stats polling, but we can set init here if we had state. 
        // We'll leave it to polling for now.

        const grid = document.getElementById('config-grid');
        grid.innerHTML = '';

        // Ayudante para añadir item
        const agregarItem = (etiqueta, valor) => {
            if (!valor) return;
            grid.innerHTML += `
                <div class="p-4 border-b border-border flex justify-between">
                    <span class="text-muted">${etiqueta}</span>
                    <span class="font-medium">${valor}</span>
                </div>
            `;
        };

        agregarItem('Tipo OS', config.ostype);
        agregarItem('Memoria', `${config.memory} MB`);
        agregarItem('Núcleos', config.cores || config.sockets * config.cores);
        agregarItem('Sockets', config.sockets);
        agregarItem('Red', config.net0);
        agregarItem('Disco (Root)', config.rootfs || config.scsi0 || config.ide0);

    } catch (e) {
        console.error("Error cargando configuración", e);
    }
}

let intervaloEstadisticas;

async function iniciarSondeoEstadisticas(nodo, id_vm, tipo) {
    const sondear = async () => {
        try {
            const respuesta = await fetch(`/api/nodos/${nodo}/maquinas/${id_vm}/estado?tipo=${tipo}`);
            if (respuesta.status === 401) {
                clearInterval(intervaloEstadisticas);
                cerrarSesion();
                return;
            }
            const datos = await respuesta.json();

            // Actualizar UI
            actualizarInterfazEstadisticas(datos);

            // Marcar estado online
            const insignia = document.getElementById('vm-status-badge');
            insignia.textContent = datos.status;
            // status colors tailwind logic needs raw style or class manipulation
            if (datos.status === 'running') {
                insignia.className = 'px-3 py-1 rounded-full text-sm font-bold bg-success text-black shadow-[0_0_10px_white]';
            } else {
                insignia.className = 'px-3 py-1 rounded-full text-sm font-bold bg-white/10 text-muted';
            }

            document.getElementById('last-update').textContent = new Date().toLocaleTimeString();

        } catch (e) {
            console.error("Error sondeo estadísticas", e);
        }
    };

    sondear(); // Inicial
    intervaloEstadisticas = setInterval(sondear, 500); // Cada 0.5s
}

function actualizarInterfazEstadisticas(datos) {
    // CPU
    const cpu = (datos.cpu * 100).toFixed(1);
    document.getElementById('cpu-usage').textContent = `${cpu}%`;
    document.getElementById('cpu-bar').style.width = `${Math.min(cpu, 100)}%`;

    // Mem
    const memBytes = datos.mem;
    const maxMem = datos.maxmem;
    const memPorcentaje = ((memBytes / maxMem) * 100).toFixed(1);
    document.getElementById('mem-usage').textContent = `${memPorcentaje}%`;
    document.getElementById('mem-bar').style.width = `${Math.min(memPorcentaje, 100)}%`;
    document.getElementById('mem-text').textContent = `${formatearBytes(memBytes)} / ${formatearBytes(maxMem)}`;

    // Red
    const redEntrada = formatearBytes(datos.netin || 0);
    const redSalida = formatearBytes(datos.netout || 0);
    document.getElementById('net-usage').innerHTML = `<span class="text-success">↓ ${redEntrada}</span>  <span class="text-primary">↑ ${redSalida}</span>`;

    // Tiempo encendido
    document.getElementById('uptime').textContent = formatearSegundos(datos.uptime);
}

function formatearSegundos(segundos) {
    if (!segundos) return '0s';
    const d = Math.floor(segundos / (3600 * 24));
    const h = Math.floor(segundos % (3600 * 24) / 3600);
    const m = Math.floor(segundos % 3600 / 60);
    const s = Math.floor(segundos % 60);

    const dMostrar = d > 0 ? d + (d == 1 ? "d " : "d ") : "";
    const hMostrar = h > 0 ? h + (h == 1 ? "h " : "h ") : "";
    const mMostrar = m + "m " + s + "s";
    return dMostrar + hMostrar + mMostrar;
}

// Lógica de Consola
function lanzarConsola() {
    const host = localStorage.getItem('proxmox_host');
    const paramsUrl = new URLSearchParams(window.location.search);
    const nodo = paramsUrl.get('nodo');
    const id_vm = paramsUrl.get('id_vm'); // Param updated
    const tipo = paramsUrl.get('tipo');

    if (host && nodo && id_vm) {
        const tipoConsola = tipo === 'lxc' ? 'lxc' : 'kvm';
        const urlConsola = `https://${host}:8006/?console=${tipoConsola}&novnc=1&vmid=${id_vm}&node=${nodo}`;
        window.open(urlConsola, '_blank');
    } else {
        alert("Falta información de sesión o máquina.");
    }
}
