package com.vplan.common;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;

/**
 * Endpoint publico de salud.
 *
 * <p>No se limita a responder "OK": ejecuta {@code SELECT 1} contra la base de
 * datos para demostrar que la conexion real funciona. Si la base de datos no
 * responde, devuelve 503 para que un monitor externo lo detecte.</p>
 */
@RestController
@RequestMapping("/api")
public class HealthController {

    private static final Logger log = LoggerFactory.getLogger(HealthController.class);

    private final JdbcTemplate jdbcTemplate;

    public HealthController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @GetMapping("/health")
    public ResponseEntity<HealthResponse> health() {
        boolean databaseUp = isDatabaseUp();

        HealthResponse body = new HealthResponse(
                databaseUp ? "UP" : "DOWN",
                "vplan",
                databaseUp ? "UP" : "DOWN",
                Instant.now());

        return databaseUp
                ? ResponseEntity.ok(body)
                : ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(body);
    }

    private boolean isDatabaseUp() {
        try {
            Integer result = jdbcTemplate.queryForObject("SELECT 1", Integer.class);
            return result != null && result == 1;
        } catch (DataAccessException ex) {
            // Se registra el tipo de error (util para diagnosticar) pero no el
            // mensaje, que podria contener host, usuario o cadena JDBC.
            log.warn("La comprobacion de la base de datos ha fallado ({})", ex.getClass().getSimpleName());
            return false;
        }
    }
}
