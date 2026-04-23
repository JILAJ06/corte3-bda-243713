const express = require('express');
const { Pool } = require('pg');
const redis = require('redis');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// 1. Conexión a PostgreSQL
const pool = new Pool({
    user: 'postgres',
    host: '127.0.0.1',
    database: 'clinica_vet',
    password: 'postgres',
    port: 5433,
});

// 2. Conexión a Redis
const redisClient = redis.createClient({
    socket: {
        host: '127.0.0.1',
        port: 6379
    }
});

redisClient.on('error', (err) => console.log('Error en Redis Client', err));
redisClient.connect().then(() => console.log('Conectado a Redis chido')).catch(console.error);

// ============================================================================
// FUNCIÓN MÁGICA PARA EJECUTAR QUERIES CON RLS Y PREVENIR SQL INJECTION
// ============================================================================
// En lugar de hacer client.query directo, pasamos por aquí para establecer el rol.
async function runQuery(rol, vetId, queryText, params = []) {
    const client = await pool.connect();
    try {
        await client.query('BEGIN'); // Iniciamos transacción

        // Cambiamos el rol dinámicamente según quién inició sesión en el frontend
        if (rol === 'admin') {
            await client.query('SET ROLE rol_admin');
        } else if (rol === 'recepcion') {
            await client.query('SET ROLE rol_recepcion');
        } else if (rol === 'veterinario') {
            await client.query('SET ROLE rol_veterinario');
            
            // Aquí le pasamos el ID del vet a Postgres para que el RLS sepa quién es.
            // Usamos set_config parametrizado para evitar inyecciones raras.
            await client.query('SELECT set_config($1, $2, true)', ['app.current_vet_id', vetId.toString()]);
        }

        // HARDENING: Ejecutamos la consulta pasándole el array de "params". 
        // Esto evita el SQL Injection clásico de "' OR '1'='1", porque la librería pg 
        // sanitiza los parámetros antes de meterlos a la BD.
        const result = await client.query(queryText, params);
        
        await client.query('COMMIT');
        return result.rows;
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
}

// ============================================================================
// ENDPOINTS DE LA API (Las pantallas que pidió el profe)
// ============================================================================

// A) Pantalla de Búsqueda de Mascotas (Superficie de ataque SQLi)
app.get('/api/mascotas/buscar', async (req, res) => {
    const { nombre, rol, vetId } = req.query;

    // Fíjate cómo usamos $1 en lugar de concatenar texto. Ahí está nuestra defensa.
    const query = `SELECT * FROM mascotas WHERE nombre ILIKE $1`;
    const parametros = [`%${nombre}%`];

    try {
        const rows = await runQuery(rol, vetId, query, parametros);
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// B) Pantalla de Vacunación Pendiente (Aquí evaluamos REDIS)
app.get('/api/vacunacion-pendiente', async (req, res) => {
    const { rol, vetId } = req.query;
    
    // Armamos una llave única para el caché. Si es vet 1, su caché es diferente al del vet 2.
    const cacheKey = `vacunas_pendientes_${rol}_${vetId || 'todos'}`;

    try {
        // 1. Buscamos primero en Redis
        const cachedData = await redisClient.get(cacheKey);

        if (cachedData) {
            // Requisito del profe: Mostrar el Hit en consola
            console.log(`[CACHE HIT] vacunacion_pendiente - Llave: ${cacheKey}`);
            return res.json(JSON.parse(cachedData));
        }

        // 2. Si no está en Redis, vamos a PostgreSQL
        console.log(`[CACHE MISS] Consultando a PostgreSQL para la llave: ${cacheKey}`);
        const rows = await runQuery(rol, vetId, 'SELECT * FROM v_mascotas_vacunacion_pendiente');

        // 3. Lo guardamos en Redis. Le puse un TTL de 300 segundos (5 minutos)
        // porque es un tiempo razonable para datos médicos que no cambian cada segundo.
        await redisClient.setEx(cacheKey, 300, JSON.stringify(rows));
        
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// C) Aplicar Vacuna (Para invalidar el caché)
app.post('/api/vacunas/aplicar', async (req, res) => {
    // El frontend nos manda los datos en el body
    const { mascotaId, vacunaId, rol, vetId } = req.body;

    try {
        const query = `
            INSERT INTO vacunas_aplicadas (mascota_id, vacuna_id, veterinario_id, fecha_aplicacion) 
            VALUES ($1, $2, $3, CURRENT_DATE) RETURNING *
        `;
        const parametros = [mascotaId, vacunaId, vetId];
        
        const rows = await runQuery(rol, vetId, query, parametros);

        // INVALIDACIÓN DE CACHÉ: Como acabamos de aplicar una vacuna, la lista de 
        // pendientes ya no sirve. Borramos todas las llaves que empiecen con vacunas_pendientes
        const keys = await redisClient.keys('vacunas_pendientes_*');
        for (let key of keys) {
            await redisClient.del(key);
        }
        console.log('[CACHE INVALIDADO] Se aplicó una vacuna, caché borrado.');

        res.json(rows[0]);
    } catch (err) {
        // Si el usuario "recepcion" intenta hacer esto, va a caer aquí por falta de permisos (GRANT)
        res.status(403).json({ error: 'Fallo al aplicar vacuna: ' + err.message });
    }
});

// Levantamos el servidor en el puerto 3001
app.listen(3001, () => {
    console.log('API corriendo en http://localhost:3001');
});