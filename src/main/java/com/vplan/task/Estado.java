package com.vplan.task;

/**
 * Estado de una tarea.
 *
 * <p>El ciclo de vida previsto es:</p>
 *
 * <pre>PENDIENTE → EN_PROCESO → COMPLETADA</pre>
 *
 * <p>La base de datos ya limita los valores con una restriccion {@code CHECK}.</p>
 */
public enum Estado {
    PENDIENTE,
    EN_PROCESO,
    COMPLETADA
}
