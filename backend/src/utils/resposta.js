// Formato padrão de todas as respostas da API.
//
// Sucesso: { "success": true,  "message": "...", "data": {...} }
// Erro:    { "success": false, "message": "..." }

function sucesso(res, status, message, data = null) {
    return res.status(status).json({
        success: true,
        message,
        data
    });
}

function erro(res, status, message) {
    return res.status(status).json({
        success: false,
        message
    });
}

module.exports = {
    sucesso,
    erro
};
