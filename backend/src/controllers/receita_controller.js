const pool = require('../database');
const { sucesso, erro } = require('../utils/resposta');
const {
    ehTexto,
    dataReceitaValida,
    idValido
} = require('../utils/validacoes');
const {
    detectarTipo,
    limparNomeOriginal,
    salvarArquivo,
    caminhoDoArquivo,
    apagarArquivo
} = require('../utils/arquivos');


const CAMPOS_RECEITA = `
    id,
    data_receita,
    medico,
    especialidade,
    arquivo_url,
    tipo_arquivo,
    nome_arquivo,
    criado_em
`;

const MENSAGEM_ARQUIVO_INVALIDO =
    'Arquivo inválido. Envie uma imagem (JPG, PNG ou WEBP) ou um PDF.';


// ========================================
// FUNÇÕES AUXILIARES
// ========================================

// Converte a linha do banco no objeto devolvido pela API.
// No banco, arquivo_url guarda o nome do arquivo no servidor.
// Para o aplicativo, arquivo_url é o endereço para baixar o arquivo
// (rota protegida por login: só o dono da receita consegue abrir).
function montarReceita(linha) {
    const receita = {
        id: linha.id,
        data_receita: linha.data_receita,
        medico: linha.medico,
        especialidade: linha.especialidade,
        tem_arquivo: !!linha.arquivo_url,
        arquivo_url: linha.arquivo_url ? `/api/receitas/${linha.id}/arquivo` : null,
        tipo_arquivo: linha.tipo_arquivo,
        nome_arquivo: linha.nome_arquivo,
        criado_em: linha.criado_em
    };

    if (linha.total_medicamentos !== undefined) {
        receita.total_medicamentos = Number(linha.total_medicamentos);
    }

    return receita;
}


// Lê e valida os campos de texto da receita.
// Devolve { dados } se estiver tudo certo ou { mensagem } com o problema.
function lerDadosReceita(body) {

    const { data_receita, medico, especialidade } = body || {};

    if (
        !ehTexto(data_receita) || !data_receita.trim() ||
        !ehTexto(medico) || !medico.trim() ||
        !ehTexto(especialidade) || !especialidade.trim()
    ) {
        return { mensagem: 'Preencha os dados obrigatórios da receita.' };
    }

    const dados = {
        data_receita: data_receita.trim(),
        medico: medico.trim(),
        especialidade: especialidade.trim()
    };

    if (dados.medico.length < 2 || dados.medico.length > 150) {
        return { mensagem: 'Informe o nome do médico.' };
    }

    if (dados.especialidade.length < 2 || dados.especialidade.length > 100) {
        return { mensagem: 'Informe a especialidade.' };
    }

    if (!dataReceitaValida(dados.data_receita)) {
        return {
            mensagem: 'Informe uma data de receita válida (AAAA-MM-DD, sem ser no futuro).'
        };
    }

    return { dados };
}


// Confere o arquivo enviado (se houver).
// Devolve { arquivo } (ou { arquivo: null } sem envio) ou { mensagem }.
function lerArquivoEnviado(req) {

    if (!req.file) {
        return { arquivo: null };
    }

    const tipo = detectarTipo(req.file.buffer);

    if (!tipo) {
        return { mensagem: MENSAGEM_ARQUIVO_INVALIDO };
    }

    return {
        arquivo: {
            buffer: req.file.buffer,
            tipo: tipo.tipo,
            extensao: tipo.extensao,
            nomeOriginal: limparNomeOriginal(req.file.originalname)
        }
    };
}


// Busca uma receita SOMENTE se ela pertencer ao usuário logado.
// É aqui que se impede um paciente de ver receitas de outro.
async function buscarDoUsuario(id, usuarioId) {

    const [receitas] = await pool.execute(
        `SELECT ${CAMPOS_RECEITA} FROM receitas WHERE id = ? AND usuario_id = ?`,
        [Number(id), usuarioId]
    );

    return receitas[0] || null;
}


// ========================================
// CADASTRAR RECEITA
// POST /api/receitas
// ========================================
// Aceita JSON (sem arquivo) ou multipart/form-data
// (campos de texto + arquivo no campo "arquivo").

