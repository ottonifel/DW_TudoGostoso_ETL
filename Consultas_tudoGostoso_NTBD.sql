--CONSULTA 1:
-- Qual subcategoria com dificuldade Y e custo Z com mais receitas unitárias
SELECT categoria, subcategoria, COUNT(*) as qtd_receitas
FROM fato_relevancia_receita f JOIN dimensao_categoria d ON d.pk_receita = f.pk_receita
WHERE pk_dificuldade LIKE 'fácil' AND pk_custo LIKE 'baixo'
GROUP BY categoria, subcategoria
HAVING COUNT(*) IN (SELECT max(qtd_receitas) AS maximo_receitas
					FROM (SELECT categoria, subcategoria, COUNT(*) as qtd_receitas
						  FROM fato_relevancia_receita f JOIN dimensao_categoria d ON d.pk_receita = f.pk_receita
						  WHERE pk_dificuldade LIKE 'fácil' AND pk_custo LIKE 'baixo'
						  GROUP BY categoria, subcategoria) as t1)

-- VARIAÇÃO PARA VISUALIZAÇÃO NO POWER BI
SELECT categoria, subcategoria, COUNT(*) as qtd_receitas
FROM fato_relevancia_receita f JOIN dimensao_categoria d ON d.pk_receita = f.pk_receita
WHERE pk_dificuldade LIKE 'fácil' AND pk_custo LIKE 'baixo'
GROUP BY categoria, subcategoria
ORDER BY qtd_receitas DESC

-- CONSULTA 2:
-- Dada 2 categorias comparar o nível de dificuldade dela
SELECT categoria, COALESCE(
           					(SELECT MODE() WITHIN GROUP (ORDER BY pk_dificuldade)
            				 FROM fato_relevancia_receita f2 
            				 JOIN dimensao_categoria d2 ON d2.pk_receita = f2.pk_receita
            				 WHERE f2.pk_dificuldade != 'não especificado' 
              				 AND d2.categoria = d.categoria),
           					 'não especificado') AS dificuldade_mais_comum
FROM dimensao_categoria d
WHERE categoria IN ('aves', 'carnes')
GROUP BY categoria;

-- VARIAÇÃO PARA VISUALIZAÇÃO NO POWER BI
SELECT categoria, COALESCE(
           					(SELECT MODE() WITHIN GROUP (ORDER BY pk_dificuldade)
            				 FROM fato_relevancia_receita f2 
            				 JOIN dimensao_categoria d2 ON d2.pk_receita = f2.pk_receita
            				 WHERE f2.pk_dificuldade != 'não especificado' 
              				 AND d2.categoria = d.categoria),
           					 'não especificado') AS dificuldade_mais_comum
FROM dimensao_categoria d
GROUP BY categoria;


--CONSULTA 3:
-- Qual o ranking de subcategorias mais populares?
WITH Estatisticas AS (
    SELECT 
        subcategoria, 
        SUM(media_avaliacoes * quant_avaliacoes) / SUM(quant_avaliacoes) AS media_subcategoria, 
        SUM(quant_avaliacoes) AS total_avaliacoes,
        (SELECT SUM(media_avaliacoes * quant_avaliacoes) / SUM(quant_avaliacoes) FROM fato_relevancia_receita) AS media_global
    FROM fato_relevancia_receita f 
    JOIN dimensao_categoria d ON d.pk_receita = f.pk_receita
    GROUP BY categoria, subcategoria
)
SELECT 
    subcategoria, 
    total_avaliacoes, 
    media_subcategoria,
    ( (total_avaliacoes / (total_avaliacoes + 100.0)) * media_subcategoria ) +
    ( (100.0 / (total_avaliacoes + 100.0)) * media_global ) AS popularidade_subcategoria
FROM Estatisticas
ORDER BY popularidade_subcategoria DESC;

-- OBS: Ranking das categorias mais populares
WITH Estatisticas AS (
    SELECT 
        categoria, 
        SUM(media_avaliacoes * quant_avaliacoes) / SUM(quant_avaliacoes) AS media_categoria, 
        SUM(quant_avaliacoes) AS total_avaliacoes,
        (SELECT SUM(media_avaliacoes * quant_avaliacoes) / SUM(quant_avaliacoes) FROM fato_relevancia_receita) AS media_global
    FROM fato_relevancia_receita f 
    JOIN dimensao_categoria d ON d.pk_receita = f.pk_receita
    GROUP BY categoria
)
SELECT 
    categoria, 
    total_avaliacoes, 
    media_categoria,
    ( (total_avaliacoes / (total_avaliacoes + 100.0)) * media_categoria ) +
    ( (100.0 / (total_avaliacoes + 100.0)) * media_global ) AS popularidade_categoria
FROM Estatisticas
ORDER BY popularidade_categoria DESC;



