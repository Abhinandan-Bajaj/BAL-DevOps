
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
alter PROC [dbo].[USP_ASM_PB_T_BILLING_REFRESH] AS
BEGIN
--***************************START************************************************
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION				      */
/*--------------------------------------------------------------------------------------------------*/
/*  2025-07-18 	|	Lachmanna		        | Newly Added script for K+T        */
/*  2025-10-07 	|	Lachmanna		        | added ABC code  and applied date casting        */
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
	
--***************************START***********************************

declare @ASMFact_IMPORTEDDATE date;
set @ASMFact_IMPORTEDDATE = CAST((SELECT MAX(DATE) from ASM_PB_T_BILLING_STG)AS DATE);


DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_PB_T_BILLING_REFRESH';

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			@table_name1 VARCHAR(128) = 'ASM_PB_T_BILLING_STG', 
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT,   
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX); 

BEGIN TRY
--1.Billing Stage
INSERT INTO ASM_PB_T_BILLING_STG
SELECT DISTINCT
'0000'+SAP_BILLING.DEALERCODE AS DEALERCODE,
SAP_BILLING.MATERIAL as SKU,
Cast(0 as int) as FK_DEALERCODE,
Cast(0 as int) as FK_SKU,
10003 As FK_TYPE_ID,
SAP_BILLING.DOCDATE AS DATE,
Sum(SAP_BILLING.BILLQTY) as ACTUALQUANTITY,
0 As TARGETQUANTITY,
cast(0 as decimal(19,0)) As PENDING_ORDERS,
getdate() as LASTUPDATEDDATETIME,
SAP_BILLING.MATERIAL,
Case when LEN(SAP_BILLING.MATERIAL)=8  then LEFT(SAP_BILLING.MATERIAL,6)
        when LEN(SAP_BILLING.MATERIAL) IN (6,7) THEN LEFT(SAP_BILLING.MATERIAL,4) 
        when LEN(SAP_BILLING.MATERIAL)=5 THEN LEFT(SAP_BILLING.MATERIAL,3) END  AS MODELCODE,
Cast(0 as int) as FK_MODEL,
100031 As FLAG,
NULL AS TEHSILID,
NULL AS SALESPERSON,
BM.PK_BRANCHID as BRANCHCODE
FROM
   SAP_BILLING 
INNER JOIN COMPANY_MASTER ON ('0000'+SAP_BILLING.DEALERCODE=COMPANY_MASTER.CODE AND --Comented as per req. of Nikita and approval from Adarsh and Kaushik 
COMPANY_MASTER.COMPANYTYPE = 2)

INNER JOIN (
    SELECT *, 
           ROW_NUMBER() OVER (PARTITION BY MODELCODE ORDER BY MODELCODE) AS rnk
    FROM ASM_PB_HKT_PRODUCT_DIM
    WHERE BRAND = 'TRIUMPH'
) PM 
    ON 
    PM.MODELCODE = 
        CASE 
            WHEN LEN(SAP_BILLING.MATERIAL) = 8 THEN LEFT(SAP_BILLING.MATERIAL, 6)
            WHEN LEN(SAP_BILLING.MATERIAL) IN (6, 7) THEN LEFT(SAP_BILLING.MATERIAL, 4)
            WHEN LEN(SAP_BILLING.MATERIAL) = 5 THEN LEFT(SAP_BILLING.MATERIAL, 3)
            ELSE NULL
        END
    AND PM.rnk = 1
Left  JOIN sap_LIKP ON SAP_BILLING.DELIVERY=sap_LIKP.VBELN
Left JOIN ASM_PB_HKT_BRANCH_MASTER_DIM BM on  sap_LIKP.KUNNR=BM.BRANCH_CODE
WHERE --SAP_BILLING.DOCDATE BETWEEN '2025-06-09' AND Cast(Getdate()-1 as date)
cast(SAP_BILLING.DOCDATE as date)> @ASMFact_IMPORTEDDATE
AND [Distr.Chnl] IN ('55') AND DIVISION='B2' AND SAP_BILLING.CANCELLED<>'X'  -- (Change Division,'B2' is for MC)
GROUP BY
    '0000'+SAP_BILLING.DEALERCODE,
    SAP_BILLING.MATERIAL,
    SAP_BILLING.DOCDATE,
    SAP_BILLING.MATERIAL,
	LEFT(SAP_BILLING.MATERIAL,6),BM.PK_BRANCHID


--******************************************************************
--2.Billing Plan Stage
TRUNCATE TABLE ASM_PB_T_BILLING_PLAN_STG

