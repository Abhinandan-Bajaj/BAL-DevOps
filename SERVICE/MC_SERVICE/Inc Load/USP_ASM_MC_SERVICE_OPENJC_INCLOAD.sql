SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Alter PROC [dbo].[USP_ASM_MC_SERVICE_OPENJC_INCLOAD] AS
BEGIN

/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-08-05 	|	Sarvesh Kulkarni		|New SP created to track the Open JC */
/*	2024-08-22 	|	Sarvesh Kulkarni		|Handled Cancelled JC with all the line item are deleted */
/*	2024-11-05 	|	Sarvesh Kulkarni		|Handled ASD Dealer Mapping */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

------------------------------------------------------------------------------------------------------------------

DECLARE @MAXDATESTG DATETIME2(7)= (SELECT MAX(IMPORTEDDATE) FROM ASM_MC_OPEN_JC_STG)

insert into ASM_MC_OPEN_JC_STG
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
 ,CASE WHEN SH.ISCLOSED=0 AND SH.READYFORINVDELAYREASON IS NULL THEN 'Reason not selected'
       WHEN SH.ISCLOSED=0 AND SH.READYFORINVDELAYREASON IS NOT NULL THEN READYFORINVDELAYREASON END AS ReasonForDelay
 ,0 AS Delete_Flag
 ,SH.Importeddate
 ,CM.CODE AS asd_Dealercode 
FROM SERVICE_HEADER SH
LEFT JOIN SERVICE_CONTRACT_MASTER SCM1 ON SCM1.SERVICECONTRACTID=SH.CONTRACTTYPEID
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (1,8))
LEFT JOIN CONTACT_MASTER CM1 ON CM1.CONTACTID=SH.SALESPERSONID AND CM1.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CM1.CONTACTID = CN1.CONTACTID)
LEFT JOIN CONTACT_MASTER CM2 ON CM2.CONTACTID=SH.MECHANICID AND CM2.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CM2.CONTACTID = CN1.CONTACTID)
WHERE SH.Importeddate  > @MAXDATESTG
AND CM.CODE NOT IN ('0000028428')
AND SH.IBID IS NOT NULL

Print('Data inserted into table ASM_MC_OPEN_JC_STG')
--------------------------------------------------------------------------------------------------------
SELECT * INTO #ServiceDealerMapping FROM
(SELECT DISTINCT ZF_ASC ASD_DEALERCODE,DEALER_CODE DEALERCODE
FROM SAP_ZSD_ASC_DETAIL
WHERE SER_STATUS = 'OPERATIONAL')T

UPDATE B
SET B.Dealercode=A.DEALERCODE
FROM ASM_MC_OPEN_JC_STG B
INNER JOIN #ServiceDealerMapping A ON B.ASD_DealerCode=A.ASD_DEALERCODE

Drop table #ServiceDealerMapping

Print('Updated Dealer ASD mapping')
-------------------------------------------------------------------------------------------------------
Print('Deleteing duplicate JC from table ASM_MC_OPEN_JC_STG')
;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY FK_DOCID ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_MC_OPEN_JC_STG              
)          
DELETE FROM CTE                  
WHERE RNK<>1;
--------------------------------------------------------------------------------------------------------
------------------------------UPDATE Cancellation date
print('Updating Cancellation date in ASM_MC_OPEN_JC_STG table')

Update ASF 
SET ASF.CANCELLATIONDATE=sh.CANCELLATIONDATE
,ASF.Isclosed=sh.Isclosed
,ASF.Billeddatetime=sh.Billeddatetime
FROM ASM_MC_OPEN_JC_STG ASF
LEFT JOIN SERVICE_HEADER SH ON sh.HEADERID = asf.FK_Docid
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (1,8))
WHERE SH.IMPORTEDDATE > DATEADD(Day,-2,@MAXDATESTG)
AND (SH.CANCELLATIONDATE IS NOT NULL
 OR SH.Isclosed=1
OR SH.Billeddatetime is NOT null)

print('Cancellation,Billeddate, isclosed columns updated in ASM_MC_OPEN_JC_STG table');;
---------------------------------------------------------------------------------------

Print('Deleteing closed JC from table ASM_MC_OPEN_JC_STG')
Delete from ASM_MC_OPEN_JC_STG where 
Isclosed=1
OR Billeddatetime is  not null
OR CANCELLATIONDATE is not null
--------------------------------------------------------------------------------------------------------
Print('Truncating table ASM_MC_OPEN_JC_FACT')
TRUNCATE TABLE ASM_MC_OPEN_JC_FACT

INSERT into ASM_MC_OPEN_JC_FACT 
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
 ,ReasonForDelay
 ,CASE WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))<=3 THEN '<3 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate())))) < 7 THEN '3-7 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate())))) < 15 THEN '7-15 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate())))) < 30 THEN '15-30 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate())))) < 60 THEN '30-60 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate())))) < 90 THEN '60-90 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate())))) < 120 THEN '90-120 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))>= 120 THEN '>= 120 Days' END AS OpenJC_Buckets_MC
from ASM_MC_OPEN_JC_STG
where  
Isclosed=0
and Billeddatetime is null
and CANCELLATIONDATE is null

Print('Data inserted into table ASM_MC_OPEN_JC_FACT')
END
GO