async function cadastrar(req, res) {

    let nomeGuardado = null;

    try {
        const campos = lerDadosReceita(req.body);

        if (campos.mensagem) {
            return erro(res, 400, campos.mensagem);
        }

        const enviado = lerArquivoEnviado(req);

        if (enviado.mensagem) {
            return erro(res, 400, enviado.mensagem);
        }

        if (enviado.arquivo) {
            nomeGuardado = await salvarArquivo(
                enviado.arquivo.buffer,
                enviado.arquivo.extensao
            );
        }

        const [resultado] = await pool.execute(
            `
            INSERT INTO receitas
                (usuario_id, data_receita, medico, especialidade,
                 arquivo_url, tipo_arquivo, nome_arquivo)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            `,
            [
                req.usuario.id,
                campos.dados.data_receita,
                campos.dados.medico,
                campos.dados.especialidade,
                nomeGuardado,
                enviado.arquivo ? enviado.arquivo.tipo : null,
                enviado.arquivo ? enviado.arquivo.nomeOriginal : null
            ]
        );

        const receita = await buscarDoUsuario(resultado.insertId, req.usuario.id);

        return sucesso(res, 201, 'Receita salva com sucesso!', {
            receita: montarReceita(receita)
        });

    } catch (e) {

        // Não deixa arquivo órfão no disco se o banco falhou.
        await apagarArquivo(nomeGuardado);

        console.error(e);

        return erro(res, 500, 'Não foi possível salvar a receita. Tente novamente.');
    }
}


// ========================================
// LISTAR RECEITAS DO USUÁRIO LOGADO
// GET /api/receitas
// ========================================

async function listar(req, res) {
    try {
        const [receitas] = await pool.execute(
            `
            SELECT
                r.id,
                r.data_receita,
                r.medico,
                r.especialidade,
                r.arquivo_url,
                r.tipo_arquivo,
                r.nome_arquivo,
                r.criado_em,
                (
                    SELECT COUNT(*)
                    FROM medicamentos m
                    WHERE m.receita_id = r.id
                ) AS total_medicamentos
            FROM receitas r
            WHERE r.usuario_id = ?
            ORDER BY r.data_receita DESC, r.id DESC
            `,
            [req.usuario.id]
        );

        return sucesso(res, 200, 'Receitas carregadas.', {
            receitas: receitas.map(montarReceita)
        });

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível carregar suas receitas.');
    }
}


// ========================================
// CONSULTAR UMA RECEITA (com seus medicamentos)
// GET /api/receitas/:id
// ========================================

async function buscarPorId(req, res) {
    try {
        if (!idValido(req.params.id)) {
            return erro(res, 404, 'Receita não encontrada.');
        }

        const receita = await buscarDoUsuario(req.params.id, req.usuario.id);

        if (!receita) {
            return erro(res, 404, 'Receita não encontrada.');
        }

        const [medicamentos] = await pool.execute(
            `
            SELECT
                id, receita_id, nome, dosagem, intervalo_horas,
                horario_inicio, duracao_dias, observacoes, ativo, criado_em
            FROM medicamentos
            WHERE receita_id = ?
            ORDER BY horario_inicio ASC, id ASC
            `,
            [receita.id]
        );

        return sucesso(res, 200, 'Receita encontrada.', {
            receita: {
                ...montarReceita(receita),
                medicamentos: medicamentos.map((m) => ({
                    ...m,
                    ativo: !!m.ativo
                }))
            }
        });

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível carregar a receita.');
    }
}


// ========================================
// ATUALIZAR RECEITA
// PUT /api/receitas/:id
// ========================================
// Os três campos de texto são sempre enviados.
// Arquivo: enviar um novo em "arquivo" substitui o antigo;
// enviar remover_arquivo=true apaga o arquivo; sem nada, mantém o atual.

