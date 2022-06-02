/*
 ROTINA DBA
 */
-- Verifica o modelo de backup dos bandos
SELECT
    name,
    recovery_model,
    recovery_model_desc
FROM
    sys.databases -- Backup Norma
    BACKUP DATABASE < NomeBanco > TO DISK = 'P:\BACKUP\CLIENTES_1_FULL.BAK' WITH STATS -- Demonstra o perceutla executado
    -- Recuperação normal
    RESTORE DATABASE CLIENTES
FROM
    DISK = 'P:\BACKUP\CLIENTES_1_FULL.BAK' WITH STATS,
    NORECOVERY -- Bloqueia a tabela para validações
    --Colocar Online
    RESTORE DATABASE CLIENTES WITH RECOVERY -- Fazendo novo backup com COMPRESS
    BACKUP DATABASE CLIENTES TO DISK = 'P:\BACKUP\CLIENTES_1_FULL.BAK' WITH COMPRESSION,
    STATS -- Backup Arquivos Log
    BACKUP LOG CLIENTES TO DISK = 'P:\BACKUP\CLIENTES_1_FULL.BAK' -- Bakcup DIFFERENTIAL
    BACK DATABASE CLIENTES TO DISK = 'P:\BACKUP\CLIENTES_1_FULL.BAK' WITH DIFFERENTIAL,
    STATS -- Back em vários arquivos
    BACKUP DATABASE CLIENTES TO DISK = 'P:\BACKUP\CLIENTES_MULTIFILL1_FULL.BAKK' DISK = 'P:\BACKUP\CLIENTES_MULTIFILL4_FULL.BAKK' DISK = 'P:\BACKUP\CLIENTES_MULTIFILL2_FULL.BAKK' DISK = 'P:\BACKUP\CLIENTES_MULTIFILL3_FULL.BAKK'
    /*
     IMPORTANTE 
     A declaração NORECOVERY deixa o banco offline WITH NORECOVERY Para alterar essa declaração 
     USE MASTER
     GO
     RESTORE DATABASE CLIENTES WITH RECOVERY
     */
    /*
     DESAFIOS REDUZIR CONSUMO DE ESPAÇO E NÚMERO DE LEITURA DE PÁGINAS  DE DADOS
     */
    -- CONFERIR TAMANHO DAS TABELAS
    EXEC sp_spaceused < nome tabela > -- HABILITAR CONTADORES DE LEITURAS DE PAGINAS
SET
    STATISTICS IO ON -- ESTIMAR COMPRESSÃO
    EXEC sp_stimate_data_compression_savings 'dbo',
    '<nometabela>',
    null,
    null,
    'ROW';

EXEC sp_stimate_data_compression_savings 'dbo',
'<nometabela>',
null,
null,
'PAGE';

-- COMPRESSÃO
ALTER TABLE
    < NomeTabela > REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = none) -- Análise de espaço livre em banco LDF e MDF
    USE PROVAPR
GO
SELECT
    [TYPE] = A.TYPE_DESC,
    [FILE_Name] = A.name,
    [FILEGROUP_NAME] = fg.name,
    [File_Location] = A.PHYSICAL_NAME,
    [FILESIZE_MB] = CONVERT(DECIMAL(10, 2), A.SIZE / 128.0),
    [USEDSPACE_MB] = CONVERT(
        DECIMAL(10, 2),
        A.SIZE / 128.0 - (
            (SIZE / 128.0) - CAST(FILEPROPERTY(A.NAME, 'SPACEUSED') AS INT) / 128.0
        )
    ),
    [FREESPACE_MB] = CONVERT(
        DECIMAL(10, 2),
        A.SIZE / 128.0 - CAST(FILEPROPERTY(A.NAME, 'SPACEUSED') AS INT) / 128.0
    ),
    [FREESPACE_%] = CONVERT(
        DECIMAL(10, 2),
        (
            (
                A.SIZE / 128.0 - CAST(FILEPROPERTY(A.NAME, 'SPACEUSED') AS INT) / 128.0
            ) /(A.SIZE / 128.0)
        ) * 100
    ),
    [AutoGrow] = 'By ' + CASE
        is_percent_growth
        WHEN 0 THEN CAST(growth / 128 AS VARCHAR(10)) + ' MB -'
        WHEN 1 THEN CAST(growth AS VARCHAR(10)) + '% -'
        ELSE ''
    END + CASE
        max_size
        WHEN 0 THEN 'DISABLED'
        WHEN -1 THEN ' Unrestricted'
        ELSE ' Restricted to ' + CAST(max_size /(128 * 1024) AS VARCHAR(10)) + ' GB'
    END + CASE
        is_percent_growth
        WHEN 1 THEN ' [autogrowth by percent, BAD setting!]'
        ELSE ''
    END
FROM
    sys.database_files A
    LEFT JOIN sys.filegroups fg ON A.data_space_id = fg.data_space_id
order by
    A.TYPE desc,
    A.NAME;

-- pARA INDENTIFICAR A FRAGMENTAÇÃO DOS INDICES DE UMA TABELA
SELECT
    *
FROM
    sys.dm_db_index_physical_stats (
        DB_ID(N'PROVAPR'),
        OBJECT_ID(N'dbo.IMAGE'),
        NULL,
        NULL,
        'DETAILED'
    );