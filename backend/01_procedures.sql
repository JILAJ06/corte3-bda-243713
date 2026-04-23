-- =============================================================
-- 01. PROCEDURES Y FUNCIONES (Corte 2 Reciclado y Mejorado)
-- =============================================================

CREATE OR REPLACE PROCEDURE sp_agendar_cita(
    p_mascota_id INT,
    p_veterinario_id INT,
    p_fecha_hora TIMESTAMP,
    p_motivo TEXT,
    OUT p_cita_id INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_mascota_existe INT;
    v_vet_activo BOOLEAN;
    v_dias_descanso VARCHAR;
    v_num_dia INT;
    v_dia_cita VARCHAR;
    v_colision INT;
    v_dias_semana CONSTANT text[] := ARRAY['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];
BEGIN
    IF trim(p_motivo) = '' OR p_motivo IS NULL THEN
        RAISE EXCEPTION 'El motivo de la cita no puede estar vacío.';
    END IF;

    SELECT id INTO v_mascota_existe FROM mascotas WHERE id = p_mascota_id;
    IF v_mascota_existe IS NULL THEN
        RAISE EXCEPTION 'La mascota con ID % no existe.', p_mascota_id;
    END IF;
    SELECT activo, dias_descanso INTO v_vet_activo, v_dias_descanso 
    FROM veterinarios WHERE id = p_veterinario_id;
    
    IF v_vet_activo IS NOT TRUE THEN
        RAISE EXCEPTION 'El veterinario no existe o se encuentra inactivo.';
    END IF;

    v_num_dia := EXTRACT(ISODOW FROM p_fecha_hora); 
    v_dia_cita := v_dias_semana[v_num_dia];       
    
    IF position(v_dia_cita in lower(v_dias_descanso)) > 0 THEN
        RAISE EXCEPTION 'El veterinario descansa los días: %', v_dias_descanso;
    END IF;

    SELECT id INTO v_colision 
    FROM citas 
    WHERE veterinario_id = p_veterinario_id 
      AND fecha_hora = p_fecha_hora 
      AND estado != 'CANCELADA'
    FOR UPDATE;

    IF v_colision IS NOT NULL THEN
        RAISE EXCEPTION 'Horario ocupado: El veterinario ya tiene una cita a esa hora.';
    END IF;

    INSERT INTO citas (mascota_id, veterinario_id, fecha_hora, motivo, estado)
    VALUES (p_mascota_id, p_veterinario_id, p_fecha_hora, p_motivo, 'AGENDADA')
    RETURNING id INTO p_cita_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_total_facturado(
    p_mascota_id INT,
    p_anio INT
) RETURNS NUMERIC AS $$
DECLARE
    v_total_citas NUMERIC;
    v_total_vacunas NUMERIC;
BEGIN
    SELECT COALESCE(SUM(costo), 0) INTO v_total_citas
    FROM citas
    WHERE mascota_id = p_mascota_id AND estado = 'COMPLETADA' AND EXTRACT(YEAR FROM fecha_hora) = p_anio;

    SELECT COALESCE(SUM(costo_cobrado), 0) INTO v_total_vacunas
    FROM vacunas_aplicadas
    WHERE mascota_id = p_mascota_id AND EXTRACT(YEAR FROM fecha_aplicacion) = p_anio;

    RETURN v_total_citas + v_total_vacunas;
END;
$$ LANGUAGE plpgsql;