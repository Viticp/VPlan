package com.vplan;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

/**
 * Comprueba que el contexto de Spring arranca completo con H2 y que Flyway
 * aplica las migraciones sin errores.
 */
@SpringBootTest
@ActiveProfiles("test")
class VPlanApplicationTests {

    @Test
    void contextLoads() {
        // Si el contexto no puede arrancar, el test falla.
    }
}
