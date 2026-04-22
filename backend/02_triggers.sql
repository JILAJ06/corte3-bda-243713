-- =============================================================
-- 02. TRIGGERS
-- =============================================================

CREATE OR REPLACE FUNCTION fn_registrar_historial_cita() RETURNS TRIGGER AS $$
DECLARE
    v_nombre_mascota VARCHAR;
    v_nombre_vet VARCHAR;
    v_fecha_txt VARCHAR;
    v_descripcion TEXT;
BEGIN
    SELECT nombre INTO v_nombre_mascota FROM mascotas WHERE id = NEW.mascota_id;
    SELECT nombre INTO v_nombre_vet FROM veterinarios WHERE id = NEW.veterinario_id;
    v_fecha_txt := to_char(NEW.fecha_hora, 'DD/MM/YYYY');
    
    v_descripcion := 'Cita para ' || v_nombre_mascota || ' con ' || v_nombre_vet || ' el ' || v_fecha_txt;

    INSERT INTO historial_movimientos (tipo, referencia_id, descripcion, fecha)
    VALUES ('CITA_AGENDADA', NEW.id, v_descripcion, NOW());

    RETURN NULL; 
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_historial_cita ON citas;
CREATE TRIGGER trg_historial_cita
AFTER INSERT ON citas
FOR EACH ROW
EXECUTE FUNCTION fn_registrar_historial_cita();