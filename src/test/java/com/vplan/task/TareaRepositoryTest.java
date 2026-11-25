package com.vplan.task;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Pruebas del repositorio contra H2 en memoria (mismo esquema que MySQL,
 * migrado por Flyway). Cada test se ejecuta en una transaccion que se revierte
 * al terminar, asi que no dejan datos.
 */
@SpringBootTest
@ActiveProfiles("test")
@Transactional
class TareaRepositoryTest {

    @Autowired
    private TareaRepository repositorio;

    @Test
    void guardaYRecuperaUnaTarea() {
        Tarea guardada = repositorio.save(new Tarea(
                "Preparar practica", "Entrega del modulo", Prioridad.ALTA, Estado.PENDIENTE,
                LocalDate.of(2026, 12, 31)));

        assertThat(guardada.getId()).isNotNull();
        assertThat(guardada.getCreadoEn()).isNotNull();
        assertThat(guardada.getActualizadoEn()).isNotNull();

        Tarea recuperada = repositorio.findById(guardada.getId()).orElseThrow();
        assertThat(recuperada.getTitulo()).isEqualTo("Preparar practica");
        assertThat(recuperada.getDescripcion()).isEqualTo("Entrega del modulo");
        assertThat(recuperada.getPrioridad()).isEqualTo(Prioridad.ALTA);
        assertThat(recuperada.getEstado()).isEqualTo(Estado.PENDIENTE);
        assertThat(recuperada.getFechaLimite()).isEqualTo(LocalDate.of(2026, 12, 31));
        assertThat(recuperada.getCompletadoEn()).isNull();
    }

    @Test
    void guardaLaFechaDeFinalizacionDeUnaTareaCompletada() {
        Tarea guardada = repositorio.save(new Tarea(
                "Terminada", null, Prioridad.MEDIA, Estado.COMPLETADA, null));

        Tarea recuperada = repositorio.findById(guardada.getId()).orElseThrow();

        assertThat(recuperada.getCompletadoEn()).isNotNull();
    }

    @Test
    void filtraPorEstado() {
        repositorio.save(tarea("A", Prioridad.BAJA, Estado.PENDIENTE));
        repositorio.save(tarea("B", Prioridad.MEDIA, Estado.EN_PROCESO));
        repositorio.save(tarea("C", Prioridad.ALTA, Estado.PENDIENTE));

        List<Tarea> pendientes = repositorio.findByEstadoOrderByIdAsc(Estado.PENDIENTE);

        assertThat(pendientes).extracting(Tarea::getTitulo).containsExactly("A", "C");
    }

    @Test
    void filtraPorPrioridad() {
        repositorio.save(tarea("A", Prioridad.BAJA, Estado.PENDIENTE));
        repositorio.save(tarea("B", Prioridad.ALTA, Estado.EN_PROCESO));
        repositorio.save(tarea("C", Prioridad.ALTA, Estado.COMPLETADA));

        List<Tarea> altas = repositorio.findByPrioridadOrderByIdAsc(Prioridad.ALTA);

        assertThat(altas).extracting(Tarea::getTitulo).containsExactly("B", "C");
    }

    @Test
    void filtraPorEstadoYPrioridadALaVez() {
        repositorio.save(tarea("A", Prioridad.ALTA, Estado.PENDIENTE));
        repositorio.save(tarea("B", Prioridad.BAJA, Estado.PENDIENTE));
        repositorio.save(tarea("C", Prioridad.ALTA, Estado.COMPLETADA));

        List<Tarea> resultado = repositorio.findByEstadoAndPrioridadOrderByIdAsc(Estado.PENDIENTE, Prioridad.ALTA);

        assertThat(resultado).extracting(Tarea::getTitulo).containsExactly("A");
    }

    @Test
    void listaTodasOrdenadasPorId() {
        repositorio.save(tarea("Primera", Prioridad.BAJA, Estado.PENDIENTE));
        repositorio.save(tarea("Segunda", Prioridad.MEDIA, Estado.PENDIENTE));
        repositorio.save(tarea("Tercera", Prioridad.ALTA, Estado.PENDIENTE));

        List<Tarea> todas = repositorio.findAllByOrderByIdAsc();

        assertThat(todas).extracting(Tarea::getTitulo).containsExactly("Primera", "Segunda", "Tercera");
    }

    private static Tarea tarea(String titulo, Prioridad prioridad, Estado estado) {
        return new Tarea(titulo, null, prioridad, estado, null);
    }
}
