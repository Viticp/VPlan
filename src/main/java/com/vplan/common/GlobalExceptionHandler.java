package com.vplan.common;

import com.vplan.task.TareaNoEncontradaException;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Traduce excepciones a respuestas HTTP con el formato {@link ErrorResponse}.
 *
 * <p>Regla de seguridad: nunca se devuelve el mensaje de una excepcion interna
 * ni una traza. El detalle se registra en el log del servidor y el cliente recibe
 * un mensaje generico.</p>
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(TareaNoEncontradaException.class)
    public ResponseEntity<ErrorResponse> tareaNoEncontrada(TareaNoEncontradaException ex, HttpServletRequest peticion) {
        return respuesta(HttpStatus.NOT_FOUND, ex.getMessage(), peticion);
    }

    /**
     * Errores de Bean Validation (@NotBlank, @Size, @NotNull...).
     * Devuelve un mapa campo → mensaje para que el frontend pueda marcarlos.
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> validacion(MethodArgumentNotValidException ex, HttpServletRequest peticion) {
        Map<String, String> campos = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(error ->
                campos.putIfAbsent(error.getField(), error.getDefaultMessage()));

        ErrorResponse cuerpo = ErrorResponse.deValidacion(
                "La peticion no es valida", peticion.getRequestURI(), campos);

        return ResponseEntity.badRequest().body(cuerpo);
    }

    /**
     * JSON mal formado o valor imposible de convertir (por ejemplo un estado que
     * no existe). No se repite el mensaje de Jackson porque puede incluir rutas
     * de clases internas.
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> jsonInvalido(HttpMessageNotReadableException ex, HttpServletRequest peticion) {
        return respuesta(HttpStatus.BAD_REQUEST,
                "El cuerpo de la peticion no es un JSON valido o contiene un valor no permitido",
                peticion);
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ErrorResponse> parametroInvalido(MethodArgumentTypeMismatchException ex, HttpServletRequest peticion) {
        return respuesta(HttpStatus.BAD_REQUEST,
                "El parametro '" + ex.getName() + "' tiene un valor no permitido",
                peticion);
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ErrorResponse> metodoNoPermitido(HttpRequestMethodNotSupportedException ex, HttpServletRequest peticion) {
        return respuesta(HttpStatus.METHOD_NOT_ALLOWED,
                "El metodo HTTP " + ex.getMethod() + " no esta permitido en esta ruta",
                peticion);
    }

    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<ErrorResponse> tipoContenidoNoSoportado(HttpMediaTypeNotSupportedException ex, HttpServletRequest peticion) {
        return respuesta(HttpStatus.UNSUPPORTED_MEDIA_TYPE,
                "El Content-Type debe ser application/json",
                peticion);
    }

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ErrorResponse> recursoNoEncontrado(NoResourceFoundException ex, HttpServletRequest peticion) {
        return respuesta(HttpStatus.NOT_FOUND, "El recurso solicitado no existe", peticion);
    }

    /**
     * Red de seguridad: cualquier error no previsto devuelve 500 sin detalles.
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> errorInesperado(Exception ex, HttpServletRequest peticion) {
        log.error("Error no controlado en {}", peticion.getRequestURI(), ex);
        return respuesta(HttpStatus.INTERNAL_SERVER_ERROR,
                "Ha ocurrido un error interno. Intentalo de nuevo mas tarde.",
                peticion);
    }

    private static ResponseEntity<ErrorResponse> respuesta(HttpStatus estado, String mensaje, HttpServletRequest peticion) {
        return ResponseEntity
                .status(estado)
                .body(ErrorResponse.de(estado.value(), estado.getReasonPhrase(), mensaje, peticion.getRequestURI()));
    }
}
