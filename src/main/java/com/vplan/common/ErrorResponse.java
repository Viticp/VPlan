package com.vplan.common;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;
import java.util.Map;

/**
 * Formato unico de error de la API.
 *
 * <p>Se usa en todas las respuestas de error para que el frontend solo tenga que
 * entender un contrato:</p>
 *
 * <pre>
 * {
 *   "timestamp": "2026-11-17T10:00:00Z",
 *   "status": 400,
 *   "error": "Bad Request",
 *   "mensaje": "La peticion no es valida",
 *   "ruta": "/api/tareas",
 *   "campos": { "titulo": "El titulo es obligatorio" }
 * }
 * </pre>
 *
 * <p>{@code campos} solo aparece en los errores de validacion.</p>
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ErrorResponse(
        Instant timestamp,
        int status,
        String error,
        String mensaje,
        String ruta,
        Map<String, String> campos) {

    public static ErrorResponse de(int status, String error, String mensaje, String ruta) {
        return new ErrorResponse(Instant.now(), status, error, mensaje, ruta, null);
    }

    public static ErrorResponse deValidacion(String mensaje, String ruta, Map<String, String> campos) {
        return new ErrorResponse(Instant.now(), 400, "Bad Request", mensaje, ruta, campos);
    }
}
