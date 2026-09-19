require('dotenv').config();

const express = require('express');
const cors = require('cors');

const pool = require('./database');

const authRoutes = require('./routes/auth_routes');
const receitaRoutes = require('./routes/receita_routes');
const medicamentoRoutes = require('./routes/medicamento_routes');

const app = express();

app.use(cors());

app.use(express.json());


// ========================================
// ROTA PRINCIPAL
// ========================================

app.get('/', (req, res) => {
    res.json({
        mensagem: 'API Saúde em Dia funcionando!'
    });
});


// ========================================
// TESTE DE CONEXÃO COM MYSQL
// ========================================

app.get('/api/teste-mysql', async (req, res) => {
    try {
        const [resultado] = await pool.query('SELECT 1 AS teste');

        res.json({
            mensagem: 'MySQL conectado com sucesso!',
            resultado
        });
    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: 'Não foi possível conectar ao MySQL.'
        });
    }
});


// ========================================
// ROTAS
// ========================================

app.use('/api/auth', authRoutes);

app.use('/api/receitas', receitaRoutes);

app.use('/api/medicamentos', medicamentoRoutes);


// ========================================
// INICIAR SERVIDOR
// ========================================

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
    console.log(`API Saúde em Dia rodando na porta ${PORT}`);
});