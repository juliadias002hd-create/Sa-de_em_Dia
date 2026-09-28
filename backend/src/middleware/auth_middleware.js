const jwt = require('jsonwebtoken');

const pool = require('../database');
const { erro } = require('../utils/resposta');


// Protege as rotas privadas.
//
// 1. Exige o cabeçalho  Authorization: Bearer <token>
// 2. Valida a assinatura e a validade do token
// 3. Confere no banco se o usuário ainda existe e está ativo
//    (assim, um usuário desativado perde o acesso mesmo com token válido)
//
// Se tudo estiver certo, deixa o usuário disponível em req.usuario.

async function autenticar(req, res, next) {

    const cabecalho = req.headers.authorization;

    if (!cabecalho) {
        return erro(res, 401, 'Token não informado.');
    }

    const partes = cabecalho.split(' ');

    if (partes.length !== 2 || partes[0] !== 'Bearer') {
        return erro(res, 401, 'Formato do token inválido.');
    }

    let dados;

    try {
        dados = jwt.verify(partes[1], process.env.JWT_SECRET, {
            algorithms: ['HS256']
        });
    } catch (e) {
        return erro(res, 401, 'Sessão expirada. Faça login novamente.');
    }

    try {
        const [usuarios] = await pool.execute(
            'SELECT id, email, ativo, senha_alterada_em FROM usuarios WHERE id = ?',
            [dados.id]
        );

        if (usuarios.length === 0) {
            return erro(res, 401, 'Sessão inválida. Faça login novamente.');
        }

        if (!usuarios[0].ativo) {
            return erro(res, 403, 'Usuário inativo.');
        }

        // Se a senha foi redefinida depois deste login, a sessão antiga
        // deixa de valer (protege quem teve a senha descoberta).
        const alterada = usuarios[0].senha_alterada_em;

        if (alterada && dados.iat * 1000 < new Date(alterada.replace(' ', 'T')).getTime()) {
            return erro(res, 401, 'Sua senha foi alterada. Faça login novamente.');
        }

        req.usuario = {
            id: usuarios[0].id,
            email: usuarios[0].email
        };

        next();

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Erro ao validar o acesso.');
    }
}

module.exports = autenticar;
