/****** Object:  StoredProcedure [dbo].[USP_ASM_CV_SERVICE_RETAIL_FULLLOAD]    Script Date: 19-02-2024 11:03:38 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_CV_SERVICE_RETAIL_INCLOAD] AS
BEGIN

DECLARE @MAXDATESTG DATETIME2(7)= (SELECT MAX(IMPORTEDDATE) FROM ASM_CV_SERVICE_RETAIL_STG)

INSERT INTO [dbo].[ASM_CV_SERVICE_RETAIL_STG]
--Extracting raw data from source tables and adding Due Dates and Expiry Dates for FSR
SELECT DISTINCT
 RH.HEADERID AS [FK_Docid]
 ,RH.DOCNAME
 ,CAST(RH.DOCDATE AS DATE) as Docdate
 ,RH.COMPANYID AS [FK_Companyid]
 ,RL.LINEID AS Lineid
 ,RH.CONTACTID AS FK_Contactid
 ,RL.IBID AS [FK_Ibid]
 ,RH.BRANCHID AS [FK_Branchid]
 ,RL.ITEMID AS [FK_Modelid]
 ,RH.BU
 ,CM.COMPANYTYPE
 ,CM.CODE AS Dealercode
 ,(CASE WHEN ISNULL(RETAIL_HEADER_EXT.IsInstitutionalSale,0) = 1 AND RH.DocType NOT IN (441,1000088) THEN 'Institutional' 
       WHEN ISNULL(RETAIL_HEADER_EXT.IsInstitutionalSale,0) = 0 
            AND Len(BM.Code) = 10 
            AND SUBSTRING(BM.Code,0,6) = '00000' 
            AND ((SUBSTRING(BM.Code,6,6) BETWEEN '10000' AND '14000') 
            OR (SUBSTRING(BM.Code,6,6) = '25669'))  
            AND RH.DocType NOT IN (441,1000088) THEN 'Showroom'
      ELSE 'Command Area' 
    END) AS SALESCHANNEL
 ,DATEADD(DAY,30,cast(RH.Docdate as date)) AS [1stFS_EXPIRY1_Date]
 ,DATEADD(DAY,75,cast(RH.Docdate as date)) AS [2ndFS_EXPIRY1_Date]
 ,DATEADD(DAY,120,cast(RH.Docdate as date))AS [3rdFS_EXPIRY1_Date]
 ,DATEADD(DAY,165,cast(RH.Docdate as date)) AS [4thFS_EXPIRY1_Date]
 ,DATEADD(DAY,210,cast(RH.Docdate as date)) AS [5thFS_EXPIRY1_Date]
 ,DATEADD(DAY,255,cast(RH.Docdate as date))AS [6thFS_EXPIRY1_Date]
 ,DATEADD(DAY,300,cast(RH.Docdate as date))AS [7thFS_EXPIRY1_Date]
 ,DATEADD(DAY,60,cast(RH.Docdate as date)) AS [1stFS_EXPIRY2_Date]
 ,DATEADD(DAY,90,cast(RH.Docdate as date)) AS [2ndFS_EXPIRY2_Date]
 ,DATEADD(DAY,135,cast(RH.Docdate as date)) AS [3rdFS_EXPIRY2_Date]
 ,DATEADD(DAY,180,cast(RH.Docdate as date)) AS [4thFS_EXPIRY2_Date]
 ,DATEADD(DAY,225,cast(RH.Docdate as date)) AS [5thFS_EXPIRY2_Date]
 ,DATEADD(DAY,270,cast(RH.Docdate as date)) AS [6thFS_EXPIRY2_Date]
 ,DATEADD(DAY,315,cast(RH.Docdate as date)) AS [7thFS_EXPIRY2_Date]  
 ,'NR' AS Return_Flag
 ,CAST(NULL AS DATE) AS FS_SERVICE_DATE
 ,CAST(NULL AS DATE) AS SS_SERVICE_DATE
 ,CAST(NULL AS DATE) AS TS_SERVICE_DATE
 ,CAST(NULL AS DATE) AS FS4_SERVICE_DATE
 ,CAST(NULL AS DATE) AS FS5_SERVICE_DATE
 ,CAST(NULL AS DATE) AS FS6_SERVICE_DATE
 ,CAST(NULL AS DATE) AS FS7_SERVICE_DATE
 ,NULL AS FS_COMPANYID
 ,NULL AS SS_COMPANYID
 ,NULL AS TS_COMPANYID
 ,NULL AS FS4_COMPANYID
 ,NULL AS FS5_COMPANYID
 ,NULL AS FS6_COMPANYID
 ,NULL AS FS7_COMPANYID
 ,RH.Importeddate       
 ,102 AS Service_Retail_TypeIdentifier
 ,GETDATE() AS Refresh_Date
FROM RETAIL_HEADER RH
LEFT JOIN RETAIL_LINE RL ON RH.HEADERID=RL.DOCID
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=RH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (7))
INNER JOIN BRANCH_MASTER BM ON RH.BRANCHID=BM.BRANCHID
LEFT OUTER JOIN RETAIL_HEADER_EXT ON RH.HEADERID=RETAIL_HEADER_EXT.HEADERID
WHERE RH.IMPORTEDDATE> @MAXDATESTG
AND RL.IBID IS NOT NULL
AND RH.DOCTYPE IN (141,441,1000079,1000317)

Delete from ASM_CV_SERVICE_RETAIL_STG Where DOCDATE>Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate()))) - 1 as date);
---------------------------------------DEDUP

;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY FK_DOCID ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_CV_SERVICE_RETAIL_STG              
)          
DELETE FROM CTE                  
WHERE RNK<>1;


------------------------------UPDATING RETURN FLAG

SELECT RL.SALEINVOICELINEID,RL.SERIALNO INTO #ReturnData_CV
FROM 
RETAIL_LINE_RETURN RL INNER JOIN ASM_CV_SERVICE_RETAIL_STG RD ON RD.LINEID=RL.SALEINVOICELINEID
 
--Return Data Flag Updation
UPDATE RD
SET RD.Return_Flag='R'
FROM ASM_CV_SERVICE_RETAIL_STG RD INNER JOIN #ReturnData_CV RL ON RL.SALEINVOICELINEID=RD.LINEID

------------------------------UPDATING FIRST FREE SERVICE DATE

SELECT SH.IBID
,CAST(SH.DOCDATE AS DATE) AS FS_SERVICE_DATE
,SH.COMPANYID AS FS_COMPANYID
INTO #FIRST_FS_DATA
FROM SERVICE_HEADER SH
JOIN COMPANY_MASTER CM ON (CM.COMPANYID = SH.COMPANYID AND CM.COMPANYTYPE = 7)
JOIN ASM_CV_SERVICE_RETAIL_STG RS ON RS.FK_IBID=SH.IBID
WHERE SH.CONTRACTTYPEID IN (48,174)
AND SH.CANCELLATIONDATE IS NULL
AND RS.RETURN_FLAG='NR'

UPDATE B
SET B.FS_SERVICE_DATE=A.FS_SERVICE_DATE
,B.FS_COMPANYID=A.FS_COMPANYID
FROM ASM_CV_SERVICE_RETAIL_STG B
JOIN #FIRST_FS_DATA A ON A.IBID=B.FK_IBID
WHERE B.FS_SERVICE_DATE IS NULL

------------------------------UPDATING SECOND FREE SERVICE DATE

SELECT SH.IBID
,CAST(SH.DOCDATE AS DATE) AS SS_SERVICE_DATE
,SH.COMPANYID AS SS_COMPANYID
INTO #SECOND_FS_DATA
FROM SERVICE_HEADER SH
JOIN COMPANY_MASTER CM ON (CM.COMPANYID = SH.COMPANYID AND CM.COMPANYTYPE = 7)
JOIN ASM_CV_SERVICE_RETAIL_STG RS ON RS.FK_IBID=SH.IBID
WHERE SH.CONTRACTTYPEID IN (190,175)
AND SH.CANCELLATIONDATE IS NULL
AND RS.RETURN_FLAG='NR'

UPDATE B
SET B.SS_SERVICE_DATE=A.SS_SERVICE_DATE
,B.SS_COMPANYID=A.SS_COMPANYID
FROM ASM_CV_SERVICE_RETAIL_STG B
JOIN #SECOND_FS_DATA A ON A.IBID=B.FK_IBID
WHERE B.SS_SERVICE_DATE IS NULL

------------------------------UPDATING THIRD FREE SERVICE DATE

SELECT SH.IBID
,CAST(SH.DOCDATE AS DATE) AS TS_SERVICE_DATE
,SH.COMPANYID AS TS_COMPANYID
INTO #THIRD_FS_DATA
FROM SERVICE_HEADER SH
JOIN COMPANY_MASTER CM ON (CM.COMPANYID = SH.COMPANYID AND CM.COMPANYTYPE = 7)
JOIN ASM_CV_SERVICE_RETAIL_STG RS ON RS.FK_IBID=SH.IBID
WHERE SH.CONTRACTTYPEID IN (191,176)
AND SH.CANCELLATIONDATE IS NULL
AND RS.RETURN_FLAG='NR'

UPDATE B
SET B.TS_SERVICE_DATE=A.TS_SERVICE_DATE
,B.TS_COMPANYID=A.TS_COMPANYID
FROM ASM_CV_SERVICE_RETAIL_STG B
JOIN #THIRD_FS_DATA A ON A.IBID=B.FK_IBID
WHERE B.TS_SERVICE_DATE IS NULL


------------------------------UPDATING FOURTH FREE SERVICE DATE

SELECT SH.IBID
,CAST(SH.DOCDATE AS DATE) AS FS4_SERVICE_DATE
,SH.COMPANYID AS FS4_COMPANYID
INTO #FOURTH_FS_DATA
FROM SERVICE_HEADER SH
JOIN COMPANY_MASTER CM ON (CM.COMPANYID = SH.COMPANYID AND CM.COMPANYTYPE = 7)
JOIN ASM_CV_SERVICE_RETAIL_STG RS ON RS.FK_IBID=SH.IBID
WHERE SH.CONTRACTTYPEID IN (210)
AND SH.CANCELLATIONDATE IS NULL
AND RS.RETURN_FLAG='NR'

UPDATE B
SET B.FS4_SERVICE_DATE=A.FS4_SERVICE_DATE
,B.FS4_COMPANYID=A.FS4_COMPANYID
FROM ASM_CV_SERVICE_RETAIL_STG B
JOIN #FOURTH_FS_DATA A ON A.IBID=B.FK_IBID
WHERE B.FS4_SERVICE_DATE IS NULL

------------------------------UPDATING FIFTH FREE SERVICE DATE

SELECT SH.IBID
,CAST(SH.DOCDATE AS DATE) AS FS5_SERVICE_DATE
,SH.COMPANYID AS FS5_COMPANYID
INTO #FIFTH_FS_DATA
FROM SERVICE_HEADER SH
JOIN COMPANY_MASTER CM ON (CM.COMPANYID = SH.COMPANYID AND CM.COMPANYTYPE = 7)
JOIN ASM_CV_SERVICE_RETAIL_STG RS ON RS.FK_IBID=SH.IBID
WHERE SH.CONTRACTTYPEID IN (211)
AND SH.CANCELLATIONDATE IS NULL
AND RS.RETURN_FLAG='NR'

UPDATE B
SET B.FS5_SERVICE_DATE=A.FS5_SERVICE_DATE
,B.FS5_COMPANYID=A.FS5_COMPANYID
FROM ASM_CV_SERVICE_RETAIL_STG B
JOIN #FIFTH_FS_DATA A ON A.IBID=B.FK_IBID
WHERE B.FS5_SERVICE_DATE IS NULL

------------------------------UPDATING SIXTH FREE SERVICE DATE

SELECT SH.IBID
,CAST(SH.DOCDATE AS DATE) AS FS6_SERVICE_DATE
,SH.COMPANYID AS FS6_COMPANYID
INTO #SIXTH_FS_DATA
FROM SERVICE_HEADER SH
JOIN COMPANY_MASTER CM ON (CM.COMPANYID = SH.COMPANYID AND CM.COMPANYTYPE = 7)
JOIN ASM_CV_SERVICE_RETAIL_STG RS ON RS.FK_IBID=SH.IBID
WHERE SH.CONTRACTTYPEID IN (212)
AND SH.CANCELLATIONDATE IS NULL
AND RS.RETURN_FLAG='NR'

UPDATE B
SET B.FS6_SERVICE_DATE=A.FS6_SERVICE_DATE
,B.FS6_COMPANYID=A.FS6_COMPANYID
FROM ASM_CV_SERVICE_RETAIL_STG B
JOIN #SIXTH_FS_DATA A ON A.IBID=B.FK_IBID
WHERE B.FS6_SERVICE_DATE IS NULL

------------------------------UPDATING SEVENTH FREE SERVICE DATE

SELECT SH.IBID
,CAST(SH.DOCDATE AS DATE) AS FS7_SERVICE_DATE
,SH.COMPANYID AS FS7_COMPANYID
INTO #SEVENTH_FS_DATA
FROM SERVICE_HEADER SH
JOIN COMPANY_MASTER CM ON (CM.COMPANYID = SH.COMPANYID AND CM.COMPANYTYPE = 7)
JOIN ASM_CV_SERVICE_RETAIL_STG RS ON RS.FK_IBID=SH.IBID
WHERE SH.CONTRACTTYPEID IN (213)
AND SH.CANCELLATIONDATE IS NULL
AND RS.RETURN_FLAG='NR'

UPDATE B
SET B.FS7_SERVICE_DATE=A.FS7_SERVICE_DATE
,B.FS7_COMPANYID=A.FS7_COMPANYID
FROM ASM_CV_SERVICE_RETAIL_STG B
JOIN #SEVENTH_FS_DATA A ON A.IBID=B.FK_IBID
WHERE B.FS7_SERVICE_DATE IS NULL

------------------------------RETAIL FLAGS AND UPDATES
TRUNCATE TABLE [dbo].[ASM_CV_RETAIL_FLAGS]

INSERT INTO ASM_CV_RETAIL_FLAGS

SELECT ARS.*
,CASE WHEN CAST(ARS.FS_SERVICE_DATE AS DATE)<=CAST([1stFS_EXPIRY1_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_1stFS_EXPIRY1
,CASE WHEN CAST(ARS.SS_SERVICE_DATE AS DATE)<=CAST([2ndFS_EXPIRY1_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_2ndFS_EXPIRY1
,CASE WHEN CAST(ARS.TS_SERVICE_DATE AS DATE)<=CAST([3rdFS_EXPIRY1_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_3rdFS_EXPIRY1
,CASE WHEN CAST(ARS.FS4_SERVICE_DATE AS DATE)<=CAST([4thFS_EXPIRY1_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_4thFS_EXPIRY1
,CASE WHEN CAST(ARS.FS5_SERVICE_DATE AS DATE)<=CAST([5thFS_EXPIRY1_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_5thFS_EXPIRY1
,CASE WHEN CAST(ARS.FS6_SERVICE_DATE AS DATE)<=CAST([6thFS_EXPIRY1_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_6thFS_EXPIRY1
,CASE WHEN CAST(ARS.FS7_SERVICE_DATE AS DATE)<=CAST([7thFS_EXPIRY1_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_7thFS_EXPIRY1
,CASE WHEN CAST(ARS.FS_SERVICE_DATE AS DATE)<=CAST([1stFS_EXPIRY2_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_1stFS_EXPIRY2
,CASE WHEN CAST(ARS.SS_SERVICE_DATE AS DATE)<=CAST([2ndFS_EXPIRY2_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_2ndFS_EXPIRY2
,CASE WHEN CAST(ARS.TS_SERVICE_DATE AS DATE)<=CAST([3rdFS_EXPIRY2_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_3rdFS_EXPIRY2
,CASE WHEN CAST(ARS.FS4_SERVICE_DATE AS DATE)<=CAST([4thFS_EXPIRY2_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_4thFS_EXPIRY2
,CASE WHEN CAST(ARS.FS5_SERVICE_DATE AS DATE)<=CAST([5thFS_EXPIRY2_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_5thFS_EXPIRY2
,CASE WHEN CAST(ARS.FS6_SERVICE_DATE AS DATE)<=CAST([6thFS_EXPIRY2_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_6thFS_EXPIRY2
,CASE WHEN CAST(ARS.FS7_SERVICE_DATE AS DATE)<=CAST([7thFS_EXPIRY2_Date] AS DATE)
THEN 'Done' ELSE NULL END AS STATUS_7thFS_EXPIRY2
,CASE WHEN ARS.FS_SERVICE_DATE BETWEEN [1stFS_EXPIRY1_Date] AND [1stFS_EXPIRY2_Date]
 THEN 'Yes' ELSE 'No' END AS GRACE_PERIOD_1STFS
,CASE WHEN ARS.SS_SERVICE_DATE BETWEEN [2NDFS_EXPIRY1_Date] AND [2NDFS_EXPIRY2_Date]
 THEN 'Yes' ELSE 'No' END AS GRACE_PERIOD_2NDFS
,CASE WHEN ARS.TS_SERVICE_DATE BETWEEN [3RDFS_EXPIRY1_Date] AND [3RDFS_EXPIRY2_Date]
 THEN 'Yes' ELSE 'No' END AS GRACE_PERIOD_3RDFS
,CASE WHEN ARS.FS4_SERVICE_DATE BETWEEN [4thFS_EXPIRY1_Date] AND [4thFS_EXPIRY2_Date]
 THEN 'Yes' ELSE 'No' END AS GRACE_PERIOD_4THFS
,CASE WHEN ARS.FS5_SERVICE_DATE BETWEEN [5thFS_EXPIRY1_Date] AND [5thFS_EXPIRY2_Date]
 THEN 'Yes' ELSE 'No' END AS GRACE_PERIOD_5THFS
,CASE WHEN ARS.FS6_SERVICE_DATE BETWEEN [6THFS_EXPIRY1_Date] AND [6THFS_EXPIRY2_Date]
 THEN 'Yes' ELSE 'No' END AS GRACE_PERIOD_6THFS
,CASE WHEN ARS.FS7_SERVICE_DATE BETWEEN [7THFS_EXPIRY1_Date] AND [7THFS_EXPIRY2_Date]
 THEN 'Yes' ELSE 'No' END AS GRACE_PERIOD_7THFS 
,CASE WHEN ARS.FS_COMPANYID IS NULL THEN NULL
   WHEN ARS.FS_COMPANYID=ARS.FK_COMPANYID THEN 'Self Done'
   WHEN ARS.FS_COMPANYID<>ARS.FK_COMPANYID THEN 'Not Done'
   END AS SELF_REDEEM_1STFS
,CASE WHEN ARS.SS_COMPANYID IS NULL THEN NULL
   WHEN ARS.SS_COMPANYID=ARS.FK_COMPANYID THEN 'Self Done'
   WHEN ARS.SS_COMPANYID<>ARS.FK_COMPANYID THEN 'Not Done'
   END AS SELF_REDEEM_2NDFS
,CASE WHEN ARS.TS_COMPANYID IS NULL THEN NULL
   WHEN ARS.TS_COMPANYID=ARS.FK_COMPANYID THEN 'Self Done'
   WHEN ARS.TS_COMPANYID<>ARS.FK_COMPANYID THEN 'Not Done'
   END AS SELF_REDEEM_3RDFS  
,CASE WHEN ARS.FS4_COMPANYID IS NULL THEN NULL
   WHEN ARS.FS4_COMPANYID=ARS.FK_COMPANYID THEN 'Self Done'
   WHEN ARS.FS4_COMPANYID<>ARS.FK_COMPANYID THEN 'Not Done'
   END AS SELF_REDEEM_4THFS
,CASE WHEN ARS.FS5_COMPANYID IS NULL THEN NULL
   WHEN ARS.FS5_COMPANYID=ARS.FK_COMPANYID THEN 'Self Done'
   WHEN ARS.FS5_COMPANYID<>ARS.FK_COMPANYID THEN 'Not Done'
   END AS SELF_REDEEM_5THFS
,CASE WHEN ARS.FS6_COMPANYID IS NULL THEN NULL
   WHEN ARS.FS6_COMPANYID=ARS.FK_COMPANYID THEN 'Self Done'
   WHEN ARS.FS6_COMPANYID<>ARS.FK_COMPANYID THEN 'Not Done'
   END AS SELF_REDEEM_6THFS
,CASE WHEN ARS.FS7_COMPANYID IS NULL THEN NULL
   WHEN ARS.FS7_COMPANYID=ARS.FK_COMPANYID THEN 'Self Done'
   WHEN ARS.FS7_COMPANYID<>ARS.FK_COMPANYID THEN 'Not Done'
   END AS SELF_REDEEM_7THFS            
,DATEDIFF(D,Docdate,GETDATE()) AS VehicleAging
,DATEDIFF(D,GETDATE(),[1stFS_EXPIRY2_Date]) AS FFS_RemainingDaysForExpiry
,DATEDIFF(D,GETDATE(),[2NDFS_EXPIRY2_Date]) AS SFS_RemainingDaysForExpiry
,DATEDIFF(D,GETDATE(),[3RDFS_EXPIRY2_Date]) AS TFS_RemainingDaysForExpiry
,DATEDIFF(D,GETDATE(),[4THFS_EXPIRY2_Date]) AS FS4_RemainingDaysForExpiry
,DATEDIFF(D,GETDATE(),[5THFS_EXPIRY2_Date]) AS FS5_RemainingDaysForExpiry
,DATEDIFF(D,GETDATE(),[6THFS_EXPIRY2_Date]) AS FS6_RemainingDaysForExpiry
,DATEDIFF(D,GETDATE(),[7THFS_EXPIRY2_Date]) AS FS7_RemainingDaysForExpiry
,CASE WHEN FS_SERVICE_DATE<=[1STFS_EXPIRY2_DATE] THEN 'Serviced'
      WHEN FS_SERVICE_DATE IS NULL AND CAST(GETDATE() AS DATE)<[1STFS_EXPIRY2_DATE] THEN 'Un-Serviced'
      WHEN FS_SERVICE_DATE IS NULL OR FS_SERVICE_DATE>[1STFS_EXPIRY2_DATE] THEN 'Service Expired'
       END AS FSServicingStatus
,CASE WHEN SS_SERVICE_DATE<=[2NDFS_EXPIRY2_DATE] THEN 'Serviced'
      WHEN SS_SERVICE_DATE IS NULL AND CAST(GETDATE() AS DATE)<[2NDFS_EXPIRY2_DATE] THEN 'Un-Serviced'
      WHEN SS_SERVICE_DATE IS NULL OR SS_SERVICE_DATE>[2NDFS_EXPIRY2_DATE] THEN 'Service Expired'
       END AS SSServicingStatus
,CASE WHEN TS_SERVICE_DATE<=[3RDFS_EXPIRY2_DATE] THEN 'Serviced'
      WHEN TS_SERVICE_DATE IS NULL AND CAST(GETDATE() AS DATE)<[3RDFS_EXPIRY2_DATE] THEN 'Un-Serviced'
      WHEN TS_SERVICE_DATE IS NULL OR TS_SERVICE_DATE>[3RDFS_EXPIRY2_DATE] THEN 'Service Expired'
       END AS TSServicingStatus
,CASE WHEN FS4_SERVICE_DATE<=[4THFS_EXPIRY2_DATE] THEN 'Serviced'
      WHEN FS4_SERVICE_DATE IS NULL AND CAST(GETDATE() AS DATE)<[4THFS_EXPIRY2_DATE] THEN 'Un-Serviced'
      WHEN FS4_SERVICE_DATE IS NULL OR FS4_SERVICE_DATE>[4THFS_EXPIRY2_DATE] THEN 'Service Expired'
       END AS FS4ServicingStatus
,CASE WHEN FS5_SERVICE_DATE<=[5THFS_EXPIRY2_DATE] THEN 'Serviced'
      WHEN FS5_SERVICE_DATE IS NULL AND CAST(GETDATE() AS DATE)<[5THFS_EXPIRY2_DATE] THEN 'Un-Serviced'
      WHEN FS5_SERVICE_DATE IS NULL OR FS5_SERVICE_DATE>[5THFS_EXPIRY2_DATE] THEN 'Service Expired'
       END AS FS5ServicingStatus
,CASE WHEN FS6_SERVICE_DATE<=[6THFS_EXPIRY2_DATE] THEN 'Serviced'
      WHEN FS6_SERVICE_DATE IS NULL AND CAST(GETDATE() AS DATE)<[6THFS_EXPIRY2_DATE] THEN 'Un-Serviced'
      WHEN FS6_SERVICE_DATE IS NULL OR FS6_SERVICE_DATE>[6THFS_EXPIRY2_DATE] THEN 'Service Expired'
       END AS FS6ServicingStatus
,CASE WHEN FS7_SERVICE_DATE<=[7THFS_EXPIRY2_DATE] THEN 'Serviced'
      WHEN FS7_SERVICE_DATE IS NULL AND CAST(GETDATE() AS DATE)<[7THFS_EXPIRY2_DATE] THEN 'Un-Serviced'
      WHEN FS7_SERVICE_DATE IS NULL OR FS7_SERVICE_DATE>[7THFS_EXPIRY2_DATE] THEN 'Service Expired'
       END AS FS7ServicingStatus
                                   
,CASE WHEN FS_SERVICE_DATE<=[1STFS_EXPIRY1_DATE] THEN 0 ELSE 1 END AS FS_Grace_Flag
,CASE WHEN SS_SERVICE_DATE<=[2NDFS_EXPIRY1_DATE] THEN 0 ELSE 1 END AS SS_Grace_Flag
,CASE WHEN TS_SERVICE_DATE<=[3RDFS_EXPIRY1_DATE] THEN 0 ELSE 1 END AS TS_Grace_Flag
,CASE WHEN FS4_SERVICE_DATE<=[4THFS_EXPIRY1_DATE] THEN 0 ELSE 1 END AS FS4_Grace_Flag
,CASE WHEN FS5_SERVICE_DATE<=[5THFS_EXPIRY1_DATE] THEN 0 ELSE 1 END AS FS5_Grace_Flag
,CASE WHEN FS6_SERVICE_DATE<=[6THFS_EXPIRY1_DATE] THEN 0 ELSE 1 END AS FS6_Grace_Flag
,CASE WHEN FS7_SERVICE_DATE<=[7THFS_EXPIRY1_DATE] THEN 0 ELSE 1 END AS FS7_Grace_Flag
,CASE WHEN MONTH(GETDATE())<=3 AND DATEDIFF(MM,LSD.LASTSERVICEDATE,CAST(CONCAT(YEAR(GETDATE())-1,'-','04','-','01') AS DATE)) BETWEEN 0 AND 6 THEN 'H2'
      WHEN MONTH(GETDATE())>3 AND DATEDIFF(MM,LSD.LASTSERVICEDATE,CAST(CONCAT(YEAR(GETDATE()),'-','04','-','01') AS DATE)) BETWEEN 0 AND 6 THEN 'H2'
      WHEN MONTH(GETDATE())<=3 AND DATEDIFF(MM,LSD.LASTSERVICEDATE,CAST(CONCAT(YEAR(GETDATE())-1,'-','10','-','01') AS DATE)) BETWEEN 0 AND 6 THEN 'H1'
      WHEN MONTH(GETDATE())>3 AND DATEDIFF(MM,LSD.LASTSERVICEDATE,CAST(CONCAT(YEAR(GETDATE()),'-','10','-','01') AS DATE)) BETWEEN 0 AND 6 THEN 'H1'
      ELSE 'LOST' END AS Lost_Customer
,LSD.LastServiceDate
,LSD.LastServiceName
,LSD.LastKmReading
FROM ASM_CV_SERVICE_RETAIL_STG ARS

LEFT JOIN

(SELECT IBID
,LastServiceDate
,LastServiceName
,LastKmReading
FROM
(SELECT DISTINCT IBID
,CAST(DOCDATE AS DATE) AS LastServiceDate
,SCM.NAME AS LastServiceName
,SH.UsageReading as LastKmReading
,ROW_NUMBER() OVER(PARTITION BY IBID ORDER BY DOCDATE DESC) RNO
FROM SERVICE_HEADER SH
JOIN COMPANY_MASTER CM ON (CM.COMPANYID = SH.COMPANYID AND CM.COMPANYTYPE = 7)
JOIN SERVICE_CONTRACT_MASTER SCM ON SCM.SERVICECONTRACTID=SH.CONTRACTTYPEID
) LATEST_DATE
WHERE RNO=1) LSD on LSD.IBID=ARS.FK_Ibid

WHERE ARS.Return_Flag='NR'

----------------------------FSR REPORT TABLE
TRUNCATE TABLE [dbo].[ASM_CV_RETAIL_FLAGS_UNION]

INSERT INTO [dbo].[ASM_CV_RETAIL_FLAGS_UNION]
SELECT 
*,CASE WHEN Flag = 'Due Date' THEN [Due_date]
WHEN Flag = 'Expiry Date' THEN [Expiry_date] END AS DATE
FROM
(SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    [BU],
    [Companytype],
    [Dealercode],
    [1stFS_EXPIRY1_Date] as Due_date,
    [1stFS_EXPIRY2_Date] as Expiry_date,
    'First Free Service' as Service_type,
    [FSServicingStatus] as Service_Status,
	'Expiry Date' as Flag,
    [VehicleAging],
    [FFS_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading] 
    from ASM_CV_RETAIL_FLAGS
 
    UNION ALL
    SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    [BU],
    [Companytype],
    [Dealercode],
    [2ndFS_EXPIRY1_Date] as Due_date,
    [2ndFS_EXPIRY2_Date] as Expiry_date,
    'Second Free Service' as Service_type,
    SSServicingStatus as Service_Status,
	'Expiry Date' as Flag,
    [VehicleAging],
    [SFS_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading] 
    from ASM_CV_RETAIL_FLAGS
    
    UNION ALL
    SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    [BU],
    [Companytype],
    [Dealercode],
    [3rdFS_EXPIRY1_Date] as Due_date,
    [3rdFS_EXPIRY2_Date] as Expiry_date,
    'Third Free Service' as Service_type,
    TSServicingStatus as Service_Status,
	'Expiry Date' as Flag,
    [VehicleAging],
    [TFS_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading]
    from ASM_CV_RETAIL_FLAGS

	UNION ALL

	SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    CR.[BU],
    [Companytype],
    [Dealercode],
    [4thFS_EXPIRY1_Date] as Due_date,
    [4thFS_EXPIRY2_Date] as Expiry_date,
    'Fourth Free Service' as Service_type,
    [FS4ServicingStatus] as Service_Status,
	'Expiry Date' as Flag,
    [VehicleAging],
    [FS4_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading]
    from ASM_CV_RETAIL_FLAGS CR
	JOIN ASM_SERVICE_MODEL_MASTER_DIM MD ON CR.FK_Modelid = MD.Modelid
	WHERE MD.CategoryICBU = 'E-TEC'

    UNION ALL

	SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    CR.[BU],
    [Companytype],
    [Dealercode],
    [5thFS_EXPIRY1_Date] as Due_date,
    [5thFS_EXPIRY2_Date] as Expiry_date,
    'Fifth Free Service' as Service_type,
    [FS5ServicingStatus] as Service_Status,
	'Expiry Date' as Flag,
    [VehicleAging],
    [FS5_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading]
    from ASM_CV_RETAIL_FLAGS CR
	JOIN ASM_SERVICE_MODEL_MASTER_DIM MD ON CR.FK_Modelid = MD.Modelid
	WHERE MD.CategoryICBU = 'E-TEC'

	UNION ALL

	SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    CR.[BU],
    [Companytype],
    [Dealercode],
    [6thFS_EXPIRY1_Date] as Due_date,
    [6thFS_EXPIRY2_Date] as Expiry_date,
    'Sixth Free Service' as Service_type,
    [FS6ServicingStatus] as Service_Status,
	'Expiry Date' as Flag,
    [VehicleAging],
    [FS6_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading]
    from ASM_CV_RETAIL_FLAGS CR
	JOIN ASM_SERVICE_MODEL_MASTER_DIM MD ON CR.FK_Modelid = MD.Modelid
	WHERE MD.CategoryICBU = 'E-TEC'
	
	UNION ALL

	SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    CR.[BU],
    [Companytype],
    [Dealercode],
    [7thFS_EXPIRY1_Date] as Due_date,
    [7thFS_EXPIRY2_Date] as Expiry_date,
    'Seventh Free Service' as Service_type,
    [FS7ServicingStatus] as Service_Status,
	'Expiry Date' as Flag,
    [VehicleAging],
    [FS7_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading]
    from ASM_CV_RETAIL_FLAGS CR
	JOIN ASM_SERVICE_MODEL_MASTER_DIM MD ON CR.FK_Modelid = MD.Modelid
	WHERE MD.CategoryICBU = 'E-TEC'

    UNION ALL

	SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    [BU],
    [Companytype],
    [Dealercode],
    [1stFS_EXPIRY1_Date] as Due_date,
    [1stFS_EXPIRY2_Date] as Expiry_date,
    'First Free Service' as Service_type,
    [FSServicingStatus] as Service_Status,
	'Due Date' as Flag,
    [VehicleAging],
    [FFS_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading] 
    from ASM_CV_RETAIL_FLAGS
 
    UNION ALL
    SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    [BU],
    [Companytype],
    [Dealercode],
    [2ndFS_EXPIRY1_Date] as Due_date,
    [2ndFS_EXPIRY2_Date] as Expiry_date,
    'Second Free Service' as Service_type,
    SSServicingStatus as Service_Status,
	'Due Date' as Flag,
    [VehicleAging],
    [SFS_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading] 
    from ASM_CV_RETAIL_FLAGS
    
    UNION ALL
    SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    [BU],
    [Companytype],
    [Dealercode],
    [3rdFS_EXPIRY1_Date] as Due_date,
    [3rdFS_EXPIRY2_Date] as Expiry_date,
    'Third Free Service' as Service_type,
    TSServicingStatus as Service_Status,
	'Due Date' as Flag,
    [VehicleAging],
    [TFS_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading]
    from ASM_CV_RETAIL_FLAGS

	UNION ALL

	SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    CR.[BU],
    [Companytype],
    [Dealercode],
    [4thFS_EXPIRY1_Date] as Due_date,
    [4thFS_EXPIRY2_Date] as Expiry_date,
    'Fourth Free Service' as Service_type,
    [FS4ServicingStatus] as Service_Status,
	'Due Date' as Flag,
    [VehicleAging],
    [FS4_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading]
    from ASM_CV_RETAIL_FLAGS CR
	JOIN ASM_SERVICE_MODEL_MASTER_DIM MD ON CR.FK_Modelid = MD.Modelid
	WHERE MD.CategoryICBU = 'E-TEC'

    UNION ALL

	SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    CR.[BU],
    [Companytype],
    [Dealercode],
    [5thFS_EXPIRY1_Date] as Due_date,
    [5thFS_EXPIRY2_Date] as Expiry_date,
    'Fifth Free Service' as Service_type,
    [FS5ServicingStatus] as Service_Status,
	'Due Date' as Flag,
    [VehicleAging],
    [FS5_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading]
    from ASM_CV_RETAIL_FLAGS CR
	JOIN ASM_SERVICE_MODEL_MASTER_DIM MD ON CR.FK_Modelid = MD.Modelid
	WHERE MD.CategoryICBU = 'E-TEC'

	UNION ALL

	SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    CR.[BU],
    [Companytype],
    [Dealercode],
    [6thFS_EXPIRY1_Date] as Due_date,
    [6thFS_EXPIRY2_Date] as Expiry_date,
    'Sixth Free Service' as Service_type,
    [FS6ServicingStatus] as Service_Status,
	'Due Date' as Flag,
    [VehicleAging],
    [FS6_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading]
    from ASM_CV_RETAIL_FLAGS CR
	JOIN ASM_SERVICE_MODEL_MASTER_DIM MD ON CR.FK_Modelid = MD.Modelid
	WHERE MD.CategoryICBU = 'E-TEC'
	
	UNION ALL

	SELECT 
    [FK_Docid],
    [DOCNAME],
    [Docdate],
    [FK_Companyid],
    [Lineid],
    [FK_Contactid],
    [FK_Ibid],
    [FK_Branchid],
    [FK_Modelid],
    CR.[BU],
    [Companytype],
    [Dealercode],
    [7thFS_EXPIRY1_Date] as Due_date,
    [7thFS_EXPIRY2_Date] as Expiry_date,
    'Seventh Free Service' as Service_type,
    [FS7ServicingStatus] as Service_Status,
	'Due Date' as Flag,
    [VehicleAging],
    [FS7_RemainingDaysForExpiry] AS [RemainingDaysForExpiry], 
    [LastServiceDate], 
    [LastServiceName],
    [LastKmReading]
    from ASM_CV_RETAIL_FLAGS CR
	JOIN ASM_SERVICE_MODEL_MASTER_DIM MD ON CR.FK_Modelid = MD.Modelid
	WHERE MD.CategoryICBU = 'E-TEC'
    
) T


----------------------------------PAID DUE REPORT
TRUNCATE TABLE [dbo].[ASM_CV_PAID_DUE_REPORT]

INSERT INTO ASM_CV_PAID_DUE_REPORT

SELECT DISTINCT FK_Ibid,
docdate as Ret_Date,
FK_Companyid,
FK_Contactid,
FK_Branchid,
FK_Modelid,
Dealercode,
LastServiceDate,
LastServiceName,
LastKmReading,
VehicleAging,
case when datediff(d,lastservicedate,getdate())>=45 and datediff(d,lastservicedate,getdate())<=90 then '45 days'
when datediff(d,lastservicedate,getdate())>90 and datediff(d,lastservicedate,getdate())<=180 then '90 days'
when datediff(d,lastservicedate,getdate())>180 and datediff(d,lastservicedate,getdate())<=360 then '6 months'
when datediff(m,lastservicedate,getdate())>12 and datediff(m,lastservicedate,getdate())<=15 then '12 months'
when datediff(m,lastservicedate,getdate())>15 and datediff(m,lastservicedate,getdate())<=18 then '15 months'
when datediff(m,lastservicedate,getdate())>18 and datediff(m,lastservicedate,getdate())<=24 then '18 months'
when datediff(m,lastservicedate,getdate())>24 then '2 years' else 'Reported' 
end as [Not reported since last]
FROM ASM_CV_RETAIL_FLAGS 
WHERE VEHICLEAGING>135

----------------------------------OVERALL FS DONE 
TRUNCATE TABLE ASM_CV_FREE_SERVICE

INSERT INTO ASM_CV_FREE_SERVICE

SELECT A.*, 
CASE WHEN SERVICE_DATE <= [EXPIRY_DATE] THEN 1 ELSE 0 END AS EXPIRY_STATUS,
CASE WHEN SERVICE_DATE <= DUE_DATE THEN 1 ELSE 0 END AS DUE_STATUS
FROM 
(SELECT B.*,
CASE WHEN FS_IDENTIFIER IN (48,174) THEN DATEADD(DAY,60,cast(RETAIL_DATE as date))
WHEN FS_IDENTIFIER IN (190,175) THEN DATEADD(DAY,90,cast(RETAIL_DATE as date))
WHEN FS_IDENTIFIER IN (191,176) THEN DATEADD(DAY,135,cast(RETAIL_DATE as date))
WHEN FS_IDENTIFIER IN (210) THEN DATEADD(DAY,180,cast(RETAIL_DATE as date))
WHEN FS_IDENTIFIER IN (211) THEN DATEADD(DAY,225,cast(RETAIL_DATE as date))
WHEN FS_IDENTIFIER IN (212) THEN DATEADD(DAY,270,cast(RETAIL_DATE as date))
WHEN FS_IDENTIFIER IN (213) THEN DATEADD(DAY,315,cast(RETAIL_DATE as date)) ELSE NULL END AS EXPIRY_DATE,
CASE WHEN FS_IDENTIFIER IN (48,174) THEN DATEADD(DAY,30,cast(RETAIL_DATE as date))
WHEN FS_IDENTIFIER IN (190,175) THEN DATEADD(DAY,75,cast(RETAIL_DATE as date))
WHEN FS_IDENTIFIER IN (191,176) THEN DATEADD(DAY,120,cast(RETAIL_DATE as date))
WHEN FS_IDENTIFIER IN (210) THEN DATEADD(DAY,165,cast(RETAIL_DATE as date))
WHEN FS_IDENTIFIER IN (211) THEN DATEADD(DAY,210,cast(RETAIL_DATE as date))
WHEN FS_IDENTIFIER IN (212) THEN DATEADD(DAY,255,cast(RETAIL_DATE as date))
WHEN FS_IDENTIFIER IN (213) THEN DATEADD(DAY,300,cast(RETAIL_DATE as date)) ELSE NULL END AS DUE_DATE
FROM 
(SELECT DISTINCT CM.CODE AS DEALERCODE,ACV.DOCDATE AS RETAIL_DATE,CAST(SH.DOCDATE AS DATE) AS SERVICE_DATE,SH.HEADERID AS FK_DOCID,SH.IBID AS FK_IBID,SH.MODELId AS FK_MODELID,SH.CONTRACTTYPEID FS_IDENTIFIER,SH.BRANCHID AS FK_BRANCHID
FROM SERVICE_HEADER SH
JOIN COMPANY_MASTER CM ON (CM.COMPANYID = SH.COMPANYID AND CM.COMPANYTYPE = 7)
LEFT JOIN ASM_CV_RETAIL_FLAGS ACV ON ACV.FK_IBID = SH.IBID
WHERE SH.CONTRACTTYPEID IN (48,174,190,175,191,176,210,211,212,213) AND SH.CANCELLATIONDATE IS NULL
AND CAST(SH.DOCDATE AS DATE) >= '2021-04-01')B)A

-----------------------------------INSERT INTO FACT TABLE

DELETE FROM ASM_CV_SERVICE_FACT WHERE SERVICE_RETAIL_TYPEIDENTIFIER=102

INSERT INTO ASM_CV_SERVICE_FACT(FK_Docid,
DOCNAME,
Docdate,
FK_Companyid,
Lineid,
FK_Contactid,
FK_Ibid,
FK_Branchid,
FK_Modelid,
BU,
COMPANYTYPE,
Dealercode,
SALESCHANNEL,
[1stFS_EXPIRY1_Date],
[2ndFS_EXPIRY1_Date],
[3rdFS_EXPIRY1_Date],
[4thFS_EXPIRY1_Date],
[5thFS_EXPIRY1_Date],
[6thFS_EXPIRY1_Date],
[7thFS_EXPIRY1_Date],
[1stFS_EXPIRY2_Date],
[2ndFS_EXPIRY2_Date],
[3rdFS_EXPIRY2_Date],
[4thFS_EXPIRY2_Date],
[5thFS_EXPIRY2_Date],
[6thFS_EXPIRY2_Date],
[7thFS_EXPIRY2_Date],
Return_Flag,
Importeddate,
Service_Retail_TypeIdentifier,
STATUS_1stFS_EXPIRY1,
STATUS_2ndFS_EXPIRY1,
STATUS_3rdFS_EXPIRY1,
STATUS_4thFS_EXPIRY1,
STATUS_5thFS_EXPIRY1,
STATUS_6thFS_EXPIRY1,
STATUS_7thFS_EXPIRY1,
STATUS_1stFS_EXPIRY2,
STATUS_2ndFS_EXPIRY2,
STATUS_3rdFS_EXPIRY2,
STATUS_4thFS_EXPIRY2,
STATUS_5thFS_EXPIRY2,
STATUS_6thFS_EXPIRY2,
STATUS_7thFS_EXPIRY2,
GRACE_PERIOD_1STFS,
GRACE_PERIOD_2NDFS,
GRACE_PERIOD_3RDFS,
GRACE_PERIOD_4THFS,
GRACE_PERIOD_5THFS,
GRACE_PERIOD_6THFS,
GRACE_PERIOD_7THFS,
SELF_REDEEM_1STFS,
SELF_REDEEM_2NDFS,
SELF_REDEEM_3RDFS,
SELF_REDEEM_4THFS,
SELF_REDEEM_5THFS,
SELF_REDEEM_6THFS,
SELF_REDEEM_7THFS,
FS_Grace_Flag,
SS_Grace_Flag,
TS_Grace_Flag,
FS4_Grace_Flag,
FS5_Grace_Flag,
FS6_Grace_Flag,
FS7_Grace_Flag,
Lost_Customer,
Refresh_Date)

SELECT 
FK_Docid,
DOCNAME,
Docdate,
FK_Companyid,
Lineid,
FK_Contactid,
FK_Ibid,
FK_Branchid,
FK_Modelid,
BU,
COMPANYTYPE,
Dealercode,
SALESCHANNEL,
[1stFS_EXPIRY1_Date],
[2ndFS_EXPIRY1_Date],
[3rdFS_EXPIRY1_Date],
[4thFS_EXPIRY1_Date],
[5thFS_EXPIRY1_Date],
[6thFS_EXPIRY1_Date],
[7thFS_EXPIRY1_Date],
[1stFS_EXPIRY2_Date],
[2ndFS_EXPIRY2_Date],
[3rdFS_EXPIRY2_Date],
[4thFS_EXPIRY2_Date],
[5thFS_EXPIRY2_Date],
[6thFS_EXPIRY2_Date],
[7thFS_EXPIRY2_Date],
Return_Flag,
Importeddate,
Service_Retail_TypeIdentifier,
STATUS_1stFS_EXPIRY1,
STATUS_2ndFS_EXPIRY1,
STATUS_3rdFS_EXPIRY1,
STATUS_4thFS_EXPIRY1,
STATUS_5thFS_EXPIRY1,
STATUS_6thFS_EXPIRY1,
STATUS_7thFS_EXPIRY1,
STATUS_1stFS_EXPIRY2,
STATUS_2ndFS_EXPIRY2,
STATUS_3rdFS_EXPIRY2,
STATUS_4thFS_EXPIRY2,
STATUS_5thFS_EXPIRY2,
STATUS_6thFS_EXPIRY2,
STATUS_7thFS_EXPIRY2,
GRACE_PERIOD_1STFS,
GRACE_PERIOD_2NDFS,
GRACE_PERIOD_3RDFS,
GRACE_PERIOD_4THFS,
GRACE_PERIOD_5THFS,
GRACE_PERIOD_6THFS,
GRACE_PERIOD_7THFS,
SELF_REDEEM_1STFS,
SELF_REDEEM_2NDFS,
SELF_REDEEM_3RDFS,
SELF_REDEEM_4THFS,
SELF_REDEEM_5THFS,
SELF_REDEEM_6THFS,
SELF_REDEEM_7THFS,
FS_Grace_Flag,
SS_Grace_Flag,
TS_Grace_Flag,
FS4_Grace_Flag,
FS5_Grace_Flag,
FS6_Grace_Flag,
FS7_Grace_Flag,
Lost_Customer,
GETDATE() AS Refresh_Date

FROM ASM_CV_RETAIL_FLAGS
END
GO


