require('dotenv').config({ quiet: true });

// ========================================
// CONFERE O .env ANTES DE INICIAR
// ========================================
// DB_PASSWORD pode ficar vazio (XAMPP sem senha), então não entra aqui.

const obrigatorias = ['DB_HOST', 'DB_PORT', 'DB_USER', 'DB_NAME', 'JWT_SECRET'];

const faltando = obrigatorias.filter((nome) => !process.env[nome]);

if (faltando.length > 0) {
    console.error(
        `Configuração incompleta no arquivo backend/.env. Faltando: ${faltando.join(', ')}`
    );
    process.exit(1);
}

if (process.env.JWT_SECRET.length < 16) {
    console.warn(
        'AVISO: JWT_SECRET é curto. Use uma chave longa e aleatória (32+ caracteres).'
    );
}


const express = require('express');
const cors = require('cors');

const pool = require('./database');
const { sucesso, erro } = require('./utils/resposta');

const authRoutes = require('./routes/auth_routes');
const receitaRoutes = require('./routes/receita_routes');
const medicamentoRoutes = require('./routes/medicamento_routes');
const doseRoutes = require('./routes/dose_routes');

const app = express();

app.use(cors());

app.use(express.json({ limit: '1mb' }));


// ========================================
// ROTA PRINCIPAL
// ========================================

app.get('/', (req, res) => {
    return sucesso(res, 200, 'API Saúde em Dia funcionando!');
});


// ========================================
// TESTE DE CONEXÃO COM MYSQL
// ========================================
// Só para desenvolvimento. Remover antes de publicar a API.

app.get('/api/teste-mysql', async (req, res) => {
    try {
        await pool.execute('SELECT 1 AS teste');

        return sucesso(res, 200, 'MySQL conectado com sucesso!');
    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível conectar ao MySQL.');
    }
});


// ========================================
// ROTAS
// ========================================

app.use('/api/auth', authRoutes);

app.use('/api/receitas', receitaRoutes);

app.use('/api/medicamentos', medicamentoRoutes);

app.use('/api/doses', doseRoutes);


// ========================================
// ROTA NÃO ENCONTRADA
// ========================================

app.use((req, res) => {
    return erro(res, 404, 'Rota não encontrada.');
});


// ========================================
// TRATAMENTO GERAL DE ERROS
// ========================================
// Pega o que escapar dos controllers (ex.: JSON malformado no corpo).
// Nunca devolve detalhes técnicos para quem chamou a API.

app.use((err, req, res, next) => {

    if (err.type === 'entity.parse.failed') {
        return erro(res, 400, 'O corpo da requisição não é um JSON válido.');
    }

    if (err.type === 'entity.too.large') {
        return erro(res, 413, 'Requisição grande demais.');
    }

    // Erros de upload de arquivo (multer)
    if (err.name === 'MulterError') {
        if (err.code === 'LIMIT_FILE_SIZE') {
            return erro(res, 413, 'O arquivo é grande demais. O limite é 10 MB.');
        }

        return erro(res, 400, 'Não foi possível receber o arquivo. Envie apenas um arquivo no campo "arquivo".');
    }

    console.error(err);

    return erro(res, 500, 'Ocorreu um erro inesperado. Tente novamente.');
});


// ========================================
// INICIAR SERVIDOR
// ========================================

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
    console.log(`API Saúde em Dia rodando na porta ${PORT}`);
});
