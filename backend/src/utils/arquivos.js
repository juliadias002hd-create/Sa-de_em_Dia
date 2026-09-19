const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');


// Pasta onde ficam os arquivos das receitas: backend/uploads/receitas
const PASTA_RECEITAS = path.join(__dirname, '..', '..', 'uploads', 'receitas');

// Nome com que o arquivo é guardado no disco (sempre gerado pelo servidor).
const NOME_SEGURO = /^[0-9a-f-]{36}\.(jpg|png|webp|pdf)$/;


// Descobre o tipo REAL do arquivo pelos primeiros bytes.
// Não confia no nome nem no tipo informado pelo aplicativo,
// pois esses dados podem ser falsificados.
// Devolve { tipo, extensao, mime } ou null se não for imagem/PDF aceito.
function detectarTipo(buffer) {

    if (!Buffer.isBuffer(buffer) || buffer.length < 12) {
        return null;
    }

    // JPEG
    if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
        return { tipo: 'imagem', extensao: 'jpg', mime: 'image/jpeg' };
    }

    // PNG
    if (buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
        return { tipo: 'imagem', extensao: 'png', mime: 'image/png' };
    }

    // WEBP  (RIFF....WEBP)
    if (
        buffer.subarray(0, 4).toString('ascii') === 'RIFF' &&
        buffer.subarray(8, 12).toString('ascii') === 'WEBP'
    ) {
        return { tipo: 'imagem', extensao: 'webp', mime: 'image/webp' };
    }

    // PDF
    if (buffer.subarray(0, 5).toString('ascii') === '%PDF-') {
        return { tipo: 'pdf', extensao: 'pdf', mime: 'application/pdf' };
    }

    return null;
}


// Limpa o nome original só para exibição (nunca usado como caminho).
function limparNomeOriginal(nome) {

    if (typeof nome !== 'string') {
        return null;
    }

    const limpo = path
        .basename(nome.replace(/\\/g, '/'))
        .replace(/[^\p{L}\p{N}._ ()-]/gu, '_')
        .slice(0, 200)
        .trim();

    return limpo || null;
}


// Grava o arquivo e devolve o nome guardado no disco.
async function salvarArquivo(buffer, extensao) {

    await fs.mkdir(PASTA_RECEITAS, { recursive: true });

    const nome = `${crypto.randomUUID()}.${extensao}`;

    await fs.writeFile(path.join(PASTA_RECEITAS, nome), buffer, { flag: 'wx' });

    return nome;
}


// Caminho completo de um arquivo já guardado, ou null se o nome for suspeito.
function caminhoDoArquivo(nome) {

    if (typeof nome !== 'string' || !NOME_SEGURO.test(nome)) {
        return null;
    }

    return path.join(PASTA_RECEITAS, nome);
}


// Apaga o arquivo. Se ele já não existir, não é erro.
async function apagarArquivo(nome) {

    const caminho = caminhoDoArquivo(nome);

    if (!caminho) {
        return;
    }

    try {
        await fs.unlink(caminho);
    } catch (e) {
        if (e.code !== 'ENOENT') {
            console.error('Não foi possível apagar o arquivo', nome, e.message);
        }
    }
}


module.exports = {
    detectarTipo,
    limparNomeOriginal,
    salvarArquivo,
    caminhoDoArquivo,
    apagarArquivo
};
