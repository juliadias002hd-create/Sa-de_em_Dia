const express = require('express');

const autenticar = require('../middleware/auth_middleware');

const {
    registrar,
    listar,
    desfazer
} = require('../controllers/dose_controller');

const router = express.Router();


// Todas as rotas precisam de autenticação

router.use(autenticar);


// POST /api/doses          (marca uma dose como tomada)
router.post('/', registrar);

// GET /api/doses?inicio=AAAA-MM-DD&fim=AAAA-MM-DD
router.get('/', listar);

// DELETE /api/doses/:id    (desfaz o registro)
router.delete('/:id', desfazer);


module.exports = router;
