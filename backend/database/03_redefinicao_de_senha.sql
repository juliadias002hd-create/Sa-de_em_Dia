-- =====================================================================
-- SAÚDE EM DIA — REDEFINIÇÃO DE SENHA ("Esqueci minha senha")
-- Execute depois do 01_schema.sql. Pode rodar mais de uma vez.
--
-- 1) Tabela redefinicoes_senha: guarda o código de 6 dígitos enviado por
--    e-mail (apenas o "hash", nunca o código), a validade, o número de
--    tentativas e se já foi usado.
-- 2) Coluna usuarios.senha_alterada_em: quando a senha mudou. Logins feitos
--    ANTES dessa data deixam de valer (quem redefine a senha derruba as
--    sessões antigas, inclusive a de quem tivesse roubado a senha).
-- =====================================================================

USE saude_em_dia;

CREATE TABLE IF NOT EXISTS redefinicoes_senha (
    id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario_id    INT UNSIGNED    NOT NULL,
    codigo_hash   VARCHAR(255)    NOT NULL,
    expira_em     DATETIME        NOT NULL,
    tentativas    TINYINT UNSIGNED NOT NULL DEFAULT 0,
    usado_em      DATETIME        NULL,
    criado_em     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_redefinicoes_usuario
        FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX idx_redefinicoes_usuario (usuario_id, criado_em)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Adiciona a coluna só se ainda não existir (funciona no MySQL e no MariaDB).
SET @existe := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'usuarios'
      AND COLUMN_NAME = 'senha_alterada_em'
);

SET @comando := IF(
    @existe = 0,
    'ALTER TABLE usuarios ADD COLUMN senha_alterada_em DATETIME NULL',
    'SELECT ''coluna senha_alterada_em ja existe'' AS aviso'
);

PREPARE instrucao FROM @comando;
EXECUTE instrucao;
DEALLOCATE PREPARE instrucao;
