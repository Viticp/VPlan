-- VPlan - Comprobaciones de solo lectura
-- Ejecutar como root. No modifica nada.

-- 1. La base de datos existe y usa utf8mb4
SELECT SCHEMA_NAME, DEFAULT_CHARACTER_SET_NAME, DEFAULT_COLLATION_NAME
FROM information_schema.SCHEMATA
WHERE SCHEMA_NAME = 'vplan';

-- 2. El usuario existe
SELECT user, host FROM mysql.user WHERE user = 'vplan_app';

-- 3. Privilegios concedidos (debe aparecer solo vplan.*)
SHOW GRANTS FOR 'vplan_app'@'localhost';

-- 4. Tablas creadas por Flyway (vacio antes del primer arranque)
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'vplan'
ORDER BY table_name;
