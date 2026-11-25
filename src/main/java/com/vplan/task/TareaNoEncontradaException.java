package com.vplan.task;

/**
 * Se lanza cuando se pide una tarea que no existe. El manejador global la
 * traduce a un {@code 404 Not Found}.
 */
public class TareaNoEncontradaException extends RuntimeException {

    private final Long id;

    public TareaNoEncontradaException(Long id) {
        super("No existe ninguna tarea con id " + id);
        this.id = id;
    }

    public Long getId() {
        return id;
    }
}
