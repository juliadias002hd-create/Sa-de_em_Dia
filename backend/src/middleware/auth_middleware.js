const jwt = require('jsonwebtoken');

function autenticar(req, res, next) {

    const cabecalho = req.headers.authorization;

    if (!cabecalho) {
        return res.status(401).json({
            erro: 'Token não informado.'
        });
    }

    const partes = cabecalho.split(' ');

    if (
        partes.length !== 2 ||
        partes[0] !== 'Bearer'
    ) {
        return res.status(401).json({
            erro: 'Formato do token inválido.'
        });
    }

    const token = partes[1];

    try {

        const usuario = jwt.verify(
            token,
            process.env.JWT_SECRET
        );

        req.usuario = usuario;

        next();

    } catch (erro) {

        return res.status(401).json({
            erro: 'Token inválido ou expirado.'
        });
    }
}

module.exports = autenticar;