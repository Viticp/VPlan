package com.vplan.common;

import java.time.Instant;

/**
 * Respuesta del endpoint de salud.
 *
 * @param status      "UP" si la aplicacion y la base de datos responden
 * @param application nombre de la aplicacion
 * @param database    "UP" o "DOWN"
 * @param timestamp   momento de la comprobacion (ISO-8601, UTC)
 */
public record HealthResponse(
        String status,
        String application,
        String database,
        Instant timestamp) {
}