INSERT INTO ASM_PB_T_BILLING_PLAN_STG
SELECT DISTINCT
ZO.DEALERCODE,
ZO.MATERIAL as SKU,
Cast(0 as int) as FK_DEALERCODE,
Cast(0 as int) as FK_SKU,
10003 As FK_TYPE_ID,
ZO.DOCDATE AS DATE,
Cast(0 as decimal(19,0)) as ACTUALQUANTITY,
Sum(ZO.MPSSQTY) As TARGETQUANTITY,
cast(0 as decimal(19,0)) As PENDING_ORDERS,
getdate() as LASTUPDATEDDATETIME,
ZO.MATERIAL,
Case when LEN(ZO.MATERIAL)=8  then LEFT(ZO.MATERIAL,6)
        when LEN(ZO.MATERIAL) IN (6,7) THEN LEFT(ZO.MATERIAL,4) 
        when LEN(ZO.MATERIAL)=5 THEN LEFT(ZO.MATERIAL,3) END  AS MODELCODE,
Cast(0 as int) as FK_MODEL,
100032 As FLAG,
NULL AS TEHSILID,
NULL AS SALESPERSON
FROM 
SAP_ZMPSS_ORDERS ZO
INNER JOIN (
    SELECT *, 
           ROW_NUMBER() OVER (PARTITION BY MODELCODE ORDER BY MODELCODE) AS rnk
    FROM ASM_PB_HKT_PRODUCT_DIM
    WHERE BRAND = 'TRIUMPH'
) PM 
    ON 
    PM.MODELCODE = 
        CASE 
            when LEN(ZO.MATERIAL)=8  then LEFT(ZO.MATERIAL,6)
            when LEN(ZO.MATERIAL) IN (6,7) THEN LEFT(ZO.MATERIAL,4) 
            when LEN(ZO.MATERIAL)=5 THEN LEFT(ZO.MATERIAL,3)
            ELSE NULL
        END
    AND PM.rnk = 1
WHERE 
ZO.DEALERCODE IN (SELECT DISTINCT DEALER.KUNNR from SAP_ZSD_DEALER_REPOS DEALER WHERE DEALER.KATR6='TRM') 
AND  CAST(ZO.DOCDATE AS DATE) BETWEEN '2025-06-09' AND  Cast(Getdate()-1 as date)
Group By
	ZO.DEALERCODE,
	ZO.MATERIAL,
	ZO.DOCDATE,
	LEFT(ZO.MATERIAL,6)

INSERT INTO ASM_PB_T_BILLING_PLAN_STG
SELECT DISTINCT
ZO.DEALERCODE,
ZO.MATERIAL as SKU,
Cast(0 as int) as FK_DEALERCODE,
Cast(0 as int) as FK_SKU,
10003 As FK_TYPE_ID,
ZO.DOCDATE AS DATE,
Cast(0 as decimal(19,0)) as ACTUALQUANTITY,
Sum(ZO.MPSSQTY) As TARGETQUANTITY,
cast(0 as decimal(19,0)) As PENDING_ORDERS,
getdate() as LASTUPDATEDDATETIME,
ZO.MATERIAL,
Case when LEN(ZO.MATERIAL)=8  then LEFT(ZO.MATERIAL,6)
        when LEN(ZO.MATERIAL) IN (6,7) THEN LEFT(ZO.MATERIAL,4) 
        when LEN(ZO.MATERIAL)=5 THEN LEFT(ZO.MATERIAL,3) END  AS MODELCODE,
Cast(0 as int) as FK_MODEL,
100032 As FLAG,
NULL AS TEHSILID,
NULL AS SALESPERSON
FROM 
SAP_ZMPSS_ORDERS ZO
WHERE 
ZO.DEALERCODE IN (SELECT DISTINCT DEALER.KUNNR from SAP_ZSD_DEALER_REPOS DEALER WHERE DEALER.KATR6='TRM') 
AND  CAST(ZO.DOCDATE AS DATE) BETWEEN '2022-04-01' AND  '2025-06-08'
Group By
	ZO.DEALERCODE,
	ZO.MATERIAL,
	ZO.DOCDATE,
	LEFT(ZO.MATERIAL,6)

--**************************************************************************
--3.Pending Orders Stage
TRUNCATE TABLE ASM_PB_T_PENDING_ORDER_STG

INSERT INTO ASM_PB_T_PENDING_ORDER_STG
SELECT DISTINCT
'00000'+PO.SOLDTOPARTY As DEALERCODE,
PO.MATERIAL as SKU,
Cast(0 as int) as FK_DEALERCODE,
Cast(0 as int) as FK_SKU,
10003 As FK_TYPE_ID,
(CONVERT(date, ltrim(rtrim([DOCDATE])), 105)) AS DATE,
Cast(0 as decimal(19,0)) as ACTUALQUANTITY,
cast(0 as decimal(19,0)) As TARGETQUANTITY,
SUM(CAST((PO.ORDQTY) as DECIMAL(19,0))) As PENDING_ORDERS,
getdate() as LASTUPDATEDDATETIME,
PO.MATERIAL,
Case when LEN(PO.MATERIAL)=8  then LEFT(PO.MATERIAL,6)
        when LEN(PO.MATERIAL) IN (6,7) THEN LEFT(PO.MATERIAL,4) 
        when LEN(PO.MATERIAL)=5 THEN LEFT(PO.MATERIAL,3) END   As MODELCODE,
