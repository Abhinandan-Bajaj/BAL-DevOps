
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create PROC [dbo].[USP_ASM_PB_HKT_ALLOCATION_REFRESH] AS
BEGIN
/********************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION				    */
/*--------------------------------------------------------------------------------------------------*/
/*  2025-07-18 	|	Lachmanna		        | Newly Added script for K+T        */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

--************************************START****************************************
--1.Allocation Dim
INSERT INTO ASM_PB_HK_ALLOCATION_DIM
SELECT DISTINCT 
AH.HEADERID AS PK_ALLOCATIONHEADERID,
CAST(AH.DOCDATE AS DATE) AS ALLOCATIONDATE,
GETDATE() AS CREATEDDATETIME,
AH.IMPORTEDDATE,
AH.CDMS_BATCHNO
FROM ALLOCATION_HEADER  AH
INNER JOIN COMPANY_MASTER
ON (AH.COMPANYID=COMPANY_MASTER.COMPANYID AND
COMPANY_MASTER.COMPANYTYPE = 2) --AND COMPANY_MASTER.COMPANYSUBTYPE is null))
INNER JOIN ALLOCATION_LINE AL ON (AH.HEADERID=AL.DOCID)
JOIN ITEM_MASTER IM ON (IM.ItemId=AL.ItemID)
INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND <>'TRIUMPH' and rnk = 1
WHERE  
--CAST(AH.DOCDATE AS DATE) BETWEEN '2025-06-09' AND  Cast(Getdate()-1 as date)
AH.IMPORTEDDATE>=(SELECT MAX(IMPORTEDDATE)  FROM ASM_PB_HK_ALLOCATION_DIM)

-----------------------------------------------------------------------------------------------
DELETE FROM ASM_PB_HK_ALLOCATION_DIM WHERE ALLOCATIONDATE>Cast(Getdate()-1 as date)

--Dedup:
;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_ALLOCATIONHEADERID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_HK_ALLOCATION_DIM                  
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;

--***************************************************************************************
--2.Allocation Fact:
INSERT INTO ASM_PB_HK_ALLOCATION_FACT
SELECT 
DISTINCT
CM.CODE AS DEALERCODE,
IM.CODE+IV.CODE As SKU,
Cast(0 as int) AS FK_DealerCode,
Cast(0 as int) AS FK_SKU,
10007 AS FK_TYPE_ID,
CAST(AH.DOCDATE AS DATE) AS DATE,
AL.LINEID AS AllocationLineID,
AL.DOCID AS FK_AllocationDocID,
CM.COMPANYTYPE AS COMPANYTYPE,
AH.BRANCHID,
COUNT(AH.HEADERID) AS ACTUALQUANTITY,
getdate() as LASTUPDATEDDATETIME,
AH.IMPORTEDDATE,
IM.CODE As MODEL,
Cast(0 as int) As FK_MODEL,
Cast(0 As decimal(19,0)) As FLAG,
NULL AS TEHSILID,
NULL AS SALESPERSON
FROM 
ALLOCATION_HEADER AH 
INNER JOIN COMPANY_MASTER CM ON (AH.COMPANYID=CM.COMPANYID AND (CM.COMPANYTYPE = 2 AND CM.COMPANYSUBTYPE is null))
INNER JOIN ALLOCATION_LINE AL ON (AH.HEADERID=AL.DOCID)
JOIN ITEM_MASTER IM ON (IM.ItemId=AL.ItemID)
   INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND <>'TRIUMPH' and rnk = 1
LEFT JOIN ITEMVARMATRIX_MASTER IV ON (AL.VARMATRIXID=IV.ITEMVARMATRIXID)
WHERE 
--CAST(AH.DOCDATE AS DATE) BETWEEN '2025-06-09' AND  Cast(Getdate()-1 as date) 
AH.IMPORTEDDATE>=(SELECT MAX(IMPORTEDDATE) FROM ASM_PB_HK_ALLOCATION_FACT)
GROUP BY
CM.CODE,
IM.CODE+IV.CODE,
CAST(AH.DOCDATE AS DATE),
AL.LINEID,
AL.DOCID,
CM.COMPANYTYPE,
AH.BRANCHID,
AH.IMPORTEDDATE,
IM.CODE 

DELETE FROM ASM_PB_HK_ALLOCATION_FACT WHERE DATE>Cast(Getdate()-1 as date)

--Dedup Process:
;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_AllocationDocID,AllocationLineID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_HK_ALLOCATION_FACT                
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1; 
 
--****************************************************************************************************
--Product Master and Dealer Master FK update: ASM_PB_ALLOCATION_FACT
update B set B.FK_SKU=C.PK_SKU from ASM_PB_HK_ALLOCATION_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_PB_HK_ALLOCATION_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_DIM C on (B.MODEL=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].ASM_PB_HK_ALLOCATION_FACT B INNER JOIN ASM_PB_HKT_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE);

--**************************************************************************************************************

EXEC [USP_ASM_PB_T_ALLOCATION_REFRESH];

TRUNCATE TABLE ASM_PB_HKT_ALLOCATION_DIM;
INSERT into ASM_PB_HKT_ALLOCATION_DIM
Select*,'PB KTM' as Brand from ASM_PB_HK_ALLOCATION_DIM;
INSERT into ASM_PB_HKT_ALLOCATION_DIM
Select*,'PB TRM' as Brand from ASM_PB_T_ALLOCATION_DIM;

END
GO