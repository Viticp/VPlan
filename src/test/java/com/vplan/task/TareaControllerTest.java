package com.vplan.task;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.endsWith;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Pruebas de la API completa (controlador + servicio + repositorio) con MockMvc
 * y H2. Se comprueban codigos HTTP, cuerpo JSON y errores.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class TareaControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private TareaRepository repositorio;

    private static final String JSON_VALIDO = """
            {
              "titulo": "Preparar entrega",
              "descripcion": "Modulo de desarrollo",
              "prioridad": "ALTA",
              "estado": "PENDIENTE",
              "fechaLimite": "2026-12-31"
            }
            """;

    @Test
    void listaTodasLasTareas() throws Exception {
        repositorio.save(new Tarea("Primera", null, Prioridad.BAJA, Estado.PENDIENTE, null));
        repositorio.save(new Tarea("Segunda", null, Prioridad.ALTA, Estado.COMPLETADA, null));

        mockMvc.perform(get("/api/tareas"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[*].titulo", containsInAnyOrder("Primera", "Segunda")));
    }

    @Test
    void listaFiltrandoPorEstadoYPrioridad() throws Exception {
        repositorio.save(new Tarea("Pendiente alta", null, Prioridad.ALTA, Estado.PENDIENTE, null));
        repositorio.save(new Tarea("Pendiente baja", null, Prioridad.BAJA, Estado.PENDIENTE, null));
        repositorio.save(new Tarea("Completada alta", null, Prioridad.ALTA, Estado.COMPLETADA, null));

        mockMvc.perform(get("/api/tareas").param("estado", "PENDIENTE").param("prioridad", "ALTA"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].titulo").value("Pendiente alta"));
    }

    @Test
    void obtieneUnaTareaPorId() throws Exception {
        Tarea guardada = repositorio.save(new Tarea(
                "Con fecha", "Detalle", Prioridad.MEDIA, Estado.EN_PROCESO, LocalDate.of(2027, 3, 1)));

        mockMvc.perform(get("/api/tareas/{id}", guardada.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(guardada.getId()))
                .andExpect(jsonPath("$.titulo").value("Con fecha"))
                .andExpect(jsonPath("$.prioridad").value("MEDIA"))
                .andExpect(jsonPath("$.estado").value("EN_PROCESO"))
                .andExpect(jsonPath("$.fechaLimite").value("2027-03-01"))
                .andExpect(jsonPath("$.completadoEn").value(nullValue()));
    }

    @Test
    void devuelve404SiLaTareaNoExiste() throws Exception {
        mockMvc.perform(get("/api/tareas/{id}", 999_999))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.mensaje").value("No existe ninguna tarea con id 999999"))
                .andExpect(jsonPath("$.ruta").value("/api/tareas/999999"));
    }

    @Test
    void creaUnaTareaYDevuelve201ConLocation() throws Exception {
        mockMvc.perform(post("/api/tareas")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(JSON_VALIDO))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.id").isNumber())
                .andExpect(jsonPath("$.titulo").value("Preparar entrega"))
                .andExpect(jsonPath("$.estado").value("PENDIENTE"))
                .andExpect(jsonPath("$.creadoEn").exists())
                .andExpect(jsonPath("$.actualizadoEn").exists());
    }

    @Test
    void creaUnaTareaSinEstadoYLaDejaPendiente() throws Exception {
        String cuerpo = """
                {"titulo": "Sin estado", "prioridad": "BAJA"}
                """;

        mockMvc.perform(post("/api/tareas")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpo))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.estado").value("PENDIENTE"))
                .andExpect(jsonPath("$.completadoEn").value(nullValue()));
    }

    @Test
    void creaUnaTareaCompletadaConFechaDeFinalizacion() throws Exception {
        String cuerpo = """
                {"titulo": "Ya hecha", "prioridad": "MEDIA", "estado": "COMPLETADA"}
                """;

        mockMvc.perform(post("/api/tareas")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpo))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.estado").value("COMPLETADA"))
                .andExpect(jsonPath("$.completadoEn").value(endsWith("Z")));
    }

    @Test
    void reabrirUnaTareaBorraSuFechaDeFinalizacion() throws Exception {
        Tarea completada = repositorio.save(new Tarea(
                "Completada", null, Prioridad.MEDIA, Estado.COMPLETADA, null));

        String cuerpo = """
                {"titulo": "Completada", "prioridad": "MEDIA", "estado": "EN_PROCESO"}
                """;

        mockMvc.perform(put("/api/tareas/{id}", completada.getId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpo))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.estado").value("EN_PROCESO"))
                .andExpect(jsonPath("$.completadoEn").value(nullValue()));
    }

    @Test
    void rechazaUnaTareaSinTituloNiPrioridad() throws Exception {
        String cuerpo = """
                {"descripcion": "Sin datos obligatorios"}
                """;

        mockMvc.perform(post("/api/tareas")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpo))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.campos.titulo").value("El titulo es obligatorio"))
                .andExpect(jsonPath("$.campos.prioridad").value("La prioridad es obligatoria"));
    }

    @Test
    void rechazaUnTituloDemasiadoLargo() throws Exception {
        String cuerpo = """
                {"titulo": "%s", "prioridad": "MEDIA"}
                """.formatted("x".repeat(121));

        mockMvc.perform(post("/api/tareas")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpo))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.campos.titulo")
                        .value("El titulo no puede superar 120 caracteres"));
    }

    @Test
    void rechazaUnEstadoQueNoExiste() throws Exception {
        String cuerpo = """
                {"titulo": "Estado raro", "prioridad": "MEDIA", "estado": "URGENTE"}
                """;

        mockMvc.perform(post("/api/tareas")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpo))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.mensaje").value(
                        "El cuerpo de la peticion no es un JSON valido o contiene un valor no permitido"));
    }

    @Test
    void rechazaUnFiltroConValorNoPermitido() throws Exception {
        mockMvc.perform(get("/api/tareas").param("estado", "URGENTE"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.mensaje").value("El parametro 'estado' tiene un valor no permitido"));
    }

    @Test
    void actualizaUnaTarea() throws Exception {
        Tarea guardada = repositorio.save(new Tarea("Antigua", null, Prioridad.BAJA, Estado.PENDIENTE, null));

        String cuerpo = """
                {
                  "titulo": "Actualizada",
                  "descripcion": "Nueva descripcion",
                  "prioridad": "ALTA",
                  "estado": "COMPLETADA",
                  "fechaLimite": "2027-06-30"
                }
                """;

        mockMvc.perform(put("/api/tareas/{id}", guardada.getId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(cuerpo))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.titulo").value("Actualizada"))
                .andExpect(jsonPath("$.estado").value("COMPLETADA"))
                .andExpect(jsonPath("$.fechaLimite").value("2027-06-30"))
                .andExpect(jsonPath("$.completadoEn").value(endsWith("Z")));
    }

    @Test
    void devuelve404AlActualizarUnaTareaInexistente() throws Exception {
        mockMvc.perform(put("/api/tareas/{id}", 999_999)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(JSON_VALIDO))
                .andExpect(status().isNotFound());
    }

    @Test
    void eliminaUnaTareaYDevuelve204() throws Exception {
        Tarea guardada = repositorio.save(new Tarea("Borrar", null, Prioridad.BAJA, Estado.PENDIENTE, null));

        mockMvc.perform(delete("/api/tareas/{id}", guardada.getId()))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/tareas/{id}", guardada.getId()))
                .andExpect(status().isNotFound());
    }

    @Test
    void devuelve404AlEliminarUnaTareaInexistente() throws Exception {
        mockMvc.perform(delete("/api/tareas/{id}", 999_999))
                .andExpect(status().isNotFound());
    }

    @Test
    void laRutaDeSaludSigueRespondiendo() throws Exception {
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.database").value("UP"));
    }
}
