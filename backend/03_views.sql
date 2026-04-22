-- =============================================================
-- 03. VISTAS
-- =============================================================

CREATE OR REPLACE VIEW v_mascotas_vacunacion_pendiente AS
WITH ultima_vacuna AS (
    SELECT mascota_id, MAX(fecha_aplicacion) as fecha_ultima_vacuna
    FROM vacunas_aplicadas
    GROUP BY mascota_id
)
SELECT 
    m.nombre AS nombre,
    m.especie,
    d.nombre AS nombre_dueno,
    d.telefono AS telefono_dueno,
    uv.fecha_ultima_vacuna,
    (CURRENT_DATE - uv.fecha_ultima_vacuna) AS dias_desde_ultima_vacuna,
    CASE 
        WHEN uv.fecha_ultima_vacuna IS NULL THEN 'NUNCA_VACUNADA'
        ELSE 'VENCIDA'
    END AS prioridad
FROM mascotas m
JOIN duenos d ON m.dueno_id = d.id
LEFT JOIN ultima_vacuna uv ON m.id = uv.mascota_id
WHERE uv.fecha_ultima_vacuna IS NULL 
   OR (CURRENT_DATE - uv.fecha_ultima_vacuna) > 365;