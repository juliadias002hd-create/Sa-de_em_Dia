const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const pool = require('../database');
const { sucesso, erro } = require('../utils/resposta');
const {
    ehTexto,
    emailValido,
    telefoneValido,
    dataNascimentoValida,
    senhaValida,
    SENHA_MINIMA
} = require('../utils/validacoes');


// Hash de mentira usado no login quando o e-mail não existe.
// Assim o tempo de resposta é parecido com o de um e-mail existente
// e ninguém descobre, medindo o tempo, quais e-mails estão cadastrados.
const HASH_FALSO = bcrypt.hashSync('senha-falsa-para-igualar-tempo', 10);


// Converte a linha do banco no objeto que a API devolve.
// A senha (hash) NUNCA sai daqui.
function montarUsuario(linha) {
    return {
        id: linha.id,
        nome: linha.nome,
        email: linha.email,
        telefone: linha.telefone,
        data_nascimento: linha.data_nascimento,
        ativo: !!linha.ativo,
        criado_em: linha.criado_em
    };
}


// Valida os campos opcionais telefone e data_nascimento.
// Devolve a mensagem de erro, ou null se estiver tudo certo.
function validarContato(telefone, dataNascimento) {

    if (telefone && !telefoneValido(telefone)) {
        return 'Informe um telefone válido com DDD. Ex.: (11) 98888-7777.';
    }

    if (dataNascimento && !dataNascimentoValida(dataNascimento)) {
        return 'Informe uma data de nascimento válida no formato AAAA-MM-DD.';
    }

    return null;
}


// ========================================
// CADASTRAR USUÁRIO
// POST /api/auth/register
// ========================================

async function cadastrar(req, res) {
    try {
        const {
            nome,
            email,
            senha,
            confirmar_senha,
            telefone,
            data_nascimento
        } = req.body || {};

        if (!ehTexto(nome) || !nome.trim() || !ehTexto(email) || !email.trim() || !senha) {
            return erro(res, 400, 'Preencha todos os campos obrigatórios.');
        }

        const nomeLimpo = nome.trim();
        const emailLimpo = email.trim().toLowerCase();
        const telefoneLimpo = ehTexto(telefone) && telefone.trim() ? telefone.trim() : null;
        const nascimentoLimpo = ehTexto(data_nascimento) && data_nascimento.trim() ? data_nascimento.trim() : null;

        if (nomeLimpo.length < 2 || nomeLimpo.length > 150) {
            return erro(res, 400, 'Informe um nome válido.');
        }

        if (!emailValido(emailLimpo)) {
            return erro(res, 400, 'Informe um e-mail válido.');
        }

        if (!senhaValida(senha)) {
            return erro(
                res,
                400,
                `A senha deve ter entre ${SENHA_MINIMA} e 72 caracteres.`
            );
        }

        // A confirmação é opcional na API (o Flutter também confere),
        // mas se for enviada precisa ser igual.
        if (confirmar_senha !== undefined && confirmar_senha !== senha) {
            return erro(res, 400, 'A confirmação da senha não confere.');
        }

        const erroContato = validarContato(telefoneLimpo, nascimentoLimpo);

        if (erroContato) {
            return erro(res, 400, erroContato);
        }

        const [existentes] = await pool.execute(
            'SELECT id FROM usuarios WHERE email = ?',
            [emailLimpo]
        );

        if (existentes.length > 0) {
            return erro(res, 409, 'Este e-mail já está cadastrado.');
        }

        const senhaHash = await bcrypt.hash(senha, 10);

        const [resultado] = await pool.execute(
            `
            INSERT INTO usuarios
                (nome, email, senha, telefone, data_nascimento, ativo)
            VALUES (?, ?, ?, ?, ?, 1)
            `,
            [nomeLimpo, emailLimpo, senhaHash, telefoneLimpo, nascimentoLimpo]
        );

        const [linhas] = await pool.execute(
            'SELECT * FROM usuarios WHERE id = ?',
            [resultado.insertId]
        );

        return sucesso(res, 201, 'Usuário cadastrado com sucesso!', {
            usuario: montarUsuario(linhas[0])
        });

    } catch (e) {

        // Dois cadastros simultâneos com o mesmo e-mail:
        // o índice UNIQUE do banco barra o segundo.
        if (e.code === 'ER_DUP_ENTRY') {
            return erro(res, 409, 'Este e-mail já está cadastrado.');
        }

        console.error(e);

        return erro(res, 500, 'Não foi possível concluir o cadastro. Tente novamente.');
    }
}


// ========================================
// LOGIN
// POST /api/auth/login
// ========================================

