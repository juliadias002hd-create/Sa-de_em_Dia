const pool = require('../database');
const { sucesso, erro } = require('../utils/resposta');
const {
    ehTexto,
    idValido,
    inteiroEntre,
    horarioValido
} = require('../utils/validacoes');


// A tabela medicamentos não guarda usuario_id: o dono do medicamento é
// o dono da receita. Por isso toda consulta passa por um JOIN com receitas
// filtrando pelo usuário logado. É isso que impede um paciente de ver
// medicamentos de outro.

const CAMPOS_MEDICAMENTO = `
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
`;

const INTERVALO_MAXIMO_HORAS = 168;   // 1 semana
const DURACAO_MAXIMA_DIAS = 730;      // 2 anos


// ========================================
// FUNÇÕES AUXILIARES
// ========================================

function montarMedicamento(linha) {
    return {
        id: linha.id,
        receita_id: linha.receita_id,
        nome: linha.nome,
        dosagem: linha.dosagem,
        intervalo_horas: linha.intervalo_horas,
        horario_inicio: linha.horario_inicio,
        duracao_dias: linha.duracao_dias,
        observacoes: linha.observacoes,
        ativo: !!linha.ativo,
        criado_em: linha.criado_em
    };
}


// Lê e valida os campos do medicamento.
// Devolve { dados } ou { mensagem } com o problema encontrado.
function lerDadosMedicamento(body) {

    const {
        nome,
        dosagem,
        intervalo_horas,
        horario_inicio,
        duracao_dias,
        observacoes
    } = body || {};

    if (
        !ehTexto(nome) || !nome.trim() ||
        !ehTexto(dosagem) || !dosagem.trim() ||
        intervalo_horas === undefined || intervalo_horas === null || intervalo_horas === '' ||
        duracao_dias === undefined || duracao_dias === null || duracao_dias === '' ||
        !horario_inicio
    ) {
        return { mensagem: 'Preencha todos os dados obrigatórios do medicamento.' };
    }

    const dados = {
        nome: nome.trim(),
        dosagem: dosagem.trim()
    };

    if (dados.nome.length < 2 || dados.nome.length > 150) {
        return { mensagem: 'Informe o nome do medicamento.' };
    }

    if (dados.dosagem.length > 50) {
        return { mensagem: 'A dosagem deve ter no máximo 50 caracteres.' };
    }

    dados.intervalo_horas = inteiroEntre(intervalo_horas, 1, INTERVALO_MAXIMO_HORAS);

    if (dados.intervalo_horas === null) {
        return {
            mensagem: `Informe o intervalo em horas (um número inteiro de 1 a ${INTERVALO_MAXIMO_HORAS}).`
        };
    }

    dados.duracao_dias = inteiroEntre(duracao_dias, 1, DURACAO_MAXIMA_DIAS);

    if (dados.duracao_dias === null) {
        return {
            mensagem: `Informe a duração em dias (um número inteiro de 1 a ${DURACAO_MAXIMA_DIAS}).`
        };
    }

    dados.horario_inicio = horarioValido(horario_inicio);

    if (dados.horario_inicio === null) {
        return { mensagem: 'Informe um horário inicial válido. Ex.: 08:00.' };
    }

    if (observacoes !== undefined && observacoes !== null && !ehTexto(observacoes)) {
        return { mensagem: 'As observações devem ser um texto.' };
    }

    dados.observacoes = ehTexto(observacoes) && observacoes.trim() ? observacoes.trim() : null;

    if (dados.observacoes !== null && dados.observacoes.length > 255) {
        return { mensagem: 'As observações devem ter no máximo 255 caracteres.' };
    }

    return { dados };
}


// Aceita true/false, 1/0, "true"/"false", "1"/"0".
// Devolve 1, 0 ou null (valor inválido).
function lerAtivo(valor) {
    if (valor === true || valor === 1 || valor === 'true' || valor === '1') {
        return 1;
    }

    if (valor === false || valor === 0 || valor === 'false' || valor === '0') {
        return 0;
    }

    return null;
}


