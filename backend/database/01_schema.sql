-- =====================================================================
-- SAÚDE EM DIA — SCRIPT DE CRIAÇÃO DO BANCO DE DADOS
-- =====================================================================

CREATE DATABASE IF NOT EXISTS saude_em_dia
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE saude_em_dia;

-- ---------------------------------------------------------------------
-- Tabela: usuarios
-- Representa os pacientes cadastrados no aplicativo.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuarios (
    id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nome             VARCHAR(150)    NOT NULL,
    email            VARCHAR(150)    NOT NULL,
    senha            VARCHAR(255)    NOT NULL,
    telefone         VARCHAR(20)     NULL,
    data_nascimento  DATE            NULL,
    ativo            TINYINT(1)      NOT NULL DEFAULT 1,
    criado_em        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_usuarios_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Tabela: receitas
-- Cada receita pertence a um paciente (usuario).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS receitas (
    id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario_id     INT UNSIGNED    NOT NULL,
    data_receita   DATE            NOT NULL,
    medico         VARCHAR(150)    NOT NULL,
    especialidade  VARCHAR(100)    NOT NULL,
    arquivo_url    VARCHAR(500)    NULL,
    tipo_arquivo   VARCHAR(20)     NULL,
    nome_arquivo   VARCHAR(255)    NULL,
    criado_em      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_receitas_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX idx_receitas_usuario (usuario_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Tabela: medicamentos
-- Cada medicamento pertence a uma receita.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS medicamentos (
    id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    receita_id       INT UNSIGNED    NOT NULL,
    nome             VARCHAR(150)    NOT NULL,
    dosagem          VARCHAR(50)     NOT NULL,
    intervalo_horas  INT UNSIGNED    NOT NULL,
    horario_inicio   TIME            NOT NULL,
    duracao_dias     INT UNSIGNED    NOT NULL,
    observacoes      VARCHAR(255)    NULL,
    ativo            TINYINT(1)      NOT NULL DEFAULT 1,
    criado_em        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_medicamentos_receita
        FOREIGN KEY (receita_id) REFERENCES receitas (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX idx_medicamentos_receita (receita_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Tabela: registros_doses
-- Cada linha é UMA dose que o paciente marcou como tomada.
-- Alimenta o Histórico e o status "Tomado" da tela inicial.
--
-- "A tomar" e "Atrasado" não são gravados: são calculados a partir do
-- horário do medicamento (uma dose sem registro cujo horário já passou
-- está "atrasada").
-- Ao excluir o medicamento, seus registros são excluídos junto (CASCADE).
-- O par (medicamento, horário previsto) é único: a mesma dose não pode
-- ser marcada duas vezes.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS registros_doses (
    id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medicamento_id    INT UNSIGNED    NOT NULL,
    horario_previsto  DATETIME        NOT NULL,
    horario_tomado    DATETIME        NOT NULL,
    status            VARCHAR(20)     NOT NULL DEFAULT 'tomado',
    criado_em         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_registros_medicamento
        FOREIGN KEY (medicamento_id) REFERENCES medicamentos (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    UNIQUE KEY uq_registros_dose (medicamento_id, horario_previsto),
    INDEX idx_registros_previsto (horario_previsto)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
