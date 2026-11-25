package com.vplan;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.ResultSet;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Comprueba que la migracion V2 deja el esquema de un solo usuario:
 * sin tabla usuarios y sin la columna tareas.usuario_id.
 *
 * <p>Se usa {@link DatabaseMetaData} en lugar de SQL especifico para que el
 * mismo test funcione en H2 (tests) y en MySQL.</p>
 */
@SpringBootTest
@ActiveProfiles("test")
class SchemaSingleUserTest {

    @Autowired
    private DataSource dataSource;

    @Test
    void laTablaUsuariosYaNoExiste() throws Exception {
        try (Connection connection = dataSource.getConnection()) {
            DatabaseMetaData metaData = connection.getMetaData();
            assertThat(existeTabla(metaData, "usuarios")).isFalse();
        }
    }

    @Test
    void laTablaTareasSigueExistiendoSinUsuarioId() throws Exception {
        try (Connection connection = dataSource.getConnection()) {
            DatabaseMetaData metaData = connection.getMetaData();
            assertThat(existeTabla(metaData, "tareas")).isTrue();
            assertThat(existeColumna(metaData, "tareas", "usuario_id")).isFalse();
            assertThat(existeColumna(metaData, "tareas", "estado")).isTrue();
        }
    }

    private boolean existeTabla(DatabaseMetaData metaData, String tabla) throws Exception {
        try (ResultSet rs = metaData.getTables(null, null, "%", new String[] {"TABLE"})) {
            while (rs.next()) {
                if (tabla.equalsIgnoreCase(rs.getString("TABLE_NAME"))) {
                    return true;
                }
            }
        }
        return false;
    }

    private boolean existeColumna(DatabaseMetaData metaData, String tabla, String columna) throws Exception {
        try (ResultSet rs = metaData.getColumns(null, null, "%", "%")) {
            while (rs.next()) {
                if (tabla.equalsIgnoreCase(rs.getString("TABLE_NAME"))
                        && columna.equalsIgnoreCase(rs.getString("COLUMN_NAME"))) {
                    return true;
                }
            }
        }
        return false;
    }
}
