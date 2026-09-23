const pool = require('../database');
const { sucesso, erro } = require('../utils/resposta');
const { dataValida, idValido, inteiroEntre } = require('../utils/validacoes');


// Registro das doses tomadas (alimenta o Histórico e o status "Tomado").
//
// O dono de um registro é o dono da receita do medicamento: toda consulta
// passa por JOIN medicamentos -> receitas filtrando pelo usuário logado.
//
// Horários são "horário de parede" (sem fuso), no mesmo relógio do servidor
// e do banco: "AAAA-MM-DD HH:MM:SS".

const PERIODO_MAXIMO_DIAS = 92;

const CAMPOS_REGISTRO = `
    rd.id,
    rd.medicamento_id,
    m.nome AS medicamento_nome,
    m.dosagem AS medicamento_dosagem,
    rd.horario_previsto,
    rd.horario_tomado,
    rd.status
`;


// ========================================
// FUNÇÕES AUXILIARES
// ========================================

function dois(n) {
    return String(n).padStart(2, '0');
}

// Data/hora local no formato do banco.
function formatarLocal(d) {
    return (
        `${d.getFullYear()}-${dois(d.getMonth() + 1)}-${dois(d.getDate())} ` +
        `${dois(d.getHours())}:${dois(d.getMinutes())}:${dois(d.getSeconds())}`
    );
}

