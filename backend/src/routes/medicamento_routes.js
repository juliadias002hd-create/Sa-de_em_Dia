const express = require('express');

const autenticar = require('../middleware/auth_middleware');

const {
    cadastrar,
    listar,
    buscarPorId,
    atualizar,
    excluir
} = require('../controllers/medicamento_controller');

const router = express.Router();


// Todas as rotas precisam de autenticação

router.use(autenticar);


// POST /api/medicamentos
router.post('/', cadastrar);

// GET /api/medicamentos          (opcional: ?ativo=true ou ?ativo=false)
router.get('/', listar);

// GET /api/medicamentos/:id
router.get('/:id', buscarPorId);

// PUT /api/medicamentos/:id
router.put('/:id', atualizar);

// DELETE /api/medicamentos/:id
router.delete('/:id', excluir);


// A listagem dos medicamentos de uma receita fica em
// GET /api/receitas/:receitaId/medicamentos  (veja receita_routes.js)


module.exports = router;