Cast(0 as int) as FK_MODEL,
100033 As FLAG,
NULL AS TEHSILID,
NULL AS SALESPERSON
FROM 
SAP_PENDING_ORDERS PO 
INNER JOIN (
    SELECT *, 
           ROW_NUMBER() OVER (PARTITION BY MODELCODE ORDER BY MODELCODE) AS rnk
    FROM ASM_PB_HKT_PRODUCT_DIM
    WHERE BRAND = 'TRIUMPH'
) PM 
    ON 
    PM.MODELCODE = 
        CASE 
            when LEN(PO.MATERIAL)=8  then LEFT(PO.MATERIAL,6)
            when LEN(PO.MATERIAL) IN (6,7) THEN LEFT(PO.MATERIAL,4) 
            when LEN(PO.MATERIAL)=5 THEN LEFT(PO.MATERIAL,3)
            ELSE NULL
        END
    AND PM.rnk = 1
WHERE 
'00000'+PO.SOLDTOPARTY IN (SELECT DISTINCT DEALER.KUNNR from SAP_ZSD_DEALER_REPOS DEALER WHERE DEALER.KATR6='TRM') 
AND FUND='F' 
AND (CONVERT(date, ltrim(rtrim([DOCDATE])), 105))  BETWEEN '2025-06-09' AND  Cast(Getdate()-1 as date)
Group By
	'00000'+PO.SOLDTOPARTY,
	PO.MATERIAL,
	(CONVERT(date, ltrim(rtrim([DOCDATE])), 105)),
	LEFT(PO.MATERIAL,6)

INSERT INTO ASM_PB_T_PENDING_ORDER_STG
SELECT DISTINCT
'00000'+PO.SOLDTOPARTY As DEALERCODE,
PO.MATERIAL as SKU,
Cast(0 as int) as FK_DEALERCODE,
Cast(0 as int) as FK_SKU,
10003 As FK_TYPE_ID,
(CONVERT(date, ltrim(rtrim([DOCDATE])), 105)) AS DATE,
Cast(0 as decimal(19,0)) as ACTUALQUANTITY,
cast(0 as decimal(19,0)) As TARGETQUANTITY,
SUM(CAST((PO.ORDQTY) as DECIMAL(19,0))) As PENDING_ORDERS,
getdate() as LASTUPDATEDDATETIME,
PO.MATERIAL,
Case when LEN(PO.MATERIAL)=8  then LEFT(PO.MATERIAL,6)
        when LEN(PO.MATERIAL) IN (6,7) THEN LEFT(PO.MATERIAL,4) 
        when LEN(PO.MATERIAL)=5 THEN LEFT(PO.MATERIAL,3) END   As MODELCODE,
Cast(0 as int) as FK_MODEL,
100033 As FLAG,
NULL AS TEHSILID,
NULL AS SALESPERSON
FROM 
SAP_PENDING_ORDERS PO 
WHERE 
'00000'+PO.SOLDTOPARTY IN (SELECT DISTINCT DEALER.KUNNR from SAP_ZSD_DEALER_REPOS DEALER WHERE DEALER.KATR6='TRM') 
AND FUND='F' 
AND (CONVERT(date, ltrim(rtrim([DOCDATE])), 105))  BETWEEN '2022-04-01' AND  '2025-06-08' 
Group By
	'00000'+PO.SOLDTOPARTY,
	PO.MATERIAL,
	(CONVERT(date, ltrim(rtrim([DOCDATE])), 105)),
	LEFT(PO.MATERIAL,6)

--**********************************************************************
--4.Billing Fact
TRUNCATE TABLE ASM_PB_T_BILLING_FACT

INSERT INTO ASM_PB_T_BILLING_FACT
SELECT * FROM ASM_PB_T_BILLING_STG
INSERT INTO ASM_PB_T_BILLING_FACT
SELECT *,NULL FROM ASM_PB_T_BILLING_PLAN_STG
INSERT INTO ASM_PB_T_BILLING_FACT
SELECT *,NULL FROM ASM_PB_T_PENDING_ORDER_STG

--Product Master and Dealer Master FK update: ASM_MC_BILLING_FACT
update B set B.FK_SKU=C.PK_SKU from ASM_PB_T_BILLING_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_PB_T_BILLING_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_DIM C on (B.MODELCODE=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].ASM_PB_T_BILLING_FACT B INNER JOIN ASM_PB_HKT_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)
--******************************************************************************

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
END
GO