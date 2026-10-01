const crypto = require('crypto');
const bcrypt = require('bcryptjs');

const pool = require('../database');
const { sucesso, erro } = require('../utils/resposta');
const { enviarEmail } = require('../utils/email');
const {
    ehTexto,
    emailValido,
    senhaValida,
    SENHA_MINIMA
} = require('../utils/validacoes');


// "Esqueci minha senha"
//
//  1. POST /api/auth/forgot-password  { email }
//     Envia um código de 6 dígitos por e-mail (vale 15 minutos).
//     A resposta é SEMPRE a mesma, exista ou não o e-mail, para que
//     ninguém descubra quem tem conta (e é enviada antes do trabalho
//     pesado, para o tempo de resposta também não denunciar).
//
//  2. POST /api/auth/reset-password   { email, codigo, nova_senha }
//     Confere o código e troca a senha. Depois disso, os logins antigos
//     deixam de valer.
//
// Proteções: código guardado só como hash; validade curta; no máximo
// 5 tentativas por código; no máximo 6 códigos por hora por usuário;
// código de uso único.

const VALIDADE_MINUTOS = 15;
const MAX_TENTATIVAS = 5;
const MAX_CODIGOS_POR_HORA = 6;

const MENSAGEM_ENVIO =
    'Se este e-mail estiver cadastrado, enviamos um código de 6 dígitos. ' +
    `Ele vale por ${VALIDADE_MINUTOS} minutos.`;

const MENSAGEM_CODIGO_INVALIDO = 'Código inválido ou expirado. Solicite um novo código.';

// Hash usado quando o e-mail não existe, para o tempo de resposta do
// reset ser parecido nos dois casos.
const HASH_FALSO = bcrypt.hashSync('000000', 10);


function gerarCodigo() {
    return String(crypto.randomInt(0, 1000000)).padStart(6, '0');
}


// Faz o trabalho de verdade DEPOIS de responder ao aplicativo.
async function processarSolicitacao(email) {
    try {
        const [usuarios] = await pool.execute(
            'SELECT id, nome, ativo FROM usuarios WHERE email = ?',
            [email]
        );

        if (usuarios.length === 0 || !usuarios[0].ativo) {
            return;
        }

        const usuario = usuarios[0];

        // Limite de pedidos por hora (evita encher a caixa de e-mail de alguém).
        const [recentes] = await pool.execute(
            `
            SELECT COUNT(*) AS total
            FROM redefinicoes_senha
            WHERE usuario_id = ?
              AND criado_em > DATE_SUB(NOW(), INTERVAL 1 HOUR)
            `,
            [usuario.id]
        );

        if (Number(recentes[0].total) >= MAX_CODIGOS_POR_HORA) {
            return;
        }

        const codigo = gerarCodigo();
        const codigoHash = await bcrypt.hash(codigo, 10);

        // Um código novo cancela os anteriores ainda não usados.
        await pool.execute(
            'UPDATE redefinicoes_senha SET usado_em = NOW() WHERE usuario_id = ? AND usado_em IS NULL',
            [usuario.id]
        );

        await pool.execute(
            `
            INSERT INTO redefinicoes_senha (usuario_id, codigo_hash, expira_em)
            VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ${VALIDADE_MINUTOS} MINUTE))
            `,
            [usuario.id, codigoHash]
        );

        const primeiroNome = String(usuario.nome).trim().split(/\s+/)[0];

        await enviarEmail({
            para: email,
            assunto: 'Saúde em Dia: código para redefinir sua senha',
            texto:
                `Olá, ${primeiroNome}!\n\n` +
                `Seu código para redefinir a senha do Saúde em Dia é:\n\n` +
                `    ${codigo}\n\n` +
                `Ele vale por ${VALIDADE_MINUTOS} minutos e só pode ser usado uma vez.\n\n` +
                `Se não foi você quem pediu, ignore este e-mail: sua senha continua a mesma.\n`
        });

    } catch (e) {
        console.error('Erro ao processar "esqueci minha senha":', e);
    }
}


// ========================================
// PEDIR O CÓDIGO
// POST /api/auth/forgot-password
// ========================================

