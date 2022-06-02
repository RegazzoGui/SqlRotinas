
/*
Informações da instância
Serviço ON a quanto tempo
Databases e Status
Consumo de CPU
Consumo de memória
Ultimos backups
Jobs que falharam
Erros Log (checkbd, acessos que falharam
*/

--CREATE OR ALTER PROC DBA_CHECKLIST as


DECLARE
	@HTML NVARCHAR(MAX) = '',
	@HTML2 NVARCHAR(MAX) = '',
	@HTML3 NVARCHAR(MAX) = '',
	@HTML4 NVARCHAR(MAX) = '',
	@HTML5 NVARCHAR(MAX) = '',
	@HTML6 NVARCHAR(MAX) = ''

SELECT @HTML = 
	'<HTML><BODY> <style type="text/css">
	<!--
	.style18 {color: #003399; font-wight: bold;font-size: 12px; font-family: Arial, Helvetica, sans-serif; }
	.style20 {color: #000099; font-wight: bold;font-size: 12px; font-family: Arial, Helvetica, sans-serif; }
	.style28 {color: #000066; font-wight: bold;font-size: 16px; font-family: Arial, Helvetica, sans-serif; }
	-->
	</style>'

-- ###################################################################
--INFORMAÇÕES DA INSTÂNCIA
SELECT @HTML = @HTML + N'<p class="style28> Instância </p> <TABLE>'
SELECT @HTML = @HTML + N'<table border ="1" class="style18" >'
+ N'<th> Data </th>'
+ N'<th> ComputerName </th>'
+ N'<th> InstanceName </th>'
+ N'<th> PortNumber </th>'
+ N'<th> Version </th>'
+ N'<th> Edition </th>'
+ N'<th> ProductLevel </th>'
+ N'<th> ProductVersion </th>'
+ CAST((SELECT td = CONVERT(VARCHAR, GETDATE(), 103),'',
td = SERVERPROPERTY('MachineName'), '',
td = SERVERPROPERTY('ServerName'), '',
td = isnull((SELECT TOP 1 local_tcp_port FROM sys.dm_exec_connections WHERE local_tcp_port IS NOT NULL ), 1433), '' ,
td = Case SERVERPROPERTY('ProductMajorVersion') 
	WHEN '10' THEN '2008' 
	WHEN '10.5' THEN '2008R2'
	WHEN '11' THEN '2012'
	WHEN '12' THEN '2014'
	WHEN '13' THEN '2016'
	WHEN '14' THEN '2017'
	WHEN '15' THEN '2019'
	WHEN '16' THEN '2022'
	END, '',
td = SERVERPROPERTY('Edition'), '' ,
td = SERVERPROPERTY('ProdctLevel'), '' ,
td = SERVERPROPERTY('ProductVersion')
FOR XML
PATH('tr'), TYPE) as NVARCHAR(MAX)) + N'</table><br><br>'


SELECT @HTML = @HTML + N'<p class="style28"> Instância ativa desde: '
+ CONVERT (VARCHAR, sqlserver_start_time, 103) +'. </p><br><br>' FROM sys.dm_os_sys_info

-- ###################################################################
-- Databases e status
SELECT @HTML = @HTML + N'<p class="style28"> Databases </p> <TABLE>'
SELECT @HTML = @HTML + N'<table border="1" class="style18">'
+ N'<th> Nome </th>'
+ N'<th> Status </th>'
+ CAST((SELECT 
			td = name, '',
			td = state_desc
		FROM sys.databases WHERE database_id > 4 order by name
FOR XML
PATH ('tr'), TYPE) AS NVARCHAR(MAX)) + N'</table><br><br>'


-- ###################################################################
-- Espaço em disco

--USE DBA
--GO

--CREATE TABLE DISCO (
--	ID INT IDENTITY(1, 1) PRIMARY KEY,
--	DATA DATETIME2(7),
--	DRIVE VARCHAR(1),
--	FREESPACE_MB INT,
--	TOTALSIZE_MB INT
--)
DECLARE 
	@obj INT,
	@fso INT,
	@drive char(1), 
	@odrive INT, 
	@TotalSize VARCHAR(20), 
	@MB BIGINT
SELECT @MB = 1048576

INSERT DBA..DISCO (DRIVE, FREESPACE_MB)
EXEC master.dbo.xp_fixeddrives

UPDATE DBA..DISCO SET DATA = GETDATE() WHERE DATA IS NULL

EXEC @obj = sp_OACreate 'Scripting.FileSystemObject', @fso OUT
	IF @obj <> 0
		BEGIN
			EXEC sp_OAGetErrorInfo @fso
		END

DECLARE dcur CURSOR LOCAL FAST_FORWARD FOR
SELECT DRIVE FROM DBA..DISCO WHERE DATA > (GETDATE()-1) ORDER BY DRIVE
OPEN dcur

FETCH NEXT FROM dcur INTO @drive
WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC @obj = sp_OAMethod @fso, 'GetDrive', @odrive OUT, @drive
		IF @obj <> 0
			BEGIN
				EXEC sp_OAGetErrorInfo @fso
			END
		EXEC @obj = sp_OAGetProperty @odrive, 'TotalSize', @TotalSize OUT
		IF @obj <> 0 
			BEGIN
				EXEC sp_OAGetErrorInfo @odrive
			END

		UPDATE DBA..DISCO
			SET TOTALSIZE_MB = @TotalSize / @MB
		WHERE drive = @drive AND DATA > (GETDATE() - 1)
	
		FETCH NEXT FROM dcur INTO @drive
	END
CLOSE dcur
DEALLOCATE DCUR
EXEC @obj = sp_OADestroy @fso
IF @obj <> 0
	BEGIN
		EXEC sp_OAGetErrorInfo @fso
	END
SELECT @HTML2 =  N'<p class="style28"> Espaço em disco </p> <TABLE>' 
SELECT @HTML2 = @HTML2 +  N'<table border="1" class="style18" >' 
+ N'<th> Drive </th>'
+ N'<th> Total Size </th>'
+ N'<th> FreeSpace </th>'
+ N'<th> MDF/LDF </th>'
+ N'<th> Backup </th>'
+ cast((SELECT td =  DRIVE, ''  ,
td = TOTALSIZE_MB, ''  ,
td = FREESPACE_MB, ''  ,
td = ISNULL((SELECT DISTINCT left (physical_name,1)  FROM sys.DATABASE_FILES 
			WHERE left (physical_name,1) = DRIVE ),'') , ''  ,
td = ISNULL((SELECT DISTINCT left (M.Physical_Device_Name,1)             
		FROM msdb.dbo.BackupSet S
		JOIN msdb.dbo.BackupMediaFamily M ON S.Media_Set_ID = M.Media_Set_ID
		WHERE S.Database_Name In (SELECT Name FROM Sys.Databases)
		--AND S.Backup_Start_Date > Convert(Char(10), (DateAdd(Day, - 2, GetDate())), 103)),'')
		AND S.Backup_Start_Date > GetDate() -2), '' )
FROM DBA..DISCO WHERE DATA > (GETDATE()-1)     
FOR XML  
PATH ('tr'), TYPE) AS NVARCHAR(MAX)) + N'</table><br><br>'  


-- ###################################################################
-- Consumo de CPU
SELECT @HTML3 =   N'<p class="style28"> Consumo CPU </p> <TABLE>' 
SELECT @HTML3 = @HTML3 +  N'<table border="1" class="style18" >' 
+ N'<th> Data </th>'
+ N'<th> % CPU SQL </th>'
+ N'<th> % CPU Geral </th>'
+ cast((SELECT TOP 10 td = CONVERT (varchar, EventDateTime, 126) , ''  ,     
td = cast(SysHealth.value('ProcessUtilization[1]','int') AS VARCHAR)+ '%', ''  ,  
td = cast(100 - SysHealth.value('SystemIdle[1]','int') AS VARCHAR) + '%'      
FROM (              
SELECT               
DATEADD(ms,               
(select [timestamp]-[ms_ticks] from sys.dm_os_sys_info),               
GETDATE())          AS 'EventDateTime',               
CAST(record AS xml)   AS 'record'              
FROM sys.dm_os_ring_buffers              
WHERE ring_buffer_type = 'RING_BUFFER_SCHEDULER_MONITOR'               
) ScheduleMonitorResults CROSS APPLY               
record.nodes('/Record/SchedulerMonitorEvent/SystemHealth') T(SysHealth)      
WHERE DATEPART(MINUTE,EventDateTime) IN (0,30)
--AND EventDateTime > (GETDATE()-1)
ORDER BY EventDateTime DESC   
FOR XML  
PATH ('tr'), TYPE) AS NVARCHAR(MAX)) + N'</table><br><br>'  


--##########################################################################
-- Consumo de memória
SELECT @HTML4 = @HTML4 +  N'<p class="style28"> Consumo de mem�ria:  ' +  
	   CAST(100 - cast((cast(available_physical_memory_kb AS DECIMAL) / 
	   cast(total_physical_memory_kb AS DECIMAL)) * 100 AS INT)AS VARCHAR)+ '% </p><br><br>'   
FROM sys.dm_os_sys_memory   

--##########################################################################
--Jobs que falharam

DECLARE @TMP_SP_HELP_JOBHISTORY TABLE                          
(                          
    INSTANCE_ID INT NULL,                           
    JOB_ID UNIQUEIDENTIFIER NULL,                           
    JOB_NAME SYSNAME NULL,                           
    STEP_ID INT NULL,                           
    STEP_NAME SYSNAME NULL,                           
    SQL_MESSAGE_ID INT NULL,                           
    SQL_SEVERITY INT NULL,                           
    MESSAGE NVARCHAR(4000) NULL,                           
    RUN_STATUS INT NULL,                           
    RUN_DATE INT NULL,                           
    RUN_TIME INT NULL,                           
    RUN_DURATION INT NULL,                           
    OPERATOR_EMAILED SYSNAME NULL,                           
    OPERATOR_NETSENT SYSNAME NULL,                           
    OPERATOR_PAGED SYSNAME NULL,                           
    RETRIES_ATTEMPTED INT NULL,                           
    SERVER SYSNAME NULL                            
)                          
                          
INSERT INTO @TMP_SP_HELP_JOBHISTORY                           
EXEC MSDB.DBO.SP_HELP_JOBHISTORY                           
       @MODE='FULL'                           
               
                              
SELECT @HTML5 =   N'<p class="style28"> Jobs com erro </p> <TABLE>' 
SELECT @HTML5 = @HTML5 +  N'<table border="1" class="style18" >' 
+ N'<th> JOB Name </th>'
+ N'<th> Erro </th>'
+ N'<th> Data </th>'
+ cast((SELECT  td = TSHJ.JOB_NAME  , ''  ,  
td =  LEFT(TSHJ.MESSAGE,200) , ''  ,                    
td = CASE TSHJ.RUN_DATE WHEN 0 THEN NULL ELSE                          
     CONVERT(DATETIME,                           
            STUFF(STUFF(CAST(TSHJ.RUN_DATE AS NCHAR(8)), 7, 0, '-'), 5, 0, '-') + N' ' +                           
            STUFF(STUFF(SUBSTRING(CAST(1000000 + TSHJ.RUN_TIME AS NCHAR(7)), 2, 6), 5, 0, ':'), 3, 0, ':'),                           
            120) END                         
FROM @TMP_SP_HELP_JOBHISTORY AS TSHJ                          
WHERE TSHJ.RUN_STATUS <> 1 AND                         
TSHJ.STEP_ID <> 0  AND (CASE TSHJ.RUN_DATE WHEN 0 THEN NULL ELSE                          
    CONVERT(DATETIME,                           
            STUFF(STUFF(CAST(TSHJ.RUN_DATE AS NCHAR(8)), 7, 0, '-'), 5, 0, '-') + N' ' +                           
            STUFF(STUFF(SUBSTRING(CAST(1000000 + TSHJ.RUN_TIME AS NCHAR(7)), 2, 6), 5, 0, ':'), 3, 0, ':'),                           
            120) END) > GETDATE()-1                        
ORDER BY TSHJ.STEP_NAME ASC     
FOR XML  
PATH ('tr'), TYPE) AS NVARCHAR(MAX)) + N'</table><br><br>'  

--##########################################################################
--Ultimos backups


SELECT @HTML5 = @HTML5 +   N'<p class="style28"> Últimos backups </p> <TABLE>' 
SELECT @HTML5 = @HTML5 +  N'<table border="1" class="style18" >' 
+ N'<th> Tipo </th>'
+ N'<th> Arquivo </th>'
+ N'<th> Tamanho (MB) </th>'
+ N'<th> Data </th>'
+ cast((SELECT  td =  CASE TYPE WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFF' ELSE 'LOG' END  , ''  , 
 td = physical_device_name  , ''  , 
 td = CAST(S.backup_size/1024.0/1024 AS DECIMAL(10, 2))   , ''  , 
 td = backup_start_date
FROM msdb.dbo.BackupSet S
JOIN msdb.dbo.BackupMediaFamily M ON S.Media_Set_ID = M.Media_Set_ID
WHERE S.Database_Name In (SELECT Name FROM Sys.Databases)
AND S.Backup_Start_Date > (GETDATE() - 2)
order by backup_start_date
FOR XML  
PATH ('tr'), TYPE) AS NVARCHAR(MAX)) + N'</table><br><br>'  


--##########################################################################
-- Errorlog

DECLARE @TMP_ERROR_LOG TABLE                      
(                      
ID INT IDENTITY (1,1),  
DATA DATETIME NULL,  
SOURCE VARCHAR(100) NULL,  
TEXTO VARCHAR(1000) NULL  
)  
  
INSERT INTO @TMP_ERROR_LOG  
EXEC sp_readerrorlog 0,1  
       

SELECT @HTML6 =  N'<p class="style28"> Errorlog </p> <TABLE>' 
SELECT @HTML6 = @HTML6 +  N'<table border="1" class="style18" >' 
+ N'<th> Data </th>'
+ N'<th> Mensagem </th>'
+ cast((SELECT  td = CAST(DATA AS SMALLDATETIME)  , ''  , 
    td = TEXTO  
 FROM @TMP_ERROR_LOG   
 WHERE (TEXTO LIKE '%LOGIN FAILED%'   OR TEXTO LIKE '%CHECKDB found%'  )
 AND CAST(DATA AS SMALLDATETIME) >= CAST(DATEADD(HOUR, -12, GETDATE()) AS SMALLDATETIME)  
 FOR XML  
PATH ('tr'), TYPE) AS NVARCHAR(MAX)) + N'</table></body></html>'  

--print @HTML6
--SELECT LEN(@HTML+@HTML2+@HTML3+@HTML4+@HTML5+@HTML6)

SELECT @HTML=@HTML+@HTML2+@HTML3+@HTML4+@HTML5+@HTML6

EXEC msdb.dbo.sp_send_dbmail         
@PROFILE_NAME = 'Informativo',
@recipients = 'aluisio.regazzo@escola.pr.gov.br',                           
@body = @HTML,                        
@body_format = 'HTML',                        
@subject = 'Check List'  
                        