// Busca um medicamento SOMENTE se pertencer ao usuário logado.
async function buscarDoUsuario(id, usuarioId) {

    const [medicamentos] = await pool.execute(
        `
        SELECT ${CAMPOS_MEDICAMENTO}
        FROM medicamentos m
        INNER JOIN receitas r ON r.id = m.receita_id
        WHERE m.id = ? AND r.usuario_id = ?
        `,
        [Number(id), usuarioId]
    );

    return medicamentos[0] || null;
}


// Confere se a receita existe e é do usuário logado.
async function receitaDoUsuario(receitaId, usuarioId) {

    const [receitas] = await pool.execute(
        'SELECT id FROM receitas WHERE id = ? AND usuario_id = ?',
        [Number(receitaId), usuarioId]
    );

    return receitas.length > 0;
}


// ========================================
// CADASTRAR MEDICAMENTO
// POST /api/medicamentos
// ========================================

async function cadastrar(req, res) {
    try {
        const receitaId = (req.body || {}).receita_id;

        const receitaIdTexto =
            typeof receitaId === 'number' ? String(receitaId) : receitaId;

        if (receitaIdTexto === undefined || receitaIdTexto === null || receitaIdTexto === '') {
            return erro(res, 400, 'Informe a receita do medicamento.');
        }

        const campos = lerDadosMedicamento(req.body);

        if (campos.mensagem) {
            return erro(res, 400, campos.mensagem);
        }

        if (!idValido(receitaIdTexto) || !(await receitaDoUsuario(receitaIdTexto, req.usuario.id))) {
            return erro(res, 404, 'Receita não encontrada.');
        }

        const [resultado] = await pool.execute(
            `
            INSERT INTO medicamentos
                (receita_id, nome, dosagem, intervalo_horas,
                 horario_inicio, duracao_dias, observacoes, ativo)
            VALUES (?, ?, ?, ?, ?, ?, ?, 1)
            `,
            [
                Number(receitaIdTexto),
                campos.dados.nome,
                campos.dados.dosagem,
                campos.dados.intervalo_horas,
                campos.dados.horario_inicio,
                campos.dados.duracao_dias,
                campos.dados.observacoes
            ]
        );

        const medicamento = await buscarDoUsuario(resultado.insertId, req.usuario.id);

        return sucesso(res, 201, 'Medicamento cadastrado com sucesso!', {
            medicamento: montarMedicamento(medicamento)
        });

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível cadastrar o medicamento. Tente novamente.');
    }
}


// ========================================
// LISTAR MEDICAMENTOS DO USUÁRIO LOGADO
// GET /api/medicamentos
// ========================================
// Filtro opcional:  ?ativo=true  ou  ?ativo=false

async function listar(req, res) {
    try {
        const parametros = [req.usuario.id];
        let filtroAtivo = '';

        if (req.query.ativo !== undefined) {
            const ativo = lerAtivo(req.query.ativo);

            if (ativo === null) {
                return erro(res, 400, 'O filtro "ativo" deve ser true ou false.');
            }

            filtroAtivo = 'AND m.ativo = ?';
            parametros.push(ativo);
        }

        const [medicamentos] = await pool.execute(
            `
            SELECT ${CAMPOS_MEDICAMENTO}
            FROM medicamentos m
            INNER JOIN receitas r ON r.id = m.receita_id
            WHERE r.usuario_id = ? ${filtroAtivo}
            ORDER BY m.ativo DESC, m.horario_inicio ASC, m.id ASC
            `,
            parametros
        );

        return sucesso(res, 200, 'Medicamentos carregados.', {
            medicamentos: medicamentos.map(montarMedicamento)
        });

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível carregar seus medicamentos.');
    }
}


// ========================================
// LISTAR MEDICAMENTOS DE UMA RECEITA
// GET /api/receitas/:receitaId/medicamentos
// ========================================

