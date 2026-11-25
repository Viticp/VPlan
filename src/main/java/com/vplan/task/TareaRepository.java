package com.vplan.task;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

/**
 * Acceso a datos de {@link Tarea}.
 *
 * <p>Los filtros se resuelven con consultas derivadas (el nombre del metodo
 * describe la consulta) en lugar de una unica consulta con parametros
 * opcionales. Hay cuatro combinaciones posibles y el servicio elige una; asi el
 * SQL que se ejecuta es siempre el mismo y con el indice adecuado.</p>
 *
 * <p>Todas las listas se ordenan por {@code id} ascendente para que el
 * resultado sea predecible y los tests no dependan del orden que devuelva el
 * motor.</p>
 */
public interface TareaRepository extends JpaRepository<Tarea, Long> {

    List<Tarea> findAllByOrderByIdAsc();

    List<Tarea> findByEstadoOrderByIdAsc(Estado estado);

    List<Tarea> findByPrioridadOrderByIdAsc(Prioridad prioridad);

    List<Tarea> findByEstadoAndPrioridadOrderByIdAsc(Estado estado, Prioridad prioridad);
}
