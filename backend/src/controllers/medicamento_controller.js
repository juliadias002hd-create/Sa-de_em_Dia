const pool = require('../database');


// ========================================
// CADASTRAR MEDICAMENTO
// ========================================

async function cadastrar(req, res) {

    try {

        const usuarioId = req.usuario.id;

        const {
            receita_id,
            nome,
            dosagem,
            intervalo_horas,
            duracao_dias,
            horario_inicio,
            observacoes
        } = req.body;


        if (
            !receita_id ||
            !nome ||
            !dosagem ||
            !intervalo_horas ||
            !duracao_dias ||
            !horario_inicio
        ) {

            return res.status(400).json({
                erro: 'Preencha todos os dados obrigatórios.'
            });
        }


        // Verificar se a receita pertence ao usuário logado

        const [receitas] = await pool.query(
            `
            SELECT id
            FROM receitas
            WHERE id = ?
            AND usuario_id = ?
            `,
            [
                receita_id,
                usuarioId
            ]
        );


        if (receitas.length === 0) {

            return res.status(404).json({
                erro: 'Receita não encontrada.'
            });
        }


        const [resultado] = await pool.query(
            `
            INSERT INTO medicamentos
            (
                receita_id,
                nome,
                dosagem,
                intervalo_horas,
                duracao_dias,
                horario_inicio,
                observacoes,
                ativo
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, 1)
            `,
            [
                receita_id,
                nome,
                dosagem,
                intervalo_horas,
                duracao_dias,
                horario_inicio,
                observacoes || null
            ]
        );


        res.status(201).json({

            mensagem: 'Medicamento cadastrado com sucesso!',

            medicamento: {
                id: resultado.insertId,
                receita_id,
                nome,
                dosagem,
                intervalo_horas,
                duracao_dias,
                horario_inicio,
                observacoes: observacoes || null,
                ativo: true
            }

        });

    } catch (erro) {

        console.error(erro);

        res.status(500).json({
            erro: 'Erro ao cadastrar medicamento.'
        });
    }
}


// ========================================
// LISTAR MEDICAMENTOS DO USUÁRIO LOGADO
// ========================================
// A tabela medicamentos não guarda usuario_id diretamente,
// então a posse é verificada pelo JOIN com receitas.

async function listar(req, res) {

    try {

        const usuarioId = req.usuario.id;


        const [medicamentos] = await pool.query(
            `
            SELECT
                m.id,
                m.receita_id,
                m.nome,
                m.dosagem,
                m.intervalo_horas,
                m.horario_inicio,
                m.duracao_dias,
                m.observacoes,
                m.ativo,
                m.criado_em
            FROM medicamentos m
            INNER JOIN receitas r ON r.id = m.receita_id
            WHERE r.usuario_id = ?
            ORDER BY m.horario_inicio ASC
            `,
            [usuarioId]
        );


        res.json(medicamentos);

    } catch (erro) {

        console.error(erro);

        res.status(500).json({
            erro: 'Erro ao consultar medicamentos.'
        });
    }
}


// ========================================
// LISTAR MEDICAMENTOS DE UMA RECEITA
// ========================================

async function listarPorReceita(req, res) {

    try {

        const usuarioId = req.usuario.id;

        const receitaId = req.params.receitaId;


        // Confirma que a receita é do usuário logado antes de listar

        const [receitas] = await pool.query(
            `
            SELECT id
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


        const [medicamentos] = await pool.query(
            `
            SELECT
                id,
                receita_id,
                nome,
                dosagem,
                intervalo_horas,
                horario_inicio,
                duracao_dias,
                observacoes,
                ativo,
                criado_em
            FROM medicamentos
            WHERE receita_id = ?
            ORDER BY horario_inicio ASC
            `,
            [receitaId]
        );


        res.json(medicamentos);

    } catch (erro) {

        console.error(erro);

        res.status(500).json({
            erro: 'Erro ao consultar medicamentos.'
        });
    }
}


module.exports = {
    cadastrar,
    listar,
    listarPorReceita
};