async function login(req, res) {
    try {
        const { email, senha } = req.body || {};

        if (!ehTexto(email) || !email.trim() || !ehTexto(senha) || !senha) {
            return erro(res, 400, 'Informe e-mail e senha.');
        }

        const emailLimpo = email.trim().toLowerCase();

        const [usuarios] = await pool.execute(
            'SELECT * FROM usuarios WHERE email = ?',
            [emailLimpo]
        );

        const usuario = usuarios[0];

        // Compara sempre (mesmo sem usuário) para manter o tempo constante.
        const senhaCorreta = await bcrypt.compare(
            senha,
            usuario ? usuario.senha : HASH_FALSO
        );

        if (!usuario || !senhaCorreta) {
            return erro(res, 401, 'E-mail ou senha inválidos.');
        }

        // Só depois de acertar a senha revelamos que a conta está inativa.
        if (!usuario.ativo) {
            return erro(res, 403, 'Usuário inativo. Entre em contato com o suporte.');
        }

        const token = jwt.sign(
            {
                id: usuario.id,
                email: usuario.email
            },
            process.env.JWT_SECRET,
            {
                algorithm: 'HS256',
                expiresIn: '7d'
            }
        );

        return sucesso(res, 200, 'Login realizado com sucesso!', {
            token,
            usuario: montarUsuario(usuario)
        });

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível fazer login. Tente novamente.');
    }
}


// ========================================
// DADOS DO USUÁRIO LOGADO
// GET /api/auth/me
// ========================================

async function me(req, res) {
    try {
        const [usuarios] = await pool.execute(
            'SELECT * FROM usuarios WHERE id = ?',
            [req.usuario.id]
        );

        if (usuarios.length === 0) {
            return erro(res, 404, 'Usuário não encontrado.');
        }

        return sucesso(res, 200, 'Usuário encontrado.', {
            usuario: montarUsuario(usuarios[0])
        });

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível carregar seus dados.');
    }
}


// ========================================
// ATUALIZAR PERFIL
// PUT /api/auth/profile
// ========================================
// Altera nome, telefone e data de nascimento.
// O e-mail não muda por aqui (ele identifica a conta).

async function atualizarPerfil(req, res) {
    try {
        const { nome, telefone, data_nascimento } = req.body || {};

        if (!ehTexto(nome) || !nome.trim()) {
            return erro(res, 400, 'Preencha o nome.');
        }

        const nomeLimpo = nome.trim();
        const telefoneLimpo = ehTexto(telefone) && telefone.trim() ? telefone.trim() : null;
        const nascimentoLimpo = ehTexto(data_nascimento) && data_nascimento.trim() ? data_nascimento.trim() : null;

        if (nomeLimpo.length < 2 || nomeLimpo.length > 150) {
            return erro(res, 400, 'Informe um nome válido.');
        }

        const erroContato = validarContato(telefoneLimpo, nascimentoLimpo);

        if (erroContato) {
            return erro(res, 400, erroContato);
        }

        await pool.execute(
            `
            UPDATE usuarios
            SET nome = ?, telefone = ?, data_nascimento = ?
            WHERE id = ?
            `,
            [nomeLimpo, telefoneLimpo, nascimentoLimpo, req.usuario.id]
        );

        const [usuarios] = await pool.execute(
            'SELECT * FROM usuarios WHERE id = ?',
            [req.usuario.id]
        );

        return sucesso(res, 200, 'Perfil atualizado com sucesso!', {
            usuario: montarUsuario(usuarios[0])
        });

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível atualizar o perfil.');
    }
}


// ========================================
// TROCAR SENHA
// PUT /api/auth/change-password
// ========================================

async function trocarSenha(req, res) {
    try {
        const { senha_atual, nova_senha } = req.body || {};

        if (!ehTexto(senha_atual) || !senha_atual || !nova_senha) {
            return erro(res, 400, 'Preencha a senha atual e a nova senha.');
        }

        if (!senhaValida(nova_senha)) {
            return erro(
                res,
                400,
                `A nova senha deve ter entre ${SENHA_MINIMA} e 72 caracteres.`
            );
        }

        if (nova_senha === senha_atual) {
            return erro(res, 400, 'A nova senha deve ser diferente da atual.');
        }

        const [usuarios] = await pool.execute(
            'SELECT id, senha FROM usuarios WHERE id = ?',
            [req.usuario.id]
        );

        if (usuarios.length === 0) {
            return erro(res, 404, 'Usuário não encontrado.');
        }

        const senhaCorreta = await bcrypt.compare(
            senha_atual,
            usuarios[0].senha
        );

        if (!senhaCorreta) {
            return erro(res, 401, 'A senha atual está incorreta.');
        }

        const novoHash = await bcrypt.hash(nova_senha, 10);

        await pool.execute(
            'UPDATE usuarios SET senha = ? WHERE id = ?',
            [novoHash, req.usuario.id]
        );

        return sucesso(res, 200, 'Senha alterada com sucesso!');

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível alterar a senha.');
    }
}


module.exports = {
    cadastrar,
    login,
    me,
    atualizarPerfil,
    trocarSenha
};
