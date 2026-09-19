const express = require('express');

const autenticar = require('../middleware/auth_middleware');

const {
    cadastrar,
    login,
    me,
    atualizarPerfil,
    trocarSenha
} = require('../controllers/auth_controller');

const router = express.Router();


// ---------- Rotas públicas ----------

// POST /api/auth/register
router.post('/register', cadastrar);

// POST /api/auth/login
router.post('/login', login);


// ---------- Rotas privadas (exigem token) ----------

// GET /api/auth/me
router.get('/me', autenticar, me);

// PUT /api/auth/profile
router.put('/profile', autenticar, atualizarPerfil);

// PUT /api/auth/change-password
router.put('/change-password', autenticar, trocarSenha);


module.exports = router;
