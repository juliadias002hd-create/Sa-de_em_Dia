const express = require('express');

const autenticar = require('../middleware/auth_middleware');

const {
    cadastrar,
    listar,
    listarPorReceita
} = require('../controllers/medicamento_controller');

const router = express.Router();


// Todas as rotas precisam de autenticação

router.use(autenticar);


// POST /api/medicamentos

router.post('/', cadastrar);


// GET /api/medicamentos

router.get('/', listar);


// GET /api/medicamentos/receita/:receitaId

router.get(
    '/receita/:receitaId',
    listarPorReceita
);


module.exports = router;