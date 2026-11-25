package com.vplan.task;

import com.vplan.task.dto.TareaRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Reglas de negocio de las tareas.
 *
 * <p>Devuelve entidades, no DTOs: la conversion a JSON es responsabilidad del
 * controlador. Asi el servicio no depende del formato de la API.</p>
 */
@Service
@Transactional(readOnly = true)
public class TareaService {

    private final TareaRepository repositorio;

    public TareaService(TareaRepository repositorio) {
        this.repositorio = repositorio;
    }

    /**
     * Lista tareas, opcionalmente filtradas por estado y/o prioridad.
     * Sin filtros devuelve todas.
     */
    public List<Tarea> listar(Estado estado, Prioridad prioridad) {
        if (estado != null && prioridad != null) {
            return repositorio.findByEstadoAndPrioridadOrderByIdAsc(estado, prioridad);
        }
        if (estado != null) {
            return repositorio.findByEstadoOrderByIdAsc(estado);
        }
        if (prioridad != null) {
            return repositorio.findByPrioridadOrderByIdAsc(prioridad);
        }
        return repositorio.findAllByOrderByIdAsc();
    }

    public Tarea obtener(Long id) {
        return repositorio.findById(id)
                .orElseThrow(() -> new TareaNoEncontradaException(id));
    }

    @Transactional
    public Tarea crear(TareaRequest peticion) {
        Tarea tarea = new Tarea(
                limpiar(peticion.titulo()),
                limpiar(peticion.descripcion()),
                peticion.prioridad(),
                peticion.estado(),
                peticion.fechaLimite());

        // Si no se indica estado, la entidad lo deja en PENDIENTE en @PrePersist.
        return repositorio.save(tarea);
    }

    @Transactional
    public Tarea actualizar(Long id, TareaRequest peticion) {
        Tarea tarea = obtener(id);

        tarea.setTitulo(limpiar(peticion.titulo()));
        tarea.setDescripcion(limpiar(peticion.descripcion()));
        tarea.setPrioridad(peticion.prioridad());
        tarea.setFechaLimite(peticion.fechaLimite());

        if (peticion.estado() != null) {
            tarea.setEstado(peticion.estado());
        }

        // La entidad esta gestionada por JPA: no hace falta save().
        // Hibernate detecta el cambio y actualiza actualizado_en en @PreUpdate.
        return tarea;
    }

    @Transactional
    public void eliminar(Long id) {
        if (!repositorio.existsById(id)) {
            throw new TareaNoEncontradaException(id);
        }
        repositorio.deleteById(id);
    }

    /**
     * Normaliza el texto: quita espacios sobrantes y convierte una cadena vacia
     * en {@code null}. Asi "  " no se guarda como descripcion.
     */
    private static String limpiar(String texto) {
        if (texto == null) {
            return null;
        }
        String limpio = texto.trim();
        return limpio.isEmpty() ? null : limpio;
    }
}
