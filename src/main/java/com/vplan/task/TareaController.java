package com.vplan.task;

import com.vplan.task.dto.TareaRequest;
import com.vplan.task.dto.TareaResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;
import java.util.List;

/**
 * API REST de tareas.
 *
 * <pre>
 * GET    /api/tareas                 lista (filtros opcionales ?estado= &amp;prioridad=)
 * GET    /api/tareas/{id}            detalle
 * POST   /api/tareas                 crea (201 + Location)
 * PUT    /api/tareas/{id}            actualiza
 * DELETE /api/tareas/{id}            elimina (204)
 * </pre>
 *
 * <p>El controlador solo traduce HTTP a llamadas al servicio y entidades a
 * DTOs. No contiene reglas de negocio ni SQL.</p>
 */
@RestController
@RequestMapping("/api/tareas")
public class TareaController {

    private final TareaService servicio;

    public TareaController(TareaService servicio) {
        this.servicio = servicio;
    }

    @GetMapping
    public List<TareaResponse> listar(
            @RequestParam(required = false) Estado estado,
            @RequestParam(required = false) Prioridad prioridad) {

        return servicio.listar(estado, prioridad).stream()
                .map(TareaResponse::desde)
                .toList();
    }

    @GetMapping("/{id}")
    public TareaResponse obtener(@PathVariable Long id) {
        return TareaResponse.desde(servicio.obtener(id));
    }

    @PostMapping
    public ResponseEntity<TareaResponse> crear(@Valid @RequestBody TareaRequest peticion) {
        Tarea creada = servicio.crear(peticion);
        return ResponseEntity
                .created(URI.create("/api/tareas/" + creada.getId()))
                .body(TareaResponse.desde(creada));
    }

    @PutMapping("/{id}")
    public TareaResponse actualizar(@PathVariable Long id, @Valid @RequestBody TareaRequest peticion) {
        return TareaResponse.desde(servicio.actualizar(id, peticion));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void eliminar(@PathVariable Long id) {
        servicio.eliminar(id);
    }
}
