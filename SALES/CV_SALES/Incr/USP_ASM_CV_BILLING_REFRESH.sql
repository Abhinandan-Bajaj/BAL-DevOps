
/****** Object:  StoredProcedure [dbo].[USP_ASM_CV_BILLING_REFRESH]    Script Date: 01-12-2023 15:08:16 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_CV_BILLING_REFRESH] AS
BEGIN

/* History*/
/*  03/11/2025 |  Ashwini Ahire          | Docdate added                */


/* Step 1 : Loading USP_ASM_CV_BILLING_REFRESH Dim */

DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_CV_BILLING_REFRESH';
----------------------------------------------------------------
    -- Audit Segment 1: ASM_CV_PENDING_ORDER_STG
----------------------------------------------------------------  

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			@table_name1 VARCHAR(128) = 'ASM_CV_PENDING_ORDER_STG', 
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT,   
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX);  
BEGIN TRY


--***********************************************************************
--Billing Data Query
--***********************************************************************
delete from SAP_BILLING Where BILLINGDOC IN (SELECT DISTINCT BILLINGDOC FROM SAP_BILLING_CANCELLED)

INSERT INTO ASM_CV_BILLING_STG
SELECT DISTINCT
'0000'+B.DEALERCODE AS DEALERCODE,
B.MATERIAL as SKU,
Cast(0 as int) as FK_DEALERCODE,
Cast(0 as int) as FK_SKU,
10003 As FK_TYPE_ID,
B.DOCDATE AS DATE,
Sum(B.BILLQTY) as ACTUALQUANTITY,
0 As TARGETQUANTITY,
cast(0 as decimal(19,0)) As PENDING_ORDERS,
getdate() as LASTUPDATEDDATETIME,
B.MATERIAL,
LEFT(B.MATERIAL,6) As MODELCODE,
Cast(0 as int) as FK_MODEL,
100031 As FLAG,
NULL AS DOCDATE
--INTO ASM_CV_BILLING_STG
FROM
   SAP_BILLING B
WHERE 
--B.DOCDATE BETWEEN '2020-04-01' and '2023-06-13'
B.DOCDATE> (SELECT MAX(DATE) from ASM_CV_BILLING_STG)
AND [Distr.Chnl] IN(10,40) and DIVISION IN ('B3','B6') AND B.CANCELLED<>'X'
GROUP BY
    '0000'+B.DEALERCODE,
    B.MATERIAL,
    B.DOCDATE,
    B.MATERIAL,
	LEFT(B.MATERIAL,6)

--*************************************************************

--****************************************************************
TRUNCATE TABLE ASM_CV_BILLING_PLAN_STG

INSERT INTO ASM_CV_BILLING_PLAN_STG

SELECT DISTINCT -- 98,023 total count using new table
ZO.DEALER,
ZO.SKU as SKU,--- need to check 
Cast(0 as int) as FK_DEALERCODE,
Cast(0 as int) as FK_SKU,
10003 As FK_TYPE_ID,
--ZO.DOCDATE AS DATE, -- old ZPMSS table
Cast(convert(datetime, replace((LEFT(ZO.CMONTH,3)+' '+CAST(ZO.CYEAR AS VARCHAR(4))), '-', ' ')) as date) As DATE,
Cast(0 as decimal(19,0)) as ACTUALQUANTITY,
Sum(ZO.ZM_Quantity) As TARGETQUANTITY,
cast(0 as decimal(19,0)) As PENDING_ORDERS,
getdate() as LASTUPDATEDDATETIME,
ZO.SKU,--- for material SKU can be used
LEFT(ZO.SKU,6) As MODELCODE,--for material SKU can be used
Cast(0 as int) as FK_MODEL,
100032 As FLAG,
NULL AS DOCDATE
--INTO ASM_CV_BILLING_PLAN_STG
FROM 
SAP_ZSD_SKU_PLAN ZO 
WHERE
ZO.DEALER IN (SELECT DISTINCT KUNNR from SAP_ZSD_DEALER_REPOS WHERE KATR6='CV')
Group By
	ZO.DEALER,
	ZO.SKU,
    Cast(convert(datetime, replace((LEFT(ZO.CMONTH,3)+' '+CAST(ZO.CYEAR AS VARCHAR(4))), '-', ' ')) as date),	
	LEFT(ZO.SKU,6)

--********************************************************
--Order Qty:

INSERT INTO ASM_CV_PENDING_ORDER_STG
SELECT DISTINCT
PO.FLD16 As DEALERCODE,
PO.FLD22 as SKU,
Cast(0 as int) as FK_DEALERCODE,
Cast(0 as int) as FK_SKU,
10003 As FK_TYPE_ID,
GETDATE() as DATE,
--(CONVERT(date, ltrim(rtrim([FLD32])), 105)) AS DATE, (--passing date as getdate from 31st Oct)
Cast(0 as decimal(19,0)) as ACTUALQUANTITY,
cast(0 as decimal(19,0)) As TARGETQUANTITY,
SUM(CAST((FLD12) as DECIMAL(19,0))) As PENDING_ORDERS,
getdate() as LASTUPDATEDDATETIME,
PO.FLD22,
LEFT(PO.FLD22,6) As MODELCODE,
Cast(0 as int) as FK_MODEL,
100033 As FLAG,
(CONVERT(date, ltrim(rtrim([FLD32])), 105)) AS DOCDATE
--INTO ASM_CV_PENDING_ORDER_STG
FROM 
SAP_REPORT_ZBODS_ITEM_DATA PO 
WHERE
TCODE='YOTDR_PENDING_ORD_PROCESS_REP' and
VARIANT='PENDORD3W' AND
PO.FLD16 IN (SELECT DISTINCT KUNNR from SAP_ZSD_DEALER_REPOS Where KATR6='CV')
AND FLD43='F'
Group By
	PO.FLD16,
	PO.FLD22,
	(CONVERT(date, ltrim(rtrim([FLD32])), 105)),
	LEFT(PO.FLD22,6)

--*************************************************

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
        'CV',
        @StartDate_utc1,
        @EndDate_utc1,
		@StartDate_ist1,
        @EndDate_ist1,
        @Duration1,  
        0,
        0,
        @Status1,
        @ErrorMessage1;

TRUNCATE TABLE ASM_CV_BILLING_FACT

INSERT INTO ASM_CV_BILLING_FACT
SELECT * FROM ASM_CV_BILLING_STG
UNION
SELECT * FROM ASM_CV_BILLING_PLAN_STG
UNION 
SELECT * FROM ASM_CV_PENDING_ORDER_STG

--*******************************************************************

--Billing :
  --Step 2:
--Product Master and Dealer Master FK update: ASM_CV_RETAIL_STG
update B set B.FK_SKU=C.PK_SKU from ASM_CV_BILLING_FACT B INNER JOIN ASM_CV_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_CV_BILLING_FACT B INNER JOIN ASM_CV_PRODUCT_DIM C on (B.MODELCODE=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].[ASM_CV_BILLING_FACT] B INNER JOIN ASM_CV_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)


--*********************************** END *******************************************


END
GO