async function atualizar(req, res) {

    let novoNome = null;

    try {
        if (!idValido(req.params.id)) {
            return erro(res, 404, 'Receita não encontrada.');
        }

        const atual = await buscarDoUsuario(req.params.id, req.usuario.id);

        if (!atual) {
            return erro(res, 404, 'Receita não encontrada.');
        }

        const campos = lerDadosReceita(req.body);

        if (campos.mensagem) {
            return erro(res, 400, campos.mensagem);
        }

        const enviado = lerArquivoEnviado(req);

        if (enviado.mensagem) {
            return erro(res, 400, enviado.mensagem);
        }

        const remover = ['true', '1'].includes(
            String((req.body || {}).remover_arquivo).toLowerCase()
        );

        let arquivoUrl = atual.arquivo_url;
        let tipoArquivo = atual.tipo_arquivo;
        let nomeArquivo = atual.nome_arquivo;

        if (enviado.arquivo) {
            novoNome = await salvarArquivo(
                enviado.arquivo.buffer,
                enviado.arquivo.extensao
            );

            arquivoUrl = novoNome;
            tipoArquivo = enviado.arquivo.tipo;
            nomeArquivo = enviado.arquivo.nomeOriginal;

        } else if (remover) {
            arquivoUrl = null;
            tipoArquivo = null;
            nomeArquivo = null;
        }

        await pool.execute(
            `
            UPDATE receitas
            SET data_receita = ?, medico = ?, especialidade = ?,
                arquivo_url = ?, tipo_arquivo = ?, nome_arquivo = ?
            WHERE id = ? AND usuario_id = ?
            `,
            [
                campos.dados.data_receita,
                campos.dados.medico,
                campos.dados.especialidade,
                arquivoUrl,
                tipoArquivo,
                nomeArquivo,
                atual.id,
                req.usuario.id
            ]
        );

        // Só agora que o banco foi atualizado é seguro apagar o arquivo antigo.
        if (atual.arquivo_url && atual.arquivo_url !== arquivoUrl) {
            await apagarArquivo(atual.arquivo_url);
        }

        const receita = await buscarDoUsuario(atual.id, req.usuario.id);

        return sucesso(res, 200, 'Receita atualizada com sucesso!', {
            receita: montarReceita(receita)
        });

    } catch (e) {

        await apagarArquivo(novoNome);

        console.error(e);

        return erro(res, 500, 'Não foi possível atualizar a receita.');
    }
}


// ========================================
// EXCLUIR RECEITA
// DELETE /api/receitas/:id
// ========================================
// Os medicamentos da receita são apagados junto pelo banco
// (chave estrangeira com ON DELETE CASCADE).

async function excluir(req, res) {
    try {
        if (!idValido(req.params.id)) {
            return erro(res, 404, 'Receita não encontrada.');
        }

        const receita = await buscarDoUsuario(req.params.id, req.usuario.id);

        if (!receita) {
            return erro(res, 404, 'Receita não encontrada.');
        }

        await pool.execute(
            'DELETE FROM receitas WHERE id = ? AND usuario_id = ?',
            [receita.id, req.usuario.id]
        );

        await apagarArquivo(receita.arquivo_url);

        return sucesso(res, 200, 'Receita excluída com sucesso!');

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível excluir a receita.');
    }
}


// ========================================
// BAIXAR O ARQUIVO DA RECEITA
// GET /api/receitas/:id/arquivo
// ========================================

async function baixarArquivo(req, res) {
    try {
        if (!idValido(req.params.id)) {
            return erro(res, 404, 'Receita não encontrada.');
        }

        const receita = await buscarDoUsuario(req.params.id, req.usuario.id);

        if (!receita) {
            return erro(res, 404, 'Receita não encontrada.');
        }

        const caminho = caminhoDoArquivo(receita.arquivo_url);

        if (!caminho) {
            return erro(res, 404, 'Esta receita não possui arquivo.');
        }

        return res.sendFile(
            caminho,
            {
                headers: {
                    'Content-Disposition': 'inline',
                    'X-Content-Type-Options': 'nosniff',
                    'Cache-Control': 'private, no-store'
                }
            },
            (e) => {
                if (!e || res.headersSent) {
                    return;
                }

                if (e.code === 'ENOENT') {
                    return erro(res, 404, 'O arquivo desta receita não foi encontrado.');
                }

                console.error(e);

                return erro(res, 500, 'Não foi possível abrir o arquivo.');
            }
        );

    } catch (e) {
        console.error(e);

        return erro(res, 500, 'Não foi possível abrir o arquivo.');
    }
}


module.exports = {
    cadastrar,
    listar,
    buscarPorId,
    atualizar,
    excluir,
    baixarArquivo
};
