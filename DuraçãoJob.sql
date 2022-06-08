SELECT sj.name,
   sh.run_date,
   sh.step_name,
   STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(sh.run_time as varchar(6)), 6), 3, 0, ':'), 6, 0, ':') 'run_time',
   CASE 
       WHEN sh.run_duration > 235959 THEN
   		   CAST((CAST(LEFT(CAST(sh.run_duration AS VARCHAR), LEN(CAST(sh.run_duration AS VARCHAR)) - 4) AS INT) / 24) AS VARCHAR)
   		   + '.' + RIGHT('00' + CAST(CAST(LEFT(CAST(sh.run_duration AS VARCHAR), LEN(CAST(sh.run_duration AS VARCHAR)) - 4) AS INT) % 24 AS VARCHAR), 2)
   		   + ':' + STUFF(CAST(RIGHT(CAST(sh.run_duration AS VARCHAR), 4) AS VARCHAR(6)), 3, 0, ':')
   		ELSE
   		   STUFF(STUFF(RIGHT(REPLICATE('0', 6) + CAST(sh.run_duration AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':')
   		END AS 'LastRunDuration (d.HH:MM:SS) '
   FROM msdb.dbo.sysjobs sj
JOIN msdb.dbo.sysjobhistory sh
   ON sj.job_id = sh.job_id;
GO