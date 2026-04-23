-- =============================================================
-- 05. ROW-LEVEL SECURITY (RLS)
-- =============================================================

ALTER TABLE mascotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE vacunas_aplicadas ENABLE ROW LEVEL SECURITY;
ALTER TABLE citas ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------
-- POLÍTICAS PARA ADMINISTRADORES Y RECEPCIÓN 
-- -------------------------------------------------------------
CREATE POLICY admin_recepcion_ve_todo_mascotas ON mascotas 
    FOR ALL TO rol_admin, rol_recepcion USING (true);

CREATE POLICY admin_ve_todo_vacunas ON vacunas_aplicadas 
    FOR ALL TO rol_admin USING (true);

CREATE POLICY admin_recepcion_ve_todo_citas ON citas 
    FOR ALL TO rol_admin, rol_recepcion USING (true);

-- -------------------------------------------------------------
-- POLÍTICAS PARA VETERINARIOS
-- -------------------------------------------------------------

-- 1. Mascotas: El veterinario solo ve las mascotas que atiende en vet_atiende_mascota 
CREATE POLICY vet_ve_sus_mascotas ON mascotas
    FOR SELECT TO rol_veterinario
    USING (id IN (
        SELECT mascota_id FROM vet_atiende_mascota 
        WHERE vet_id = current_setting('app.current_vet_id', true)::int
    ));

-- 2. Citas: El veterinario solo ve citas asignadas a él 
CREATE POLICY vet_ve_sus_citas ON citas
    FOR ALL TO rol_veterinario
    USING (veterinario_id = current_setting('app.current_vet_id', true)::int);

-- 3. Vacunas: El veterinario solo ve vacunas de las mascotas que él atiende 
CREATE POLICY vet_ve_sus_vacunas ON vacunas_aplicadas
    FOR ALL TO rol_veterinario
    USING (mascota_id IN (
        SELECT mascota_id FROM vet_atiende_mascota 
        WHERE vet_id = current_setting('app.current_vet_id', true)::int
    ));