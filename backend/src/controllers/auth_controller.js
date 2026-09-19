const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const pool = require('../database');


// ========================================
// CADASTRAR USUÁRIO
// ========================================

async function cadastrar(req, res) {
    try {
        const {
            nome,
            email,
            senha,
            telefone,
            data_nascimento
        } = req.body;

        if (!nome || !email || !senha) {
            return res.status(400).json({
                erro: 'Preencha todos os campos obrigatórios.'
            });
        }

        const emailValido = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

        if (!emailValido) {
            return res.status(400).json({
                erro: 'Informe um e-mail válido.'
            });
        }

        if (senha.length < 6) {
            return res.status(400).json({
                erro: 'A senha deve ter no mínimo 6 caracteres.'
            });
        }

        const [usuarios] = await pool.query(
            `
            SELECT id
            FROM usuarios
            WHERE email = ?
            `,
            [email]
        );

        if (usuarios.length > 0) {
            return res.status(409).json({
                erro: 'Este e-mail já está cadastrado.'
            });
        }

        const senhaHash = await bcrypt.hash(senha, 10);

        const [resultado] = await pool.query(
            `
            INSERT INTO usuarios
            (
                nome,
                email,
                senha,
                telefone,
                data_nascimento,
                ativo
            )
            VALUES (?, ?, ?, ?, ?, 1)
            `,
            [
                nome,
                email,
                senhaHash,
                telefone || null,
                data_nascimento || null
            ]
        );

        res.status(201).json({
            mensagem: 'Usuário cadastrado com sucesso!',
            usuario: {
                id: resultado.insertId,
                nome,
                email,
                telefone: telefone || null,
                data_nascimento: data_nascimento || null,
                ativo: true
            }
        });

    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: 'Erro ao cadastrar usuário.'
        });
    }
}


// ========================================
// LOGIN
// ========================================

async function login(req, res) {
    try {
        const {
            email,
            senha
        } = req.body;

        if (!email || !senha) {
            return res.status(400).json({
                erro: 'Informe e-mail e senha.'
            });
        }

        const [usuarios] = await pool.query(
            `
            SELECT *
            FROM usuarios
            WHERE email = ?
            `,
            [email]
        );

        if (usuarios.length === 0) {
            return res.status(401).json({
                erro: 'E-mail ou senha inválidos.'
            });
        }

        const usuario = usuarios[0];

        // Verificar se o usuário está ativo

        if (!usuario.ativo) {
            return res.status(403).json({
                erro: 'Usuário inativo. Entre em contato com o suporte.'
            });
        }

        const senhaCorreta = await bcrypt.compare(
            senha,
            usuario.senha
        );

        if (!senhaCorreta) {
            return res.status(401).json({
                erro: 'E-mail ou senha inválidos.'
            });
        }

        const token = jwt.sign(
            {
                id: usuario.id,
                email: usuario.email
            },
            process.env.JWT_SECRET,
            {
                expiresIn: '7d'
            }
        );

        res.json({
            mensagem: 'Login realizado com sucesso!',

            token,

            usuario: {
                id: usuario.id,
                nome: usuario.nome,
                email: usuario.email,
                telefone: usuario.telefone,
                data_nascimento: usuario.data_nascimento,
                ativo: !!usuario.ativo
            }
        });

    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: 'Erro ao realizar login.'
        });
    }
}


module.exports = {
    cadastrar,
    login
};
