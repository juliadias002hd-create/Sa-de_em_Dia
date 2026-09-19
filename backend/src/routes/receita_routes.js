const express = require('express');

const autenticar = require('../middleware/auth_middleware');
const receberArquivo = require('../middleware/upload_middleware');

const {
    cadastrar,
    listar,
    buscarPorId,
    atualizar,
    excluir,
    baixarArquivo
} = require('../controllers/receita_controller');

const router = express.Router();


// Todas as rotas abaixo precisam de login

router.use(autenticar);


// POST /api/receitas
// (JSON ou multipart/form-data com o arquivo no campo "arquivo")
router.post('/', receberArquivo, cadastrar);

// GET /api/receitas
router.get('/', listar);

// GET /api/receitas/:id/arquivo
router.get('/:id/arquivo', baixarArquivo);

// GET /api/receitas/:id
router.get('/:id', buscarPorId);

// PUT /api/receitas/:id
router.put('/:id', receberArquivo, atualizar);

// DELETE /api/receitas/:id
router.delete('/:id', excluir);


module.exports = router;
