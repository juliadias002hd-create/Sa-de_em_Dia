const mysql = require('mysql2/promise');

const pool = mysql.createPool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,

    // Devolve DATE/DATETIME como texto ("2026-09-18") em vez de objeto Date.
    // Evita que o fuso horário mude o dia (ex.: 18/09 virar 17/09).
    dateStrings: true,

    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

module.exports = pool;
