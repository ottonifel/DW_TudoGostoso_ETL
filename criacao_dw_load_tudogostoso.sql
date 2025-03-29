-- CRIAÇÃO DAS DIMENSÕES E TABELA FATO
CREATE TABLE dimensao_categoria (
    pk_receita SERIAL PRIMARY KEY,
    id_receita INT,
	nome VARCHAR(255),
    usuario VARCHAR(255),
    categoria VARCHAR(100) NOT NULL,
    subcategoria VARCHAR(100)
);

CREATE TABLE fato_relevancia_receita (
    pk_receita INTEGER NOT NULL REFERENCES public.dimensao_categoria (pk_receita),
    pk_dificuldade VARCHAR(50) NOT NULL,
    pk_custo VARCHAR(50) NOT NULL,
    media_avaliacoes DOUBLE PRECISION,
    quant_avaliacoes INTEGER,
    popularidade DOUBLE PRECISION,
    PRIMARY KEY (pk_receita, pk_custo, pk_dificuldade)
);

-- DW :: DBLINK
CREATE EXTENSION dblink;
SELECT current_user;
SELECT dblink_connect('myconn', 'dbname=Banco_receitas_auxiliar user=postgres password=labbd options=-csearch_path=');

-- PREENCHENDO DW

--PREENCHENDO DIMENSAO CATEGORIA:
INSERT INTO dimensao_categoria (id_receita, nome, usuario, categoria, subcategoria)
SELECT *
FROM dblink('dbname=Banco_receitas_auxiliar user=postgres password=labbd',
            'SELECT id,nome, autor, categoria, subcategoria
			 FROM receitas
			 ORDER BY categoria, subcategoria')
AS t1(id INT, nome TEXT, usuario TEXT, categoria TEXT, subcategoria TEXT);

select * from dimensao_categoria

-- criação de tabela temporária
CREATE TEMPORARY TABLE temp_fato_popularidade (
	id_receita INT,
	pk_receita INT,
	pk_dificuldade TEXT,
	pk_custo TEXT,
	nome TEXT,
	usuario TEXT,
	nota DOUBLE PRECISION,
	qtd_avaliacoes INT,
	categoria TEXT,
	subcategoria TEXT,
	tempo_preparo_min INT,
	dificuldade TEXT,
	custo TEXT,
	popularidade DOUBLE PRECISION
);

-- inserindo na tabela temporária (a partir do BD auxiliar) os dados a serem comparados depois com as dimensões (para pegar as PKs para depois passar para a tabela fato), além do cálculo das métricas (que vão ser passados depois para a tabela fato também)
INSERT INTO temp_fato_popularidade (id_receita, nome, usuario, nota, qtd_avaliacoes, categoria, subcategoria, tempo_preparo_min, dificuldade, custo, popularidade)
SELECT *
FROM dblink('dbname=Banco_receitas_auxiliar user=postgres password=labbd',
            'SELECT id, nome, autor, nota, numero_avaliacoes, categoria, subcategoria, tempo_preparo_min, dificuldade, custo, 
			 ((numero_avaliacoes / (numero_avaliacoes + 100.0)) * nota +(100.0 / (numero_avaliacoes + 100.0)) * (SELECT AVG(nota) FROM receitas)) AS popularidade
             FROM receitas')
AS t1(id INT, nome TEXT, autor TEXT, nota DOUBLE PRECISION, numero_avaliacoes INT, categoria TEXT, subcategoria TEXT, tempo_preparo_min INT, dificuldade TEXT, custo TEXT, popularidade DOUBLE PRECISION);

SELECT * FROM temp_fato_popularidade ORDER BY popularidade DESC

-- INSERÇÃO NA FATO
SELECT DISTINCT ON (t.id_receita) c.pk_receita, t.dificuldade, t.custo, t.nota, t.qtd_avaliacoes, t.popularidade
FROM temp_fato_popularidade t
JOIN dimensao_categoria c 
ON c.nome = t.nome 
AND c.usuario = t.usuario 
AND c.categoria = t.categoria 
AND c.subcategoria = t.subcategoria
AND c.id_receita = t.id_receita

INSERT INTO fato_relevancia_receita(pk_receita, pk_dificuldade, pk_custo, media_avaliacoes, quant_avaliacoes, popularidade)
SELECT DISTINCT ON (t.id_receita) c.pk_receita, t.dificuldade, t.custo, t.nota, t.qtd_avaliacoes, t.popularidade
FROM temp_fato_popularidade t
JOIN dimensao_categoria c 
ON c.nome = t.nome 
AND c.usuario = t.usuario 
AND c.categoria = t.categoria 
AND c.subcategoria = t.subcategoria
AND c.id_receita = t.id_receita;






