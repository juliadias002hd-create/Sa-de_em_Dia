-- =====================================================================
-- SAÚDE EM DIA — DADOS DE TESTE
-- Execute depois do 01_schema.sql.
-- Pode rodar este arquivo mais de uma vez sem duplicar dados.
--
-- Usuário de teste:
--   E-mail: julia@teste.com
--   Senha:  Teste@123   (o hash abaixo já é essa senha, gerado com bcrypt)
-- =====================================================================

USE saude_em_dia;

-- ---------------------------------------------------------------------
-- Usuário de teste
-- ---------------------------------------------------------------------
INSERT INTO usuarios (nome, email, senha, telefone, data_nascimento, ativo)
VALUES (
    'Júlia Oliveira',
    'julia@teste.com',
    '$2b$12$8v.YZtdnrmtaDgBHIT0luuq7mYm.mBKJug.jgpH9N/2VzNNI2dHdO',
    '(11) 98888-7777',
    '1998-04-12',
    1
)
ON DUPLICATE KEY UPDATE
    nome = VALUES(nome),
    senha = VALUES(senha),
    telefone = VALUES(telefone),
    data_nascimento = VALUES(data_nascimento),
    ativo = VALUES(ativo);

-- ---------------------------------------------------------------------
-- Uma receita para esse usuário
-- ---------------------------------------------------------------------
INSERT INTO receitas (usuario_id, data_receita, medico, especialidade, arquivo_url, tipo_arquivo, nome_arquivo)
SELECT
    u.id,
    '2026-09-18',
    'Dr. João da Silva',
    'Clínico Geral',
    NULL,
    NULL,
    NULL
FROM usuarios u
WHERE u.email = 'julia@teste.com'
  AND NOT EXISTS (
        SELECT 1 FROM receitas r
        WHERE r.usuario_id = u.id
          AND r.medico = 'Dr. João da Silva'
          AND r.data_receita = '2026-09-18'
  );

-- ---------------------------------------------------------------------
-- Três medicamentos ligados a essa receita
-- ---------------------------------------------------------------------
INSERT INTO medicamentos (receita_id, nome, dosagem, intervalo_horas, horario_inicio, duracao_dias, observacoes, ativo)
SELECT r.id, dados.nome, dados.dosagem, dados.intervalo_horas, dados.horario_inicio, dados.duracao_dias, dados.observacoes, 1
FROM receitas r
JOIN usuarios u ON u.id = r.usuario_id
JOIN (
    SELECT 'Paracetamol' AS nome, '500 mg' AS dosagem, 8 AS intervalo_horas, '08:00:00' AS horario_inicio, 5 AS duracao_dias, 'Tomar após as refeições' AS observacoes
    UNION ALL
    SELECT 'Amoxicilina', '500 mg', 8, '08:00:00', 7, 'Tomar com bastante água'
    UNION ALL
    SELECT 'Ibuprofeno', '400 mg', 12, '09:00:00', 3, 'Tomar apenas se houver dor'
) AS dados
WHERE u.email = 'julia@teste.com'
  AND r.medico = 'Dr. João da Silva'
  AND r.data_receita = '2026-09-18'
  AND NOT EXISTS (
        SELECT 1 FROM medicamentos m
        WHERE m.receita_id = r.id
          AND m.nome = dados.nome
  );
