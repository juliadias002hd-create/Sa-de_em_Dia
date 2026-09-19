const multer = require('multer');


// Recebe UM arquivo no campo "arquivo" de uma requisição multipart/form-data.
// O arquivo fica na memória (máx. 10 MB) e só é gravado no disco depois
// que o controller confirma que é mesmo uma imagem ou PDF.
//
// Se a requisição for JSON comum (sem arquivo), este middleware não faz nada.

const TAMANHO_MAXIMO = 10 * 1024 * 1024;

const upload = multer({
    storage: multer.memoryStorage(),

    // Nomes de arquivo com acento (ex.: "receita ação.png") chegam em UTF-8.
    defParamCharset: 'utf8',

    limits: {
        fileSize: TAMANHO_MAXIMO,
        files: 1,
        fields: 20
    }
});

module.exports = upload.single('arquivo');
