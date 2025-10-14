/****** Object:  StoredProcedure [dbo].[USP_Full_Load_ASM_PB_T_ALLOCATION_REFRESH]    Script Date: 03-11-2023 11:07:40 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

Alter  PROC [dbo].[USP_ASM_PB_T_ALLOCATION_REFRESH] AS
BEGIN

/********************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION				    */
/*--------------------------------------------------------------------------------------------------*/
/*  2025-07-18 	|	Lachmanna		        | Newly Added script for K+T        */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
--***************************START*****************************
--1.Allocation Dim



declare @ASMDim_IMPORTEDDATE date;
set @ASMDim_IMPORTEDDATE = CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_PB_T_ALLOCATION_FACT)AS DATE);

declare @ASMFact_IMPORTEDDATE date;
set @ASMFact_IMPORTEDDATE = CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_PB_T_ALLOCATION_FACT)AS DATE);


DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_PB_T_ALLOCATION_REFRESH';

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			@table_name1 VARCHAR(128) = 'ASM_PB_T_ALLOCATION_DIM', 
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT,   
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX); 

BEGIN TRY

INSERT INTO ASM_PB_T_ALLOCATION_DIM
SELECT DISTINCT 
AH.HEADERID AS PK_ALLOCATIONHEADERID,
CAST(AH.DOCDATE AS DATE) AS ALLOCATIONDATE,
GETDATE() AS CREATEDDATETIME,
AH.IMPORTEDDATE,
AH.CDMS_BATCHNO
FROM ALLOCATION_HEADER  AH
INNER JOIN COMPANY_MASTER ON (AH.COMPANYID=COMPANY_MASTER.COMPANYID 
AND (COMPANY_MASTER.COMPANYTYPE = 2))-- AND COMPANY_MASTER.COMPANYSUBTYPE='Triumph'))
INNER JOIN ALLOCATION_LINE AL ON (AH.HEADERID=AL.DOCID)
JOIN ITEM_MASTER IM ON (IM.ItemId=AL.ItemID)
INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
    from ASM_PB_HKT_PRODUCT_DIM) PM  
   ON  PM.Modelcode = IM.CODE and PM.BRAND ='TRIUMPH'and rnk = 1
WHERE 
--CAST(AH.DOCDATE AS DATE) BETWEEN '2025-06-09' AND Cast(Getdate()-1 as date)
Cast(AH.IMPORTEDDATE as date)>=@ASMDim_IMPORTEDDATE

DELETE FROM ASM_PB_T_ALLOCATION_DIM WHERE ALLOCATIONDATE>Cast(Getdate()-1 as date)


--Dedup:
;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_ALLOCATIONHEADERID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_T_ALLOCATION_DIM                  
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;

--***************************************************************************************
--2.Allocation Fact:
INSERT INTO ASM_PB_T_ALLOCATION_FACT
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
Null as TEHSILID,
Null as SalesPerson
FROM 
ALLOCATION_HEADER AH 
INNER JOIN COMPANY_MASTER CM 
ON (AH.COMPANYID=CM.COMPANYID 
AND (CM.COMPANYTYPE = 2 ))-- AND CM.COMPANYSUBTYPE='Triumph' ))
INNER JOIN ALLOCATION_LINE AL ON (AH.HEADERID=AL.DOCID)
JOIN ITEM_MASTER IM ON (IM.ItemId=AL.ItemID)
INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
    from ASM_PB_HKT_PRODUCT_DIM) PM  
   ON  PM.Modelcode = IM.CODE and PM.BRAND ='TRIUMPH'and rnk = 1
LEFT JOIN ITEMVARMATRIX_MASTER IV ON (AL.VARMATRIXID=IV.ITEMVARMATRIXID)
WHERE 
--CAST(AH.DOCDATE AS DATE) BETWEEN  '2025-06-09' AND Cast(Getdate()-1 as date)
cast(AH.IMPORTEDDATE as date)>=@ASMFact_IMPORTEDDATE
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

DELETE FROM ASM_PB_T_ALLOCATION_FACT WHERE DATE>Cast(Getdate()-1 as date)

--Dedup Process:
;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_AllocationDocID,AllocationLineID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_T_ALLOCATION_FACT                
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1; 
 
--****************************************************************************************************
--Product Master and Dealer Master FK update: ASM_PB_T_ALLOCATION_FACT
update B set B.FK_SKU=C.PK_SKU from ASM_PB_T_ALLOCATION_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_PB_T_ALLOCATION_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_DIM C on (B.MODEL=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].ASM_PB_T_ALLOCATION_FACT B INNER JOIN ASM_PB_HKT_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)


----------------------------------Audit Log Target
    END TRY
    BEGIN CATCH
        SET @Status1 = 'FAILURE';
        SET @ErrorMessage1 = ERROR_MESSAGE();
        THROW;  
    END CATCH
    SET @EndDate_utc1 = GETDATE();
	SET @EndDate_ist1 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));
    SET @Duration_sec1 = DATEDIFF(SECOND, @StartDate_ist1, @EndDate_ist1);
	SET @Duration1 = CONVERT(VARCHAR(8), DATEADD(SECOND, @Duration_sec1, 0), 108);
    EXEC [USP_Audit_Balance_Control_Logs] 
	     @SPID,
        @sp_name,
		@table_name1,
        'Sales',
        'PB-TRM',
        @StartDate_utc1,
        @EndDate_utc1,
		@StartDate_ist1,
        @EndDate_ist1,
        @Duration1,  
        '0',
        '0',
        @Status1,
        @ErrorMessage1;

--**************************************************************************************************************

END
GO


