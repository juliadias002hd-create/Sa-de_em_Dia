const express = require('express');

const autenticar = require('../middleware/auth_middleware');

const {
    cadastrar,
    listar,
    buscarPorId
} = require('../controllers/receita_controller');

const router = express.Router();


// Todas as rotas abaixo precisam de login

router.use(autenticar);


// POST /api/receitas

router.post('/', cadastrar);


// GET /api/receitas

router.get('/', listar);


// GET /api/receitas/:id

router.get('/:id', buscarPorId);


module.exports = router;