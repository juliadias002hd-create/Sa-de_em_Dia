// Funções de validação reutilizadas pelos controllers.
// Cada função devolve true (válido) ou false (inválido).

const SENHA_MINIMA = 8;

// O bcrypt só considera os primeiros 72 bytes da senha.
const SENHA_MAXIMA = 72;


function ehTexto(valor) {
    return typeof valor === 'string';
}


function emailValido(email) {
    return (
        ehTexto(email) &&
        email.length <= 150 &&
        /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    );
}


// Aceita telefone com 10 ou 11 dígitos, com ou sem máscara.
// Exemplos: (11) 98888-7777, 11988887777, (11) 3888-7777
function telefoneValido(telefone) {
    if (!ehTexto(telefone)) {
        return false;
    }

    if (!/^[\d\s()+-]+$/.test(telefone)) {
        return false;
    }

    const digitos = telefone.replace(/\D/g, '');

    return digitos.length === 10 || digitos.length === 11;
}


// Data no formato AAAA-MM-DD, existente no calendário.
function dataValida(data) {
    if (!ehTexto(data) || !/^\d{4}-\d{2}-\d{2}$/.test(data)) {
        return false;
    }

    const [ano, mes, dia] = data.split('-').map(Number);

    const d = new Date(Date.UTC(ano, mes - 1, dia));

    return (
        d.getUTCFullYear() === ano &&
        d.getUTCMonth() === mes - 1 &&
        d.getUTCDate() === dia
    );
}


// Data de nascimento: válida, no passado e não absurdamente antiga.
function dataNascimentoValida(data) {
    if (!dataValida(data)) {
        return false;
    }

    const nascimento = new Date(`${data}T00:00:00Z`);
    const hoje = new Date();

    return nascimento < hoje && data >= '1900-01-01';
}


// Data da receita: válida, entre 2000 e hoje (não pode ser futura).
function dataReceitaValida(data) {
    if (!dataValida(data)) {
        return false;
    }

    const agora = new Date();

    const hoje = [
        agora.getFullYear(),
        String(agora.getMonth() + 1).padStart(2, '0'),
        String(agora.getDate()).padStart(2, '0')
    ].join('-');

    return data >= '2000-01-01' && data <= hoje;
}


// Id vindo da URL (/:id): só dígitos, dentro do limite do INT do MySQL.
function idValido(valor) {
    return (
        typeof valor === 'string' &&
        /^\d{1,10}$/.test(valor) &&
        Number(valor) > 0 &&
        Number(valor) <= 4294967295
    );
}


function senhaValida(senha) {
    return (
        ehTexto(senha) &&
        senha.length >= SENHA_MINIMA &&
        Buffer.byteLength(senha, 'utf8') <= SENHA_MAXIMA
    );
}


module.exports = {
    SENHA_MINIMA,
    SENHA_MAXIMA,
    ehTexto,
    emailValido,
    telefoneValido,
    dataValida,
    dataNascimentoValida,
    dataReceitaValida,
    idValido,
    senhaValida
};