// Aceita "AAAA-MM-DD HH:MM[:SS]" ou "AAAA-MM-DDTHH:MM[:SS]".
// Devolve "AAAA-MM-DD HH:MM:SS" ou null se for inválido.
function lerDataHora(valor) {
    if (typeof valor !== 'string') {
        return null;
    }

    const partes = valor.trim().match(
        /^(\d{4}-\d{2}-\d{2})[ T]([01]\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?$/
    );

    if (!partes || !dataValida(partes[1])) {
        return null;
    }

    return `${partes[1]} ${partes[2]}:${partes[3]}:${partes[4] || '00'}`;
}

function montarRegistro(linha) {
    return {
        id: linha.id,
        medicamento_id: linha.medicamento_id,
        medicamento_nome: linha.medicamento_nome,
        medicamento_dosagem: linha.medicamento_dosagem,
        horario_previsto: linha.horario_previsto,
        horario_tomado: linha.horario_tomado,
        status: linha.status
    };
}

async function buscarRegistroDoUsuario(id, usuarioId) {
    const [linhas] = await pool.execute(
        `
        SELECT ${CAMPOS_REGISTRO}
        FROM registros_doses rd
        INNER JOIN medicamentos m ON m.id = rd.medicamento_id
        INNER JOIN receitas r ON r.id = m.receita_id
        WHERE rd.id = ? AND r.usuario_id = ?
        `,
        [Number(id), usuarioId]
    );

    return linhas[0] || null;
}


// ========================================
// MARCAR UMA DOSE COMO TOMADA
// POST /api/doses
// ========================================
// Corpo: { medicamento_id, horario_previsto, horario_tomado? }
// Sem horario_tomado, vale o momento atual.

async function registrar(req, res) {
    try {
        const { medicamento_id, horario_previsto, horario_tomado } = req.body || {};

        const medicamentoId = inteiroEntre(medicamento_id, 1, 4294967295);

        if (medicamentoId === null || horario_previsto === undefined) {
            return erro(res, 400, 'Informe o medicamento e o horário da dose.');
        }

        let previsto = lerDataHora(horario_previsto);

        if (previsto === null) {
            return erro(res, 400, 'Informe o horário da dose no formato AAAA-MM-DD HH:MM.');
        }

        // Uma dose vale por minuto: 08:00:45 e 08:00:00 são a mesma dose.
        previsto = `${previsto.slice(0, 16)}:00`;

        const agora = new Date();

        let tomado = formatarLocal(agora);

        if (horario_tomado !== undefined && horario_tomado !== null) {
            tomado = lerDataHora(horario_tomado);

            if (tomado === null) {
                return erro(res, 400, 'Informe o horário em que tomou no formato AAAA-MM-DD HH:MM.');
            }

            // Tolerância de 5 minutos para diferença de relógio.
            const limite = formatarLocal(new Date(agora.getTime() + 5 * 60 * 1000));

            if (tomado > limite) {
                return erro(res, 400, 'O horário em que tomou não pode estar no futuro.');
            }
        }

        // O medicamento precisa ser do usuário logado.
        const [medicamentos] = await pool.execute(
            `
            SELECT m.id, m.criado_em, m.duracao_dias
            FROM medicamentos m
            INNER JOIN receitas r ON r.id = m.receita_id
            WHERE m.id = ? AND r.usuario_id = ?
            `,
            [medicamentoId, req.usuario.id]
        );

        if (medicamentos.length === 0) {
            return erro(res, 404, 'Medicamento não encontrado.');
        }

        // A dose precisa cair dentro do período do tratamento
        // (com 1 dia de folga para cada lado).
        const criado = new Date(medicamentos[0].criado_em.replace(' ', 'T'));
        const inicio = formatarLocal(new Date(criado.getTime() - 24 * 3600 * 1000));
        const fim = formatarLocal(
            new Date(criado.getTime() + (medicamentos[0].duracao_dias + 1) * 24 * 3600 * 1000)
        );

        if (previsto < inicio || previsto > fim) {
            return erro(res, 400, 'Esse horário está fora do período do tratamento.');
        }

        const [resultado] = await pool.execute(
            `
            INSERT INTO registros_doses
                (medicamento_id, horario_previsto, horario_tomado, status)
            VALUES (?, ?, ?, 'tomado')
            `,
            [medicamentoId, previsto, tomado]
        );

        const registro = await buscarRegistroDoUsuario(resultado.insertId, req.usuario.id);

        return sucesso(res, 201, 'Dose registrada com sucesso!', {
            registro: montarRegistro(registro)
        });

    } catch (e) {
        if (e.code === 'ER_DUP_ENTRY') {
            return erro(res, 409, 'Esta dose já foi marcada como tomada.');
        }

        console.error(e);

        return erro(res, 500, 'Não foi possível registrar a dose. Tente novamente.');
    }
}


// ========================================
// LISTAR DOSES TOMADAS NUM PERÍODO
// GET /api/doses?inicio=AAAA-MM-DD&fim=AAAA-MM-DD
// ========================================
// Filtra pelo horário PREVISTO da dose. Sem parâmetros, devolve hoje.
// O período máximo é de 92 dias.

async function listar(req, res) {
    try {
        const hoje = formatarLocal(new Date()).slice(0, 10);

        const inicio = req.query.inicio === undefined ? hoje : req.query.inicio;
        const fim = req.query.fim === undefined ? inicio : req.query.fim;

        if (!dataValida(inicio) || !dataValida(fim)) {
            return erro(res, 400, 'Informe as datas no formato AAAA-MM-DD.');
        }

        if (fim < inicio) {
            return erro(res, 400, 'A data final não pode ser anterior à inicial.');
        }

        const dias =
            (Date.parse(`${fim}T00:00:00Z`) - Date.parse(`${inicio}T00:00:00Z`)) / 86400000 + 1;

        if (dias > PERIODO_MAXIMO_DIAS) {
            return erro(res, 400, `O período máximo é de ${PERIODO_MAXIMO_DIAS} dias.`);
        }

        const [registros] = await pool.execute(
            `
            SELECT ${CAMPOS_REGISTRO}
            FROM registros_doses rd
            INNER JOIN medicamentos m ON m.id = rd.medicamento_id
            INNER JOIN receitas r ON r.id = m.receita_id
            WHERE r.usuario_id = ?
              AND rd.horario_previsto >= ?
              AND rd.horario_previsto < DATE_ADD(?, INTERVAL 1 DAY)
            ORDER BY rd.horario_previsto ASC, rd.id ASC
            `,
            [req.usuario.id, `${inicio} 00:00:00`, `${fim} 00:00:00`]
        );

        return sucesso(res, 200, 'Doses carregadas.', {
            registros: registros.map(montarRegistro)
        });

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível carregar o histórico.');
    }
}


// ========================================
// DESFAZER O REGISTRO DE UMA DOSE
// DELETE /api/doses/:id
// ========================================

async function desfazer(req, res) {
    try {
        if (!idValido(req.params.id)) {
            return erro(res, 404, 'Registro não encontrado.');
        }

        const registro = await buscarRegistroDoUsuario(req.params.id, req.usuario.id);

        if (!registro) {
            return erro(res, 404, 'Registro não encontrado.');
        }

        await pool.execute('DELETE FROM registros_doses WHERE id = ?', [registro.id]);

        return sucesso(res, 200, 'Registro desfeito.');

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível desfazer o registro.');
    }
}


module.exports = {
    registrar,
    listar,
    desfazer
};
