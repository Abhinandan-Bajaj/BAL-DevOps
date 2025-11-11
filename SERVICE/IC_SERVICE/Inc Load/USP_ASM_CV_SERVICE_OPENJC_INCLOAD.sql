SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_CV_SERVICE_OPENJC_INCLOAD] AS
BEGIN

/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-08-09 	|	Sarvesh Kulkarni		|New SP created to track the Open JC */
/*	2024-08-09 	|	Sarvesh Kulkarni		|Handled cancelled JC with all the line items are deleted */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

DECLARE @MAXDATESTG DATETIME2(7)= (SELECT MAX(IMPORTEDDATE) FROM ASM_CV_OPEN_JC_STG)

insert into ASM_CV_OPEN_JC_STG
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
 ,0 AS Delete_Flag
 ,SH.Importeddate
FROM SERVICE_HEADER SH
LEFT JOIN SERVICE_CONTRACT_MASTER SCM1 ON SCM1.SERVICECONTRACTID=SH.CONTRACTTYPEID
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (7))
LEFT JOIN CONTACT_MASTER CM1 ON CM1.CONTACTID=SH.SALESPERSONID AND CM1.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CM1.CONTACTID = CN1.CONTACTID)
LEFT JOIN CONTACT_MASTER CM2 ON CM2.CONTACTID=SH.MECHANICID AND CM2.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CM2.CONTACTID = CN1.CONTACTID)
WHERE SH.IMPORTEDDATE > @MAXDATESTG
AND SH.IBID IS NOT NULL
Print('Data inserted into table ASM_CV_OPEN_JC_STG')
--------------------------------------------------------------------------------------------------------------------------------

;;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY FK_DOCID ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_CV_OPEN_JC_STG              
)          
DELETE FROM CTE                  
WHERE RNK<>1;
--------------------------------------------------------------------------------------------------------------------------------
Update ASF 
SET ASF.CANCELLATIONDATE=sh.CANCELLATIONDATE
,ASF.Isclosed=sh.Isclosed
,ASF.Billeddatetime=sh.Billeddatetime
FROM ASM_CV_OPEN_JC_STG ASF
LEFT JOIN SERVICE_HEADER SH ON sh.HEADERID = asf.FK_Docid
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (7))
WHERE SH.IMPORTEDDATE > DATEADD(Day,-2,@MAXDATESTG)
AND (SH.CANCELLATIONDATE IS NOT NULL
 OR SH.Isclosed=1
OR SH.Billeddatetime is NOT null)

print('Cancellationdate,Billeddate, isclosed columns updated updated in ASM_CV_SERVICE_STG table');;

--------------------------------------------------------------------------------------------------------------------------------

Delete from ASM_CV_OPEN_JC_STG where 
Isclosed=1
OR Billeddatetime is  not null
OR CANCELLATIONDATE is not null

--------------------------------------------------------------------------------------------------------------------------------

TRUNCATE table ASM_CV_OPEN_JC_FACT
Print('Truncating table ASM_CV_OPEN_JC_FACT')
INSERT INTO ASM_CV_OPEN_JC_FACT 

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
 ,CASE WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))>=1 AND DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))<2 THEN '1-2days'
      WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))>=2 AND DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))<3 THEN '2-3days'
      WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))>=3 AND DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))<5 THEN '3-5days'    
      WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))>=5 AND DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))<7 THEN '5-7days'
      WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))>=7 AND DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))<10 THEN '7-10days'
      WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))>=10 AND DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))<15 THEN '10-15days'    
      WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))>=15 AND DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))<20 THEN '15-20days'  
      WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))>=20 AND DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))<30 THEN '20-30days'
      WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),DATEADD(mi,30,(DATEADD(hh,5,getdate()))))>=30 THEN '>30' END AS OpenJC_Buckets_CV
  
from ASM_CV_OPEN_JC_STG
where  
Isclosed=0
and Billeddatetime is null
and CANCELLATIONDATE is null

Print('Data inserted into table ASM_CV_OPEN_JC_FACT')
END

GO
