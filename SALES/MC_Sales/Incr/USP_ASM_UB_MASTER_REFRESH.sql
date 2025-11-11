SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_UB_MASTER_REFRESH] AS
--***********************************************************************************************************************

/********************************************HISTORY********************************************/
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/
/*  DATE       |  CREATED BY/MODIFIED BY |              CHANGE DESCRIPTION                     */
/*---------------------------------------------------------------------------------------------*/
/*  27/05/2024 |  Sarvesh Kulkarni            |            Added dealer ageing in dealerdim table               */
/*  27/06/2024 |  Nikita Lakhimale            |            Urbanite + MC Dealers entries inclusion               */
/*  27/07/2024 |  Nikita Lakhimale            |            Branch typeofoutlet and branchtype addition                */
/*  08/08/2025 |  Ashwini Ahire            |     Added CityCode and Kregion and BU for dealermaster */
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/
/********************************************HISTORY********************************************/

--******************************* START ******************************************
-- Dimensions:
--1. ASM_UB_PRODUCT_SKU_DIM
TRUNCATE TABLE ASM_UB_PRODUCT_SKU_DIM
INSERT INTO ASM_UB_PRODUCT_SKU_DIM
SELECT  DISTINCT
        B.MATNR AS SKU_CODE,
		A.BU_CATEGORY as Model,
        B.MAKTX AS Model_Description,
        C.BEZEI AS Colour,
        getdate() as CREATEDATETIME
        --INTO ASM_UB_PRODUCT_SKU_DIM
FROM SAP_ZBRAND_V_DETAIL A JOIN SAP_MAKT B ON A.ZBRANDVARIANT=SUBSTRING(B.MATNR,3,4) and B.MATNR LIKE '00%'
JOIN SAP_TVM2T C ON (Right(B.MATNR,2)=C.MVGR2)
WHERE A.ZBU_TYPE IN ( 'UB','URB')
--***********************************************************************************
--2. ASM_UB_PRODUCT_DIM
TRUNCATE TABLE ASM_UB_PRODUCT_DIM
INSERT INTO ASM_UB_PRODUCT_DIM
SELECT  DISTINCT
        LEFT(B.MATNR,6) AS ModelCode,
        A.BU_CATEGORY as Model,
	    B.MAKTX AS Model_Description,
        A.ZPRESUCC_STATUS as Mono_BI_Fuel,
        A.ZSUB_BRD AS Subcategory,
        A.VARIANT AS Category,
        A.ZSEGMENT as Segment,
        A.ZBRAND1 as Brand,
        A.MODEL_ACTIVATION as Primary_Usage,
        getdate() as CREATEDATETIME
        --INTO ASM_UB_PRODUCT_DIM
FROM SAP_ZBRAND_V_DETAIL A JOIN SAP_MAKT B ON A.ZBRANDVARIANT=SUBSTRING(B.MATNR,3,4) and B.MATNR LIKE '00%'
WHERE 
A.ZBU_TYPE IN ( 'UB','URB')
--************************************************************************************

--3.ASM_UB_DEALER_MASTER_DIM

select
'0000'+SAP_BILLING.DEALERCODE AS DEALERCODE,
min(SAP_BILLING.DOCDATE) AS first_billing_date
into #temp_billing_data
FROM
   SAP_BILLING 
WHERE [Distr.Chnl] IN ('65') AND DIVISION='B2' AND SAP_BILLING.CANCELLED<>'X'  
group by '0000'+SAP_BILLING.DEALERCODE

Print('Dataloaded in #temp_billing_data for dealerage calculation')


TRUNCATE TABLE ASM_UB_DEALER_MASTER_DIM
INSERT INTO ASM_UB_DEALER_MASTER_DIM
SELECT
    Distinct
    A.KUNNR  As DEALERCODE,
    a.NAME1 As DEALERNAME,
	a.VTEXT1 As REGION,
	a.HUB as HUB, 
    a.CIRCLE As CIRCLE,
	a.CITY1 As CITY,
	a.REGIO AS [STATE],
	Cast(a.BEZEI As varchar(100)) As STATE_NAME,
    getdate() as CREATEDDATETIME,
	b.[first_billing_date],
    datediff(day,b.[first_billing_date],getdate()) as dealer_age,
    CASE
        When  datediff(day,b.[first_billing_date],getdate())<=90 THEN '0-3 Months'
        When  datediff(day,b.[first_billing_date],getdate())<=180 THEN '3-6 Months'
        When  datediff(day,b.[first_billing_date],getdate())<=366 THEN '6-12 Months'
        When  datediff(day,b.[first_billing_date],getdate())>366 THEN '>12 Months'
		else 'Not Billed'
    end as dealer_ageing_bucket,
	K.CityC AS CityCode,
    K.Regio AS KREGION,
    a.KATR6 AS BU
	--INTO ASM_UB_DEALER_MASTER_DIM
FROM
SAP_ZSD_DEALER_REPOS a
LEFT JOIN SAP_CUSTOMER_MASTER_KNA1 K on a.KUNNR = K.KUNNR
LEFT JOIN #temp_billing_data b
ON  A.KUNNR = b.DEALERCODE
Where 
a.KATR6='URB'  
--and KUNNR<'0000015000'

Print('Dataloaded in ASM_UB_DEALER_MASTER_DIM')

--************************************************************************************
--4.ASM_UB_BRANCH_MASTER_DIM
TRUNCATE TABLE ASM_UB_BRANCH_MASTER_DIM

INSERT INTO ASM_UB_BRANCH_MASTER_DIM
SELECT 
    DISTINCT 
    BM.BRANCHID AS PK_BRANCHID,
    BM.CODE AS BRANCH_CODE,
    BM.NAME AS BRANCH_NAME,
	ISNULL(BM.TypeOfOutlet,'Others') AS [TypeOfChannel],
	CASE WHEN BM.CHANNEL=1 Then 'Rural' WHEN BM.CHANNEL=2 Then 'Urban' ELSE 'Other' END As BRANCHTYPE
FROM BRANCH_MASTER BM 
JOIN COMPANY_MASTER CM 
ON CM.COMPANYID = BM.COMPANYID AND CM.COMPANYTYPE = 10 
AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND BM.IMPORTEDDATE = (SELECT MAX(BM1.IMPORTEDDATE) FROM BRANCH_MASTER BM1 WHERE BM.BRANCHID = BM1.BRANCHID)

---
TRUNCATE TABLE ASM_UB_SALESPERSON_MASTER

INSERT INTO ASM_UB_SALESPERSON_MASTER
SELECT DISTINCT USERID AS PK_SALESPERSONID,
REPLACE(REPLACE(REPLACE(REPLACE(UPPER(FIRSTNAME),CHAR(160),''),' ',' |'),'| ',''),' |',' ') AS SALESPERSON_NAME,
[Role] AS DESIGNATION,
LastCheckedOn AS LAST_LOGIN_DATETIME
FROM LSQ_UB_USERS

Drop table #temp_billing_data;
--****************************************************************************************
GO