async function esqueciSenha(req, res) {

    const { email } = req.body || {};

    if (!ehTexto(email) || !email.trim()) {
        return erro(res, 400, 'Informe seu e-mail.');
    }

    const emailLimpo = email.trim().toLowerCase();

    if (!emailValido(emailLimpo)) {
        return erro(res, 400, 'Informe um e-mail válido.');
    }

    // Responde já; o resto acontece em segundo plano.
    sucesso(res, 200, MENSAGEM_ENVIO);

    processarSolicitacao(emailLimpo);
}


// ========================================
// TROCAR A SENHA COM O CÓDIGO
// POST /api/auth/reset-password
// ========================================

async function redefinirSenha(req, res) {
    try {
        const { email, codigo, nova_senha } = req.body || {};

        if (
            !ehTexto(email) || !email.trim() ||
            !ehTexto(codigo) || !codigo.trim() ||
            !nova_senha
        ) {
            return erro(res, 400, 'Preencha o e-mail, o código e a nova senha.');
        }

        if (!senhaValida(nova_senha)) {
            return erro(
                res,
                400,
                `A nova senha deve ter entre ${SENHA_MINIMA} e 72 caracteres.`
            );
        }

        const emailLimpo = email.trim().toLowerCase();
        const codigoLimpo = codigo.trim();

        const [usuarios] = await pool.execute(
            'SELECT id, ativo FROM usuarios WHERE email = ?',
            [emailLimpo]
        );

        const usuario = usuarios[0];

        // Código mais recente, ainda válido.
        let pedido = null;

        if (usuario && usuario.ativo) {
            const [pedidos] = await pool.execute(
                `
                SELECT id, codigo_hash, tentativas
                FROM redefinicoes_senha
                WHERE usuario_id = ?
                  AND usado_em IS NULL
                  AND expira_em > NOW()
                ORDER BY id DESC
                LIMIT 1
                `,
                [usuario.id]
            );

            pedido = pedidos[0] || null;
        }

        // Conta esta tentativa ANTES de comparar, direto no banco e de uma só
        // vez. Assim, mesmo com várias tentativas simultâneas, ninguém passa
        // do limite de MAX_TENTATIVAS palpites por código.
        let podeTentar = false;

        if (pedido) {
            const [reserva] = await pool.execute(
                `
                UPDATE redefinicoes_senha
                SET tentativas = tentativas + 1
                WHERE id = ?
                  AND tentativas < ?
                  AND usado_em IS NULL
                  AND expira_em > NOW()
                `,
                [pedido.id, MAX_TENTATIVAS]
            );

            podeTentar = reserva.affectedRows === 1;
        }

        // Compara sempre (mesmo sem código) para manter o tempo parecido.
        const codigoCorreto = await bcrypt.compare(
            /^\d{6}$/.test(codigoLimpo) ? codigoLimpo : '------',
            pedido ? pedido.codigo_hash : HASH_FALSO
        );

        if (!podeTentar || !codigoCorreto) {
            return erro(res, 400, MENSAGEM_CODIGO_INVALIDO);
        }

        const novoHash = await bcrypt.hash(nova_senha, 10);

        const conexao = await pool.getConnection();

        try {
            await conexao.beginTransaction();

            // Marca o código como usado ANTES de trocar a senha: se dois
            // pedidos chegarem juntos, só um consegue.
            const [uso] = await conexao.execute(
                'UPDATE redefinicoes_senha SET usado_em = NOW() WHERE id = ? AND usado_em IS NULL',
                [pedido.id]
            );

            if (uso.affectedRows !== 1) {
                await conexao.rollback();

                return erro(res, 400, MENSAGEM_CODIGO_INVALIDO);
            }

            await conexao.execute(
                'UPDATE usuarios SET senha = ?, senha_alterada_em = NOW() WHERE id = ?',
                [novoHash, usuario.id]
            );

            // Qualquer outro código pendente deixa de valer.
            await conexao.execute(
                'UPDATE redefinicoes_senha SET usado_em = NOW() WHERE usuario_id = ? AND usado_em IS NULL',
                [usuario.id]
            );

            await conexao.commit();

        } catch (e) {
            await conexao.rollback();

            throw e;

        } finally {
            conexao.release();
        }

        return sucesso(res, 200, 'Senha alterada com sucesso! Entre com a nova senha.');

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível redefinir a senha. Tente novamente.');
    }
}


module.exports = {
    esqueciSenha,
    redefinirSenha
};
