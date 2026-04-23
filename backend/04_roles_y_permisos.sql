-- =============================================================
-- 04. ROLES Y PERMISOS (Principio de mínimo privilegio)
-- =============================================================

-- 1. Crear los roles principales
DROP ROLE IF EXISTS rol_admin;
DROP ROLE IF EXISTS rol_recepcion;
DROP ROLE IF EXISTS rol_veterinario;

CREATE ROLE rol_admin LOGIN PASSWORD 'admin123';
CREATE ROLE rol_recepcion LOGIN PASSWORD 'recepcion123';
CREATE ROLE rol_veterinario LOGIN PASSWORD 'vet123';

-- 2. Permisos para Administrador (Ve y hace todo) 
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO rol_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rol_admin;

-- 3. Permisos para Recepción 
GRANT SELECT ON duenos, mascotas, veterinarios TO rol_recepcion;
GRANT SELECT, INSERT, UPDATE ON citas TO rol_recepcion;
GRANT USAGE, SELECT ON SEQUENCE citas_id_seq TO rol_recepcion;
GRANT SELECT ON v_mascotas_vacunacion_pendiente TO rol_recepcion; 

-- 4. Permisos para Veterinario
GRANT SELECT ON duenos, mascotas, veterinarios, vet_atiende_mascota TO rol_veterinario;
GRANT SELECT, INSERT, UPDATE ON citas, vacunas_aplicadas TO rol_veterinario;
GRANT USAGE, SELECT ON SEQUENCE citas_id_seq, vacunas_aplicadas_id_seq TO rol_veterinario;
GRANT SELECT ON inventario_vacunas TO rol_veterinario;
GRANT SELECT ON v_mascotas_vacunacion_pendiente TO rol_veterinario;