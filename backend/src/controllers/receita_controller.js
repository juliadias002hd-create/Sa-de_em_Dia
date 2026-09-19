const pool = require('../database');


// ========================================
// CADASTRAR RECEITA
// ========================================

async function cadastrar(req, res) {

    try {

        const usuarioId = req.usuario.id;

        const {
            data_receita,
            medico,
            especialidade,
            nome_arquivo,
            tipo_arquivo,
            arquivo_url
        } = req.body;


        if (
            !data_receita ||
            !medico ||
            !especialidade
        ) {

            return res.status(400).json({
                erro: 'Preencha os dados obrigatórios da receita.'
            });
        }


        const [resultado] = await pool.query(
            `
            INSERT INTO receitas
            (
                usuario_id,
                data_receita,
                medico,
                especialidade,
                arquivo_url,
                tipo_arquivo,
                nome_arquivo
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            `,
            [
                usuarioId,
                data_receita,
                medico,
                especialidade,
                arquivo_url || null,
                tipo_arquivo || null,
                nome_arquivo || null
            ]
        );


        res.status(201).json({

            mensagem: 'Receita salva com sucesso!',

            receita: {
                id: resultado.insertId,
                usuario_id: usuarioId,
                data_receita,
                medico,
                especialidade,
                arquivo_url: arquivo_url || null,
                tipo_arquivo: tipo_arquivo || null,
                nome_arquivo: nome_arquivo || null
            }

        });

    } catch (erro) {

        console.error(erro);

        res.status(500).json({
            erro: 'Erro ao cadastrar receita.'
        });
    }
}


// ========================================
// CONSULTAR RECEITAS
// ========================================

async function listar(req, res) {

    try {

        const usuarioId = req.usuario.id;

        const [receitas] = await pool.query(
            `
            SELECT
                id,
                data_receita,
                medico,
                especialidade,
                arquivo_url,
                tipo_arquivo,
                nome_arquivo,
                criado_em
            FROM receitas
            WHERE usuario_id = ?
            ORDER BY data_receita DESC
            `,
            [usuarioId]
        );


        res.json(receitas);

    } catch (erro) {

        console.error(erro);

        res.status(500).json({
            erro: 'Erro ao consultar receitas.'
        });
    }
}


// ========================================
// CONSULTAR UMA RECEITA
// ========================================

async function buscarPorId(req, res) {

    try {

        const usuarioId = req.usuario.id;

        const receitaId = req.params.id;


        const [receitas] = await pool.query(
            `
            SELECT
                id,
                data_receita,
                medico,
                especialidade,
                arquivo_url,
                tipo_arquivo,
                nome_arquivo,
                criado_em
            FROM receitas
            WHERE id = ?
            AND usuario_id = ?
            `,
            [
                receitaId,
                usuarioId
            ]
        );


        if (receitas.length === 0) {

            return res.status(404).json({
                erro: 'Receita não encontrada.'
            });
        }


        res.json(receitas[0]);

    } catch (erro) {

        console.error(erro);

        res.status(500).json({
            erro: 'Erro ao consultar receita.'
        });
    }
}


module.exports = {
    cadastrar,
    listar,
    buscarPorId
};
