package com.vplan.task.dto;

import com.vplan.task.Estado;
import com.vplan.task.Prioridad;
import com.vplan.task.Tarea;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Representacion de una tarea en las respuestas JSON.
 *
 * <p>Es un {@code record} (inmutable) y se construye desde la entidad con
 * {@link #desde(Tarea)}. Asi la entidad no se expone nunca directamente y sus
 * cambios internos no alteran el contrato de la API.</p>
 *
 * <p>{@code completadoEn} se devuelve como instante UTC (con sufijo {@code Z})
 * para que el navegador pueda situarlo en el dia local de la persona. Las
 * tareas antiguas sin fecha de finalizacion devuelven {@code null}.</p>
 */
public record TareaResponse(
        Long id,
        String titulo,
        String descripcion,
        Prioridad prioridad,
        Estado estado,
        LocalDate fechaLimite,
        LocalDateTime creadoEn,
        LocalDateTime actualizadoEn,
        Instant completadoEn) {

    public static TareaResponse desde(Tarea tarea) {
        return new TareaResponse(
                tarea.getId(),
                tarea.getTitulo(),
                tarea.getDescripcion(),
                tarea.getPrioridad(),
                tarea.getEstado(),
                tarea.getFechaLimite(),
                tarea.getCreadoEn(),
                tarea.getActualizadoEn(),
                tarea.getCompletadoEn());
    }
}
