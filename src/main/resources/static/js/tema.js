/* ==========================================================================
   VPlan · tema.js
   --------------------------------------------------------------------------
   Fase 7: tema claro/oscuro.
   - El script inline del <head> aplica el tema antes del primer pintado.
   - Este módulo mantiene el interruptor, guarda la preferencia y escucha
     cambios del sistema y de otras pestañas.
   - Solo hay dos estados: 'claro' y 'oscuro'.
   ========================================================================== */

const CLAVE = 'vplan-tema';
const OSCURO = 'oscuro';
const CLARO = 'claro';
const COLOR_CLARO = '#f3f6fb';
const COLOR_OSCURO = '#0b0f19';

const raiz = document.documentElement;
const boton = document.getElementById('cambiador-tema');
const textoBoton = boton ? boton.querySelector('.cambiador-texto') : null;
const metaTema = document.getElementById('meta-tema');
const prefiereOscuro = window.matchMedia('(prefers-color-scheme: dark)');
const prefiereMenosMovimiento = window.matchMedia('(prefers-reduced-motion: reduce)');

let preferencia = leerPreferencia();
let temporizadorTransicion = null;

function leerPreferencia() {
    try {
        const valor = window.localStorage.getItem(CLAVE);
        return valor === CLARO || valor === OSCURO ? valor : null;
    } catch (error) {
        return null;
    }
}

function guardarPreferencia(tema) {
    try {
        window.localStorage.setItem(CLAVE, tema);
    } catch (error) {
        // Sin almacenamiento: el tema funciona durante la sesión actual.
    }
}

function temaDelSistema() {
    return prefiereOscuro.matches ? OSCURO : CLARO;
}

function temaAplicado() {
    return raiz.getAttribute('data-theme') === OSCURO ? OSCURO : CLARO;
}

function actualizarControl(tema) {
    if (!boton) {
        return;
    }
    const oscuro = tema === OSCURO;
    boton.setAttribute('aria-checked', String(oscuro));
    boton.setAttribute('title', oscuro ? 'Cambiar al modo claro' : 'Cambiar al modo oscuro');
    if (textoBoton) {
        textoBoton.textContent = oscuro ? 'Oscuro' : 'Claro';
    }
}

function aplicarTema(tema, { animar = false } = {}) {
    if (animar && !prefiereMenosMovimiento.matches) {
        raiz.classList.add('tema-cambiando');
        window.clearTimeout(temporizadorTransicion);
        temporizadorTransicion = window.setTimeout(() => {
            raiz.classList.remove('tema-cambiando');
        }, 260);
    }

    if (tema === OSCURO) {
        raiz.setAttribute('data-theme', OSCURO);
    } else {
        raiz.removeAttribute('data-theme');
    }

    if (metaTema) {
        metaTema.setAttribute('content', tema === OSCURO ? COLOR_OSCURO : COLOR_CLARO);
    }

    actualizarControl(tema);
}

if (boton) {
    boton.addEventListener('click', () => {
        const siguiente = temaAplicado() === OSCURO ? CLARO : OSCURO;
        preferencia = siguiente;
        guardarPreferencia(siguiente);
        aplicarTema(siguiente, { animar: true });
    });
}

// Mientras no haya preferencia guardada, el tema sigue al sistema.
prefiereOscuro.addEventListener('change', (evento) => {
    if (preferencia === null) {
        aplicarTema(evento.matches ? OSCURO : CLARO, { animar: true });
    }
});

// Sincronización entre pestañas de la misma aplicación.
window.addEventListener('storage', (evento) => {
    if (evento.key !== CLAVE) {
        return;
    }
    const nuevo = evento.newValue;
    preferencia = nuevo === CLARO || nuevo === OSCURO ? nuevo : null;
    aplicarTema(preferencia || temaDelSistema(), { animar: true });
});

// Sincroniza el control con el tema que ya aplicó el script inline.
aplicarTema(preferencia || temaAplicado());
