package com.vplan.task;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;

/**
 * Tarea persistente. Se mapea contra la tabla {@code tareas} que ya existe en
 * MySQL (creada por la migracion {@code V1} y adaptada por {@code V2}).
 *
 * <p>No se usa {@code @CreationTimestamp} ni {@code @UpdateTimestamp} de
 * Hibernate: las fechas se asignan a mano en {@link #alCrear()} y
 * {@link #alActualizar()} para que el comportamiento sea visible al leer el
 * codigo. La base de datos tiene {@code DEFAULT CURRENT_TIMESTAMP}, pero no se
 * depende de el: si la aplicacion inserta una fila, envia la fecha.</p>
 *
 * <p>Las marcas de creación y actualización se calculan en UTC y se recortan a
 * segundos; {@code completadoEn} es un {@link Instant} absoluto. La conexión
 * fija la sesión de MySQL en UTC ({@code connectionTimeZone}) y Hibernate usa
 * {@code hibernate.jdbc.time_zone: UTC}.</p>
 */
@Entity
@Table(name = "tareas")
public class Tarea {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 120)
    private String titulo;

    @Column(length = 2000)
    private String descripcion;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Prioridad prioridad;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Estado estado;

    @Column(name = "fecha_limite")
    private LocalDate fechaLimite;

    /**
     * Momento real en el que la tarea paso a COMPLETADA. Es nullable porque las
     * tareas completadas antes de la migracion V3 no tienen una fecha fiable y
     * no se rellena con datos inventados.
     *
     * <p>Se guarda como {@link Instant} para que el instante sea absoluto y no
     * dependa de la zona horaria de la maquina que lee la fila. Con
     * {@code LocalDateTime} el driver aplicaba la zona de la JVM y el instante
     * almacenado se desplazaba una hora.</p>
     */
    @Column(name = "completado_en")
    private Instant completadoEn;

    @Column(name = "creado_en", nullable = false, updatable = false)
    private LocalDateTime creadoEn;

    @Column(name = "actualizado_en", nullable = false)
    private LocalDateTime actualizadoEn;

    protected Tarea() {
        // Requerido por JPA.
    }

    public Tarea(String titulo, String descripcion, Prioridad prioridad, Estado estado, LocalDate fechaLimite) {
        this.titulo = titulo;
        this.descripcion = descripcion;
        this.prioridad = prioridad;
        this.estado = estado;
        this.fechaLimite = fechaLimite;
    }

    @PrePersist
    void alCrear() {
        LocalDateTime ahora = ahora();
        this.creadoEn = ahora;
        this.actualizadoEn = ahora;
        if (this.estado == null) {
            this.estado = Estado.PENDIENTE;
        }
        if (this.estado == Estado.COMPLETADA && this.completadoEn == null) {
            this.completadoEn = ahoraInstante();
        }
    }

    @PreUpdate
    void alActualizar() {
        this.actualizadoEn = ahora();
    }

    /**
     * Las columnas {@code TIMESTAMP} de MySQL guardan segundos, sin fracciones.
     * Se recorta a segundos para que lo que devuelve la API coincida exactamente
     * con lo que se lee despues de la base de datos.
     */
    private static LocalDateTime ahora() {
        return LocalDateTime.now(ZoneOffset.UTC).truncatedTo(ChronoUnit.SECONDS);
    }

    private static Instant ahoraInstante() {
        return Instant.now().truncatedTo(ChronoUnit.SECONDS);
    }

    public Long getId() {
        return id;
    }

    public String getTitulo() {
        return titulo;
    }

    public void setTitulo(String titulo) {
        this.titulo = titulo;
    }

    public String getDescripcion() {
        return descripcion;
    }

    public void setDescripcion(String descripcion) {
        this.descripcion = descripcion;
    }

    public Prioridad getPrioridad() {
        return prioridad;
    }

    public void setPrioridad(Prioridad prioridad) {
        this.prioridad = prioridad;
    }

    public Estado getEstado() {
        return estado;
    }

    /**
     * Cambia el estado manteniendo coherente la fecha de finalizacion:
     * se marca al entrar en COMPLETADA, se conserva si ya lo estaba (aunque
     * sea una tarea antigua sin fecha) y se limpia al reabrirla.
     */
    public void setEstado(Estado estado) {
        Estado anterior = this.estado;
        this.estado = estado;

        if (estado == Estado.COMPLETADA && anterior != Estado.COMPLETADA) {
            if (this.completadoEn == null) {
                this.completadoEn = ahoraInstante();
            }
        } else if (estado != Estado.COMPLETADA) {
            this.completadoEn = null;
        }
    }

    public LocalDate getFechaLimite() {
        return fechaLimite;
    }

    public void setFechaLimite(LocalDate fechaLimite) {
        this.fechaLimite = fechaLimite;
    }

    public Instant getCompletadoEn() {
        return completadoEn;
    }

    public LocalDateTime getCreadoEn() {
        return creadoEn;
    }

    public LocalDateTime getActualizadoEn() {
        return actualizadoEn;
    }
}
