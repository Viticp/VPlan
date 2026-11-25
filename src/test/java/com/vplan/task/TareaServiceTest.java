package com.vplan.task;

import com.vplan.task.dto.TareaRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class TareaServiceTest {

    @Autowired
    private TareaService servicio;

    @Autowired
    private TareaRepository repositorio;

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void crearAsignaEstadoPendienteSiNoSeIndica() {
        Tarea creada = servicio.crear(peticion("Estudiar", "Tema 3", Prioridad.MEDIA, null, null));

        assertThat(creada.getId()).isNotNull();
        assertThat(creada.getEstado()).isEqualTo(Estado.PENDIENTE);
        assertThat(creada.getCreadoEn()).isNotNull();
    }

    @Test
    void crearRespetaElEstadoIndicado() {
        Tarea creada = servicio.crear(peticion("Estudiar", null, Prioridad.ALTA, Estado.EN_PROCESO, null));

        assertThat(creada.getEstado()).isEqualTo(Estado.EN_PROCESO);
    }

    @Test
    void crearUnaTareaPendienteNoRegistraFechaDeFinalizacion() {
        Tarea creada = servicio.crear(peticion("Pendiente", null, Prioridad.MEDIA, null, null));

        assertThat(creada.getCompletadoEn()).isNull();
    }

    @Test
    void crearUnaTareaCompletadaRegistraFechaDeFinalizacion() {
        Tarea creada = servicio.crear(peticion("Hecha", null, Prioridad.MEDIA, Estado.COMPLETADA, null));

        assertThat(creada.getCompletadoEn()).isNotNull();
    }

    @Test
    void crearNormalizaTituloYDescripcion() {
        Tarea creada = servicio.crear(peticion("  Con espacios  ", "   ", Prioridad.BAJA, null, null));

        assertThat(creada.getTitulo()).isEqualTo("Con espacios");
        assertThat(creada.getDescripcion()).isNull();
    }

    @Test
    void actualizarCambiaLosCamposYConservaElEstadoSiNoSeEnvia() {
        Tarea creada = servicio.crear(peticion("Original", "Descripcion", Prioridad.BAJA, Estado.EN_PROCESO, null));

        Tarea actualizada = servicio.actualizar(creada.getId(),
                peticion("Nuevo titulo", "Nueva descripcion", Prioridad.ALTA, null,
                        LocalDate.of(2027, 1, 15)));

        assertThat(actualizada.getTitulo()).isEqualTo("Nuevo titulo");
        assertThat(actualizada.getDescripcion()).isEqualTo("Nueva descripcion");
        assertThat(actualizada.getPrioridad()).isEqualTo(Prioridad.ALTA);
        assertThat(actualizada.getEstado()).isEqualTo(Estado.EN_PROCESO);
        assertThat(actualizada.getFechaLimite()).isEqualTo(LocalDate.of(2027, 1, 15));
    }

    @Test
    void actualizarCambiaElEstadoSiSeEnvia() {
        Tarea creada = servicio.crear(peticion("Tarea", null, Prioridad.MEDIA, Estado.PENDIENTE, null));

        Tarea actualizada = servicio.actualizar(creada.getId(),
                peticion("Tarea", null, Prioridad.MEDIA, Estado.COMPLETADA, null));

        assertThat(actualizada.getEstado()).isEqualTo(Estado.COMPLETADA);
        assertThat(actualizada.getCompletadoEn()).isNotNull();
    }

    @Test
    void editarUnaTareaCompletadaConservaSuFechaDeFinalizacion() {
        Tarea creada = servicio.crear(peticion("Tarea", null, Prioridad.MEDIA, Estado.PENDIENTE, null));
        Tarea completada = servicio.actualizar(creada.getId(),
                peticion("Tarea", null, Prioridad.MEDIA, Estado.COMPLETADA, null));
        var completadoEn = completada.getCompletadoEn();

        Tarea editada = servicio.actualizar(creada.getId(),
                peticion("Tarea editada", null, Prioridad.ALTA, Estado.COMPLETADA, null));

        assertThat(editada.getCompletadoEn()).isEqualTo(completadoEn);
    }

    @Test
    void reabrirUnaTareaLimpiaSuFechaDeFinalizacion() {
        Tarea creada = servicio.crear(peticion("Tarea", null, Prioridad.MEDIA, Estado.PENDIENTE, null));
        servicio.actualizar(creada.getId(),
                peticion("Tarea", null, Prioridad.MEDIA, Estado.COMPLETADA, null));

        Tarea reabierta = servicio.actualizar(creada.getId(),
                peticion("Tarea", null, Prioridad.MEDIA, Estado.EN_PROCESO, null));

        assertThat(reabierta.getCompletadoEn()).isNull();
    }

    @Test
    void unaTareaAntiguaCompletadaNoRecibeUnaFechaInventada() {
        jdbc.update("""
                INSERT INTO tareas (titulo, prioridad, estado, creado_en, actualizado_en)
                VALUES (?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """, "Tarea anterior", "MEDIA", "COMPLETADA");
        Long id = jdbc.queryForObject(
                "SELECT id FROM tareas WHERE titulo = ?", Long.class, "Tarea anterior");

        Tarea antigua = servicio.obtener(id);
        assertThat(antigua.getCompletadoEn()).isNull();

        Tarea editada = servicio.actualizar(id,
                peticion("Tarea anterior editada", null, Prioridad.MEDIA, Estado.COMPLETADA, null));

        assertThat(editada.getCompletadoEn()).isNull();
    }

    @Test
    void actualizarNoModificaLaFechaDeCreacion() {
        Tarea creada = servicio.crear(peticion("Tarea", null, Prioridad.MEDIA, null, null));
        var creadoEn = creada.getCreadoEn();

        Tarea actualizada = servicio.actualizar(creada.getId(),
                peticion("Tarea editada", null, Prioridad.MEDIA, null, null));

        assertThat(actualizada.getCreadoEn()).isEqualTo(creadoEn);
        assertThat(actualizada.getActualizadoEn()).isAfterOrEqualTo(creadoEn);
    }

    @Test
    void obtenerUnaTareaInexistenteLanzaExcepcion() {
        assertThatThrownBy(() -> servicio.obtener(999_999L))
                .isInstanceOf(TareaNoEncontradaException.class)
                .hasMessageContaining("999999");
    }

    @Test
    void eliminarBorraLaTarea() {
        Tarea creada = servicio.crear(peticion("Para borrar", null, Prioridad.BAJA, null, null));

        servicio.eliminar(creada.getId());

        assertThat(repositorio.findById(creada.getId())).isEmpty();
    }

    @Test
    void eliminarUnaTareaInexistenteLanzaExcepcion() {
        assertThatThrownBy(() -> servicio.eliminar(999_999L))
                .isInstanceOf(TareaNoEncontradaException.class);
    }

    @Test
    void listarAplicaLosFiltrosIndicados() {
        servicio.crear(peticion("Pendiente alta", null, Prioridad.ALTA, Estado.PENDIENTE, null));
        servicio.crear(peticion("Pendiente baja", null, Prioridad.BAJA, Estado.PENDIENTE, null));
        servicio.crear(peticion("Completada alta", null, Prioridad.ALTA, Estado.COMPLETADA, null));

        assertThat(servicio.listar(null, null)).hasSize(3);
        assertThat(servicio.listar(Estado.PENDIENTE, null)).extracting(Tarea::getTitulo)
                .containsExactly("Pendiente alta", "Pendiente baja");
        assertThat(servicio.listar(null, Prioridad.ALTA)).extracting(Tarea::getTitulo)
                .containsExactly("Pendiente alta", "Completada alta");
        List<Tarea> combinado = servicio.listar(Estado.PENDIENTE, Prioridad.ALTA);
        assertThat(combinado).extracting(Tarea::getTitulo).containsExactly("Pendiente alta");
    }

    private static TareaRequest peticion(String titulo, String descripcion, Prioridad prioridad,
                                         Estado estado, LocalDate fechaLimite) {
        return new TareaRequest(titulo, descripcion, prioridad, estado, fechaLimite);
    }
}
