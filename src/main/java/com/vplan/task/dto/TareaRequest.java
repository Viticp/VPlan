package com.vplan.task.dto;

import com.vplan.task.Estado;
import com.vplan.task.Prioridad;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

/**
 * Datos que el cliente envia para crear o actualizar una tarea.
 *
 * <p>No incluye {@code id}, {@code creadoEn} ni {@code actualizadoEn}: esos los
 * decide el servidor. Tampoco incluye un dueño, porque VPlan es de un solo
 * usuario.</p>
 *
 * <p>{@code estado} es opcional: al crear, si no se indica, la tarea empieza en
 * {@code PENDIENTE}; al actualizar, si no se indica, se conserva el actual. Eso
 * permite editar el titulo sin enviar el estado en cada peticion.</p>
 */
public record TareaRequest(

        @NotBlank(message = "El titulo es obligatorio")
        @Size(max = 120, message = "El titulo no puede superar 120 caracteres")
        String titulo,

        @Size(max = 2000, message = "La descripcion no puede superar 2000 caracteres")
        String descripcion,

        @NotNull(message = "La prioridad es obligatoria")
        Prioridad prioridad,

        Estado estado,

        LocalDate fechaLimite) {
}
