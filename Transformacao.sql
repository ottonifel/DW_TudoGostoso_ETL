SELECT * FROM receitas

SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conrelid = 'receitas'::regclass AND contype = 'c';

ALTER TABLE receitas DROP CONSTRAINT receitas_custo_check;

-- Normalização de strings para minúsculo
UPDATE receitas
SET nome = LOWER(nome),
autor = LOWER(autor),
categoria = LOWER(categoria),
subcategoria = LOWER(subcategoria),
numero_porcoes = LOWER(numero_porcoes),
tempo_preparo_min = LOWER(tempo_preparo_min),
dificuldade = LOWER(dificuldade),
custo = LOWER(custo);

-- String 'Nulo' para o valor NULL
UPDATE receitas
SET numero_porcoes = NULL
WHERE numero_porcoes = 'nulo';

-- Remove a palavra 'Custo' dos valores da coluna custo
UPDATE receitas
SET custo = REPLACE(custo, 'custo ', '');

-- Tratamento de valor nulo: Coluna custo
UPDATE receitas AS r
SET custo = moda.moda_custo
FROM (
      SELECT subcategoria, MODE() WITHIN GROUP (ORDER BY custo) AS moda_custo -- funciona pra string
      FROM receitas
      WHERE custo IS NOT NULL AND custo != 'nulo'
      GROUP BY subcategoria
    ) AS moda
WHERE r.subcategoria = moda.subcategoria AND r.custo = 'nulo';

UPDATE receitas SET custo = 'não especificado' WHERE custo = 'nulo'

-- TRATANDO numero_porcoes
UPDATE receitas
SET numero_porcoes = 'não especificado'
WHERE numero_porcoes IS NULL OR numero_porcoes = 'nulo';

-- TRATAR TEMPO_PREPARO_MIN (MODA dos outros da mesma categoria)
UPDATE receitas AS r
SET tempo_preparo_min = moda.moda_tempo_preparo
FROM (
      SELECT subcategoria, MODE() WITHIN GROUP (ORDER BY tempo_preparo_min) AS moda_tempo_preparo -- funciona pra string
      FROM receitas
      WHERE tempo_preparo_min IS NOT NULL AND tempo_preparo_min != 'nulo'
      GROUP BY subcategoria
    ) AS moda
WHERE r.subcategoria = moda.subcategoria AND r.tempo_preparo_min = 'nulo';

ALTER TABLE receitas 
ALTER COLUMN tempo_preparo_min TYPE INTEGER USING tempo_preparo_min::INTEGER;

ALTER TABLE receitas
ALTER COLUMN numero_avaliacoes TYPE INTEGER USING numero_avaliacoes::INTEGER;


-- TRATAMENTO DIFICULDADE (depois de tratar o tempo_preparo)
UPDATE receitas AS r
SET dificuldade = COALESCE(
    -- 1ª Tentativa: Moda dentro do intervalo de ±20 minutos
    (
        SELECT MODE() WITHIN GROUP (ORDER BY r2.dificuldade)
        FROM receitas AS r2
        WHERE r2.subcategoria = r.subcategoria   
        AND r2.dificuldade != 'nulo' AND dificuldade != 'não especificado'
        AND r2.tempo_preparo_min BETWEEN (r.tempo_preparo_min - 20) 
                                     AND (r.tempo_preparo_min + 20)
    ),
    -- 2ª Tentativa: Moda sem considerar o intervalo de tempo
    (
        SELECT MODE() WITHIN GROUP (ORDER BY r3.dificuldade)
        FROM receitas AS r3
        WHERE r3.categoria = r.categoria
        AND r3.subcategoria = r.subcategoria  
        AND r3.dificuldade != 'nulo' AND r3.dificuldade != 'não especificado'
    ),
    -- 3ª Opção: Se tudo falhar, definir como 'baixa'
    'não especificado'
)
WHERE r.dificuldade IS NULL OR r.dificuldade = 'nulo';

-- TESTES POPULARIDADE:
--

SELECT nome, categoria, subcategoria, nota, numero_avaliacoes, popularidade FROM
(SELECT nome,categoria,subcategoria,nota,numero_avaliacoes,
    (
        (numero_avaliacoes / (numero_avaliacoes + 100.0)) * nota +
        (100.0 / (numero_avaliacoes + 100.0)) * (SELECT AVG(nota) FROM receitas)
    ) AS popularidade
FROM receitas) AS t1
ORDER BY t1.popularidade DESC

SELECT (numero_avaliacoes) FROM receitas

SELECT 
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY numero_avaliacoes) AS Q1,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY numero_avaliacoes) AS Mediana,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY numero_avaliacoes) AS Q3,
    AVG(numero_avaliacoes) AS Media_Avaliacoes
FROM receitas;

-- Mediana (𝑄2): Indica um número típico de avaliações.
-- Q1 (1º quartil): 25% das receitas têm menos que esse número de avaliações.
-- Q3 (3º quartil): 75% das receitas têm menos que esse número de avaliações.
-- Com essa Análise escolheu-se adotar C = 100: a partir de que ponto (qtd avaliações) consideramos a nota confiável.

WITH Estatisticas AS (
    SELECT 
        categoria,
		subcategoria,
        AVG(nota) AS media_subcategoria,
        SUM(numero_avaliacoes) AS total_avaliacoes,
        (SELECT AVG(nota) FROM receitas) AS media_global -- Média geral das receitas
    FROM receitas
    GROUP BY categoria, subcategoria
)
SELECT 
    categoria,
	subcategoria,
    total_avaliacoes,
    media_subcategoria,
    ( (total_avaliacoes / (total_avaliacoes + 100.0)) * media_subcategoria ) + 
    ( (100.0 / (total_avaliacoes + 100.0)) * media_global ) AS popularidade_subcategoria
FROM Estatisticas
ORDER BY popularidade_subcategoria DESC;

-- teste:
SELECT nome, autor, categoria, subcategoria, nota, numero_avaliacoes, tempo_preparo_min, dificuldade, custo, COUNT(*)
FROM receitas
GROUP BY nome, autor, categoria, subcategoria, nota, numero_avaliacoes, tempo_preparo_min, dificuldade, custo
HAVING COUNT(*) > 1;
