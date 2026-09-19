const express = require('express');

const {
    cadastrar,
    login
} = require('../controllers/auth_controller');

const router = express.Router();


// POST /api/auth/cadastro

router.post('/cadastro', cadastrar);


// POST /api/auth/login

router.post('/login', login);


module.exports = router;