SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_PB_SERVICE_OPENJC_INCLOAD] AS
BEGIN

/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-08-05 	|	Sarvesh Kulkarni		|New SP created to track the Open JC */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

------------------------------------------------------------------------------------------------------------------

DECLARE @MAXDATESTG DATETIME2(7)= (SELECT MAX(IMPORTEDDATE) FROM ASM_PB_OPEN_JC_STG)

insert into ASM_PB_OPEN_JC_STG
SELECT DISTINCT 
 SH.HEADERID AS [FK_Docid]
 ,SH.DOCNAME
 ,CAST(SH.Docdate AS DATE) AS Docdate
 ,SH.COMPANYID AS [FK_Companyid]
 ,SH.CONTACTID AS FK_Contactid
 ,SH.CONTRACTTYPEID AS [FK_Contracttypeid]
 ,SH.Isclosed
 ,SH.IBID AS [FK_Ibid]
 ,SH.BRANCHID AS [FK_Branchid]
 ,SH.MODELID AS [FK_Modelid]
 ,SH.BU
 ,CM.COMPANYTYPE
 ,SCM1.NAME AS ServiceType
 ,CM.CODE AS DealerCode
 ,CAST(SH.Billeddatetime AS DATE) AS Billeddatetime
 ,CAST(SH.CANCELLATIONDATE AS DATE) AS CANCELLATIONDATE
 ,CM1.NAME AS ServiceAdvisor
 ,CM2.NAME AS Technician
 ,ext.ReadyForInvDelayReason
 ,ext.ReadyForInvDelayReasonOther
 ,0 AS Delete_Flag
 ,SH.Importeddate
FROM SERVICE_HEADER SH
INNER JOIN SERVICE_CONTRACT_MASTER SCM1 ON SCM1.SERVICECONTRACTID=SH.CONTRACTTYPEID
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (2))
LEFT join SERVICE_HEADER_EXT ext on sh.headerid=ext.headerid 
LEFT JOIN CONTACT_MASTER CM1 ON CM1.CONTACTID=SH.SALESPERSONID AND CM1.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CM1.CONTACTID = CN1.CONTACTID)
LEFT JOIN CONTACT_MASTER CM2 ON CM2.CONTACTID=SH.MECHANICID AND CM2.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CM2.CONTACTID = CN1.CONTACTID)
WHERE CAST(SH.DOCDATE AS DATE) > @MAXDATESTG
AND SH.IBID IS NOT NULL

Print('Data inserted into table ASM_PB_OPEN_JC_STG')
--------------------------------------------------------------------------------------------------------
;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY FK_DOCID ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_PB_OPEN_JC_STG              
)          
DELETE FROM CTE                  
WHERE RNK<>1;
--------------------------------------------------------------------------------------------------------
Delete from ASM_PB_OPEN_JC_STG where 
Isclosed=1
and Billeddatetime is  not null
and CANCELLATIONDATE is not null
--------------------------------------------------------------------------------------------------------
TRUNCATE TABLE ASM_PB_OPEN_JC_FACT
Print('Truncating table ASM_PB_OPEN_JC_FACT')
INSERT INTO ASM_PB_OPEN_JC_FACT 
select  
FK_Docid
 ,DOCNAME
 ,Docdate
 ,FK_Companyid
 ,FK_Contactid
 ,FK_Contracttypeid
 ,Isclosed
 ,FK_Ibid
 ,FK_Branchid
 ,FK_Modelid
 ,BU
 ,COMPANYTYPE
 ,ServiceType
 ,DealerCode
 ,ServiceAdvisor
 ,Technician
 ,ReadyForInvDelayReason
 ,ReadyForInvDelayReasonOther
 ,CASE WHEN DATEDIFF(HH,CAST(DOCDATE AS DATE),GETDATE())<=24 THEN '<24 Hours'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 3 THEN '< 3 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 7 THEN '3-7 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 15 THEN  '7-15 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 30 THEN  '15-30 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 60 THEN  '30 - 60 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 90 THEN  '60 - 90 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) >= 90 THEN  '>= 90 Days' END AS OpenJC_Buckets_MC
from ASM_PB_OPEN_JC_STG
where  
Isclosed=0
and Billeddatetime is null
and CANCELLATIONDATE is null
 and Delete_Flag=0

Print('Data inserted into table ASM_PB_OPEN_JC_FACT')
END
GO