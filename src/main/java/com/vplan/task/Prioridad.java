package com.vplan.task;

/**
 * Prioridad de una tarea.
 *
 * <p>Se guarda como texto (`VARCHAR`) gracias a {@code @Enumerated(EnumType.STRING)},
 * porque los valores son legibles al mirar la base de datos y no dependen del
 * orden del enum (a diferencia de guardar el ordinal).</p>
 */
public enum Prioridad {
    BAJA,
    MEDIA,
    ALTA
}
