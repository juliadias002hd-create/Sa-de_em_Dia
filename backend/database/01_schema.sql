-- =========================================================
-- BANCO DE DADOS - SAÚDE EM DIA
-- =========================================================

CREATE DATABASE IF NOT EXISTS saude_em_dia
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE saude_em_dia;


-- =========================================================
-- TABELA: USUARIOS
-- Apenas pacientes que utilizarão o aplicativo
-- =========================================================

CREATE TABLE usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,

    nome VARCHAR(150) NOT NULL,

    cpf VARCHAR(14) NOT NULL UNIQUE,

    email VARCHAR(150) NOT NULL UNIQUE,

    senha VARCHAR(255) NOT NULL,

    status ENUM('ativo', 'inativo', 'bloqueado')
        NOT NULL DEFAULT 'ativo',

    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP
);


-- =========================================================
-- TABELA: RECEITAS
-- Receitas cadastradas pelos pacientes
-- =========================================================

CREATE TABLE receitas (
    id INT AUTO_INCREMENT PRIMARY KEY,

    usuario_id INT NOT NULL,

    data_receita DATE NOT NULL,

    medico VARCHAR(150) NOT NULL,

    especialidade VARCHAR(100) NOT NULL,

    nome_arquivo VARCHAR(255),

    tipo_arquivo ENUM('imagem', 'pdf'),

    caminho_arquivo VARCHAR(500),

    observacoes TEXT,

    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_receita_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuarios(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


-- =========================================================
-- TABELA: MEDICAMENTOS
-- Medicamentos relacionados às receitas
-- =========================================================

CREATE TABLE medicamentos (
    id INT AUTO_INCREMENT PRIMARY KEY,

    usuario_id INT NOT NULL,

    receita_id INT NOT NULL,

    nome VARCHAR(150) NOT NULL,

    dosagem VARCHAR(100) NOT NULL,

    intervalo_horas INT NOT NULL,

    duracao_dias INT NOT NULL,

    horario_inicio TIME NOT NULL,

    observacoes TEXT,

    status ENUM('ativo', 'finalizado', 'pausado')
        NOT NULL DEFAULT 'ativo',

    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_medicamento_usuario
        FOREIGN KEY (usuario_id)
        REFERENCES usuarios(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_medicamento_receita
        FOREIGN KEY (receita_id)
        REFERENCES receitas(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


-- =========================================================
-- ÍNDICES
-- Melhoram a busca dos registros
-- =========================================================

CREATE INDEX idx_receitas_usuario
ON receitas(usuario_id);

CREATE INDEX idx_medicamentos_usuario
ON medicamentos(usuario_id);

CREATE INDEX idx_medicamentos_receita
ON medicamentos(receita_id);


-- =========================================================
-- VERIFICAÇÃO DAS TABELAS
-- =========================================================

SHOW TABLES;