async function listarPorReceita(req, res) {
    try {
        const receitaId = req.params.receitaId;

        if (!idValido(receitaId) || !(await receitaDoUsuario(receitaId, req.usuario.id))) {
            return erro(res, 404, 'Receita não encontrada.');
        }

        const [medicamentos] = await pool.execute(
            `
            SELECT ${CAMPOS_MEDICAMENTO}
            FROM medicamentos m
            WHERE m.receita_id = ?
            ORDER BY m.horario_inicio ASC, m.id ASC
            `,
            [Number(receitaId)]
        );

        return sucesso(res, 200, 'Medicamentos da receita carregados.', {
            medicamentos: medicamentos.map(montarMedicamento)
        });

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível carregar os medicamentos da receita.');
    }
}


// ========================================
// CONSULTAR UM MEDICAMENTO
// GET /api/medicamentos/:id
// ========================================

async function buscarPorId(req, res) {
    try {
        if (!idValido(req.params.id)) {
            return erro(res, 404, 'Medicamento não encontrado.');
        }

        const medicamento = await buscarDoUsuario(req.params.id, req.usuario.id);

        if (!medicamento) {
            return erro(res, 404, 'Medicamento não encontrado.');
        }

        return sucesso(res, 200, 'Medicamento encontrado.', {
            medicamento: montarMedicamento(medicamento)
        });

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível carregar o medicamento.');
    }
}


// ========================================
// ATUALIZAR MEDICAMENTO
// PUT /api/medicamentos/:id
// ========================================
// Envie todos os campos do medicamento. O campo "ativo" é opcional
// (serve para pausar ou reativar). A receita do medicamento não muda.

async function atualizar(req, res) {
    try {
        if (!idValido(req.params.id)) {
            return erro(res, 404, 'Medicamento não encontrado.');
        }

        const atual = await buscarDoUsuario(req.params.id, req.usuario.id);

        if (!atual) {
            return erro(res, 404, 'Medicamento não encontrado.');
        }

        const campos = lerDadosMedicamento(req.body);

        if (campos.mensagem) {
            return erro(res, 400, campos.mensagem);
        }

        let ativo = atual.ativo ? 1 : 0;

        if ((req.body || {}).ativo !== undefined) {
            ativo = lerAtivo(req.body.ativo);

            if (ativo === null) {
                return erro(res, 400, 'O campo "ativo" deve ser true ou false.');
            }
        }

        await pool.execute(
            `
            UPDATE medicamentos
            SET nome = ?, dosagem = ?, intervalo_horas = ?,
                horario_inicio = ?, duracao_dias = ?, observacoes = ?, ativo = ?
            WHERE id = ?
            `,
            [
                campos.dados.nome,
                campos.dados.dosagem,
                campos.dados.intervalo_horas,
                campos.dados.horario_inicio,
                campos.dados.duracao_dias,
                campos.dados.observacoes,
                ativo,
                atual.id
            ]
        );

        const medicamento = await buscarDoUsuario(atual.id, req.usuario.id);

        return sucesso(res, 200, 'Medicamento atualizado com sucesso!', {
            medicamento: montarMedicamento(medicamento)
        });

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível atualizar o medicamento.');
    }
}


// ========================================
// EXCLUIR MEDICAMENTO
// DELETE /api/medicamentos/:id
// ========================================

async function excluir(req, res) {
    try {
        if (!idValido(req.params.id)) {
            return erro(res, 404, 'Medicamento não encontrado.');
        }

        const medicamento = await buscarDoUsuario(req.params.id, req.usuario.id);

        if (!medicamento) {
            return erro(res, 404, 'Medicamento não encontrado.');
        }

        await pool.execute(
            'DELETE FROM medicamentos WHERE id = ?',
            [medicamento.id]
        );

        return sucesso(res, 200, 'Medicamento excluído com sucesso!');

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível excluir o medicamento.');
    }
}


module.exports = {
    cadastrar,
    listar,
    listarPorReceita,
    buscarPorId,
    atualizar,
    excluir
};
