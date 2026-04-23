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
async function runQuery(rol, vetId, queryText, params = []) {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        if (rol === 'admin') {
            await client.query('SET ROLE rol_admin');
        } else if (rol === 'recepcion') {
            await client.query('SET ROLE rol_recepcion');
        } else if (rol === 'veterinario') {
            await client.query('SET ROLE rol_veterinario');
            await client.query('SELECT set_config($1, $2, true)', ['app.current_vet_id', vetId.toString()]);
        }
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

app.get('/api/mascotas/buscar', async (req, res) => {
    const { nombre, rol, vetId } = req.query;

    const query = `SELECT * FROM mascotas WHERE nombre ILIKE $1`;
    const parametros = [`%${nombre}%`];

    try {
        const rows = await runQuery(rol, vetId, query, parametros);
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/vacunacion-pendiente', async (req, res) => {
    const { rol, vetId } = req.query;
    
    const cacheKey = `vacunas_pendientes_${rol}_${vetId || 'todos'}`;

    try {
        const cachedData = await redisClient.get(cacheKey);

        if (cachedData) {
            console.log(`[CACHE HIT] vacunacion_pendiente - Llave: ${cacheKey}`);
            return res.json(JSON.parse(cachedData));
        }
        console.log(`[CACHE MISS] Consultando a PostgreSQL para la llave: ${cacheKey}`);
        const rows = await runQuery(rol, vetId, 'SELECT * FROM v_mascotas_vacunacion_pendiente');

        await redisClient.setEx(cacheKey, 300, JSON.stringify(rows));
        
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/vacunas/aplicar', async (req, res) => {
    const { mascotaId, vacunaId, rol, vetId } = req.body;

    try {
        const query = `
            INSERT INTO vacunas_aplicadas (mascota_id, vacuna_id, veterinario_id, fecha_aplicacion) 
            VALUES ($1, $2, $3, CURRENT_DATE) RETURNING *
        `;
        const parametros = [mascotaId, vacunaId, vetId];
        
        const rows = await runQuery(rol, vetId, query, parametros);

        const keys = await redisClient.keys('vacunas_pendientes_*');
        for (let key of keys) {
            await redisClient.del(key);
        }
        console.log('[CACHE INVALIDADO] Se aplicó una vacuna, caché borrado.');

        res.json(rows[0]);
    } catch (err) {
        res.status(403).json({ error: 'Fallo al aplicar vacuna: ' + err.message });
    }
});
app.listen(3001, () => {
    console.log('API corriendo en http://localhost:3001');
});