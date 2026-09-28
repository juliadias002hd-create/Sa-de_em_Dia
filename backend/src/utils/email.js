const nodemailer = require('nodemailer');


// Envio de e-mails (usado no "Esqueci minha senha").
//
// COM configuração de SMTP no .env  -> envia o e-mail de verdade.
// SEM configuração (modo desenvolvimento) -> não envia nada: escreve o
// conteúdo no terminal onde a API está rodando, para você copiar o código.
//
// Chaves do .env (veja backend/.env.example):
//   SMTP_HOST, SMTP_PORT, SMTP_SECURE, SMTP_USER, SMTP_PASS, SMTP_FROM


function smtpConfigurado() {
    return !!process.env.SMTP_HOST;
}


function criarTransporte() {
    const porta = Number(process.env.SMTP_PORT) || 587;

    const config = {
        host: process.env.SMTP_HOST,
        port: porta,

        // true para a porta 465; false para 587 e 25 (usa STARTTLS).
        secure: String(process.env.SMTP_SECURE).toLowerCase() === 'true',

        // Evita que um servidor de e-mail lento trave a API.
        connectionTimeout: 10000,
        greetingTimeout: 10000,
        socketTimeout: 15000
    };

    if (process.env.SMTP_USER) {
        config.auth = {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS || ''
        };
    }

    return nodemailer.createTransport(config);
}


// Devolve true se o e-mail foi entregue ao servidor SMTP.
// Nunca lança erro: falhas são registradas no terminal.
async function enviarEmail({ para, assunto, texto }) {

    if (!smtpConfigurado()) {
        console.log('');
        console.log('==================== E-MAIL (modo desenvolvimento) ====================');
        console.log(`Para:    ${para}`);
        console.log(`Assunto: ${assunto}`);
        console.log('');
        console.log(texto);
        console.log('SMTP não configurado no .env: nada foi enviado de verdade.');
        console.log('=======================================================================');
        console.log('');

        return false;
    }

    try {
        await criarTransporte().sendMail({
            from: process.env.SMTP_FROM || process.env.SMTP_USER || 'Saúde em Dia <nao-responda@saudeemdia.app>',
            to: para,
            subject: assunto,
            text: texto
        });

        return true;

    } catch (e) {
        console.error('Falha ao enviar e-mail:', e.message);

        return false;
    }
}


module.exports = {
    smtpConfigurado,
    enviarEmail
};
