# Documento de Decisiones - Corte 3 BDA
**Sistema Full-Stack de Clínica Veterinaria**

---

**1. ¿Qué política RLS aplicaste a la tabla mascotas? Pega la cláusula exacta y explica con tus palabras qué hace.**

CREATE POLICY vet_ve_sus_mascotas ON mascotas FOR SELECT TO rol_veterinario USING (id IN (SELECT mascota_id FROM vet_atiende_mascota WHERE vet_id = current_setting('app.current_vet_id', true)::int));

Cuando un veterinario hace un SELECT, Postgres revisa la tabla pivote vet_atiende_mascota con su ID de sesión y solo muestra las mascotas que le están asignadas.

---

**2. Cualquiera que sea la estrategia que elegiste para identificar al veterinario actual en RLS, tiene un vector de ataque posible. ¿Cuál es? ¿Tu sistema lo previene? ¿Cómo?**

El ataque sería inyectar SET app.current_vet_id = X para suplantar a otro veterinario. Lo previene la API de Node.js, ya que el usuario nunca se conecta directo a la base de datos y el cambio de contexto se hace con parámetros preparados ($1), no con SQL crudo.

---

**3. Si usas SECURITY DEFINER en algún procedure, ¿qué medida específica tomaste para prevenir la escalada de privilegios que ese modo habilita? Si no lo usas, justifica por qué no era necesario.**

No usé SECURITY DEFINER. Los permisos se gestionan con GRANT/REVOKE por rol, así que los procedures corren con los privilegios de quien los llama (SECURITY INVOKER), que es más seguro para este caso.

---

**4. ¿Qué TTL le pusiste al caché Redis y por qué ese valor específico? ¿Qué pasaría si fuera demasiado bajo? ¿Demasiado alto?**

TTL de **300 segundos (5 min)**. Muy bajo (ej. 5s) haría inútil el caché porque se recalcularía constantemente en PostgreSQL. Muy alto (ej. 1 día) mostraría datos desactualizados, por ejemplo una mascota recién vacunada seguiría apareciendo como pendiente.

---

**5. Tu frontend manda input del usuario al backend. Elige un endpoint crítico y pega la línea exacta donde el backend maneja ese input antes de enviarlo a la base de datos. Explica qué protege esa línea y de qué. Indica archivo y número de línea.**

En api/index.js, el endpoint de búsqueda usa consultas parametrizadas:
```js
const query = 'SELECT * FROM mascotas WHERE nombre ILIKE $1';
const parametros = ['%' + nombre + '%'];
```
Esto previene inyección SQL: el texto del usuario va como parámetro $1, nunca como comando ejecutable.

---

**6. Si revocas todos los permisos del rol de veterinario excepto SELECT en mascotas, ¿qué deja de funcionar en tu sistema? Lista tres operaciones que se romperían.**

1. **Agendar citas** — sin INSERT en citas.
2. **Ver datos del dueño** — sin SELECT en duenos.
3. **Registrar vacunas** — sin INSERT en vacunas_aplicadas.