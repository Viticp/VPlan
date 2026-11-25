-- VPlan - Creacion de la base de datos y del usuario de la aplicacion
--
-- EJECUTAR UNA SOLA VEZ como administrador de MySQL (root).
-- Antes de ejecutar, sustituye CAMBIA_ESTA_CONTRASENA por una contrasena
-- larga y distinta de la de root. Guardala en un gestor de contrasenas.
-- Usa al menos 12 caracteres con mayusculas, minusculas, numeros y simbolos:
-- algunos equipos tienen activada la politica de contrasenas de MySQL.
--
-- Este script NO se ejecuta desde la aplicacion ni desde los tests.
-- Se ejecuta manualmente desde MySQL Workbench o desde la consola mysql.

CREATE DATABASE IF NOT EXISTS vplan
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

CREATE USER IF NOT EXISTS 'vplan_app'@'localhost'
    IDENTIFIED BY 'CAMBIA_ESTA_CONTRASENA';

-- Si el usuario ya existia, actualiza la contrasena.
ALTER USER 'vplan_app'@'localhost'
    IDENTIFIED BY 'CAMBIA_ESTA_CONTRASENA';

-- Privilegios minimos: solo sobre el esquema vplan.
-- CREATE/ALTER/DROP/INDEX/REFERENCES son necesarios para que Flyway cree y
-- evolucione las tablas. No se concede ningun privilegio global.
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, INDEX, REFERENCES
    ON vplan.* TO 'vplan_app'@'localhost';

FLUSH PRIVILEGES;

-- Comprobacion rapida (opcional):
SHOW GRANTS FOR 'vplan_app'@'localhost';
