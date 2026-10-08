const mysql = require('mysql2/promise');

// O app inteiro (datas, lembretes, "criado em") assume que o horário que o
// banco devolve já é o horário local do paciente — sem nenhuma conversão de
// fuso em lugar nenhum. Isso funciona sozinho quando o MySQL roda na mesma
// máquina/fuso de quem usa o app, mas bancos na nuvem (Clever Cloud, etc.)
// costumam rodar em UTC. Por isso, toda conexão do pool força o fuso do
// Brasil logo ao conectar — sem isso, os horários dos lembretes saem errados
// por -03:00 (o Brasil não tem mais horário de verão desde 2019, então um
// deslocamento fixo é suficiente, sem precisar das tabelas de fuso do MySQL).
const FUSO = process.env.DB_TIMEZONE || '-03:00';

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
    // Bancos gratuitos (ex.: Clever Cloud "Dev") limitam quantas conexões
    // simultâneas aceitam — por isso isto é configurável pelo .env em vez
    // de um número fixo. Sem DB_CONNECTION_LIMIT, usa 10 (bom para MySQL
    // local, sem esse tipo de limite).
    connectionLimit: Number(process.env.DB_CONNECTION_LIMIT) || 10,
    queueLimit: 0
});

// A opção "timezone" do mysql2 só afeta como o driver LÊ datas no cliente;
// não muda o que NOW()/CURRENT_TIMESTAMP calculam no servidor. Por isso o
// fuso é setado de verdade com SET time_zone, em toda conexão nova do pool.
pool.on('connection', (conexao) => {
    conexao.query(`SET time_zone = '${FUSO}'`);
});

module.exports = pool;
