GO
SET QUOTED_IDENTIFIER ON
GO
alter PROC [dbo].[USP_ASM_PB_HKT_MASTER_REFRESH] AS
BEGIN
--***************************START************************************************
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2025-08-19	|	 Lachman		|  Branch logic has been updated to include inactive Dealer that are not present in the Vehicle Mapping table */
/*  2025-09-25 	|	Lachmanna		        | Branch logic has been updated to Excluded inactive branches CR      */
/*  2025-09-25 	|	Lachmanna		        | Branch logic has been updated to Excluded inactive branches CR      */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
--******************************* START ******************************************
-- Dimensions:
--select count(1) from ASM_PB_PRODUCT_SKU_DIM--175
--1. ASM_PB_PRODUCT_SKU_DIM
TRUNCATE TABLE ASM_PB_HKT_PRODUCT_SKU_DIM
INSERT INTO ASM_PB_HKT_PRODUCT_SKU_DIM
SELECT  DISTINCT
        B.MATNR AS SKU_CODE,
		COALESCE(A.ZBRAND_MODEL_VAR,A.ZMKDT_MODEL) as Model,
        B.MAKTX AS Model_Description,
        C.BEZEI AS Colour,
        getdate() as CREATEDATETIME
        --INTO ASM_PB_HKT_PRODUCT_SKU_DIM
FROM SAP_ZBRAND_V_DETAIL A JOIN SAP_MAKT B 
ON A.ZBRANDVARIANT=SUBSTRING(B.MATNR,3,4) and 
B.MATNR LIKE '00%'
JOIN SAP_TVM2T C ON (Right(B.MATNR,2)=C.MVGR2)
WHERE A.ZBU_TYPE in( 'PB','PBK') and  A.ZBRAND1 <> 'TRIUMPH'

Union ALL

SELECT  DISTINCT
        B.MATNR AS SKU_CODE,
		A.ZMKDT_MODEL  Model,
        B.MAKTX AS Model_Description,
        C.BEZEI AS Colour,
        getdate() as CREATEDATETIME
        --INTO ASM_TRIUMPH_PRODUCT_SKU_DIM
FROM SAP_ZBRAND_V_DETAIL A JOIN SAP_MAKT B 
ON A.ZBRANDVARIANT=  (CASE WHEN LEN(MATNR)=8 THEN SUBSTRING(MATNR,3,4) 
                         WHEN LEN(MATNR)=7 THEN CONCAT(0, SUBSTRING(MATNR,1,3)) 
					  WHEN LEN(MATNR)=5 THEN CONCAT(0, SUBSTRING(MATNR,1,3)) END) 
--and B.MATNR LIKE '00%'
JOIN SAP_TVM2T C -- ON (Right(B.MATNR,2)=C.MVGR2)
ON (C.MVGR2= CASE WHEN  LEN(B.MATNR)=7 THEN RIGHT(B.MATNR,3) ELSE RIGHT(B.MATNR,2) END) --change to accomodate 3 letter color in 7 letter modelcode
WHERE A.ZBU_TYPE = 'PB' AND A.ZBRAND1='TRIUMPH'

--***********************************************************************************
--2. ASM_PB_PRODUCT_DIM
--select count(1) from ASM_PB_PRODUCT_DIM--175
	TRUNCATE TABLE ASM_PB_HKT_PRODUCT_DIM
	INSERT INTO ASM_PB_HKT_PRODUCT_DIM
	SELECT DISTINCT
	    CASE 
	        WHEN B.MATNR LIKE '00%' THEN LEFT(B.MATNR, 6)
	        WHEN B.MATNR LIKE 'F%' THEN LEFT(B.MATNR, 7)--- as suggested by SUSMIT F MODEL codes are included 
	    END AS ModelCode,
	    COALESCE(A.ZBRAND_MODEL_VAR, A.ZMKDT_MODEL) AS Model,
	    B.MAKTX AS Model_Description,
	    A.ZPRESUCC_STATUS AS Mono_BI_Fuel,
	    A.ZSUB_BRD AS Subcategory,
	    --A.VARIANT AS Category,
        A.ZCATEGORY as Category,   ---- As suggested by Susmit and Adharsh, a new model grouping has been added
	    A.ZSEGMENT AS Segment,
	    A.ZBRAND1 AS Brand,
	    A.MODEL_ACTIVATION AS Primary_Usage,
	    GETDATE() AS CREATEDATETIME --   INTO ASM_PB_HKT_PRODUCT_DIM
	FROM SAP_ZBRAND_V_DETAIL A 
	JOIN SAP_MAKT B 
	    ON A.ZBRANDVARIANT = SUBSTRING(B.MATNR, 3, 4)
	WHERE 
	    A.ZBU_TYPE IN ('PB', 'PBK')
    AND (B.MATNR LIKE '00%' OR B.MATNR LIKE 'F%')
    and  A.ZBRAND1 <> 'TRIUMPH'

	UNION ALL

	SELECT  DISTINCT
        Case when LEN(B.MATNR)=8  then LEFT(B.MATNR,6)
        when LEN(B.MATNR) IN (6,7) THEN LEFT(B.MATNR,4) 
        when LEN(B.MATNR)=5 THEN LEFT(B.MATNR,3) END  AS ModelCode,
        A.ZMKDT_MODEL as Model,
	    B.MAKTX AS Model_Description,
        A.ZPRESUCC_STATUS as Mono_BI_Fuel,
        A.ZSUB_BRD AS Subcategory,
        --A.VARIANT AS Category,
         A.ZCATEGORY as Category,   ---- As suggested by Susmit and Adharsh, a new model grouping has been added
        A.ZSEGMENT as Segment,
        A.ZBRAND1 as Brand,
        A.MODEL_ACTIVATION as Primary_Usage,
        getdate() as CREATEDATETIME
        --INTO ASM_TRIUMPH_PRODUCT_DIM
FROM SAP_ZBRAND_V_DETAIL A 
JOIN SAP_MAKT B ON A.ZBRANDVARIANT=(CASE WHEN LEN(MATNR)=8 THEN SUBSTRING(MATNR,3,4) 
                         WHEN LEN(MATNR)=7 THEN CONCAT(0, SUBSTRING(MATNR,1,3)) 
					  WHEN LEN(MATNR)=5 THEN CONCAT(0, SUBSTRING(MATNR,1,3)) END) 
--and B.MATNR LIKE '00%'
WHERE A.ZBU_TYPE = 'PB' AND A.ZBRAND1='TRIUMPH';


--*************************************************************************************
--3.ASM_PB_DEALER_MASTER_DIM
--select count(1) from ASM_PB_DEALER_MASTER_DIM--393

TRUNCATE TABLE ASM_PB_HKT_DEALER_MASTER_DIM
INSERT INTO ASM_PB_HKT_DEALER_MASTER_DIM
SELECT
    Distinct
    KUNNR  As DEALERCODE,
    NAME1 As DEALERNAME,
	VTEXT1 As REGION,
	HUB as HUB, 
    CIRCLE As CIRCLE,
	CITY1 As CITY,
	REGIO AS [STATE],
	Cast(BEZEI As varchar(100)) As STATE_NAME,
    getdate() as CREATEDDATETIME
	--INTO ASM_PB_HKT_DEALER_MASTER_DIM
FROM
SAP_ZSD_DEALER_REPOS
Where 
KATR6 IN('PB', 'TRM')  and KUNNR<'0000015000'

Union ALL

SELECT
    Distinct
    KUNNR  As DEALERCODE,
    NAME1 As DEALERNAME,
	VTEXT1 As REGION,
	CASE WHEN SAL_HUB='' THEN HUB ELSE SAL_HUB END AS HUB ,
    CIRCLE As CIRCLE,
	CITY1 As CITY,
	REGIO AS [STATE],
	Cast(BEZEI As varchar(100)) As STATE_NAME,
    getdate() as CREATEDDATETIME
	--INTO ASM_TRIUMPH_DEALER_MASTER_DIM
FROM
SAP_ZSD_DEALER_REPOS DEALER
--JOIN COMPANY_MASTER CM ON CM.CODE=DEALER.KUNNR --Added comment as per request of Nikita and approval of AdarshB and KaushiA
--AND CM.COMPANYTYPE=2 AND COMPANYSUBTYPE='Triumph'
Where KATR6 IN ('TRM','PB')

;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY DEALERCODE ORDER BY DEALERCODE, HUB DESC)RNK                   
  FROM ASM_PB_HKT_DEALER_MASTER_DIM                
 )                  
delete FROM CTE              
 WHERE RNK<>1; 

--**************************************************************************************
TRUNCATE TABLE ASM_PB_HKT_BRANCH_MASTER_DIM
INSERT INTO ASM_PB_HKT_BRANCH_MASTER_DIM --( [PK_BRANCHID],[BRANCH_CODE],[BRANCH_NAME],[PRODUCT_GROUP] )
select * from
(
SELECT 									  
    DISTINCT 							  
    BM.BRANCHID AS PK_BRANCHID,			  
    BM.CODE AS BRANCH_CODE,
    BM.NAME AS BRANCH_NAME,
	NULL as aa,
	NULL as bb,
	CASE 
        WHEN PMAP.KTM = 1 AND PMAP.TRM = 1 THEN 'K+T'
        WHEN PMAP.KTM = 1 THEN 'K'
        WHEN PMAP.TRM = 1 THEN 'T'
		WHEN CM.COMPANYTYPE = 2 AND CM.COMPANYSUBTYPE is null and CM.ISACTIVE=0  THEN 'K'  -- Added to include inactive branchs 
        ELSE 'None'
    END AS PRODUCT_GROUP  --into select* from ASM_PB_HKT_BRANCH_MASTER_DIM
FROM BRANCH_MASTER BM 
LEFT JOIN CDMS_BRANCH_PRODUCT_MAPPING_VEHICLE CBM ON BM.BRANCHID= CBM.BRANCHID
-- Join the Pivoted logic as a derived table or CTE-style inline join
LEFT JOIN (
    SELECT 
        BRANCHID,
        MAX(CASE WHEN ProductType IN ('KTM', 'Husqvarna') THEN 1 ELSE 0 END) AS KTM,
        MAX(CASE WHEN ProductType = 'Triumph' THEN 1 ELSE 0 END) AS TRM
    FROM CDMS_BRANCH_PRODUCT_MAPPING_VEHICLE where IsActive=1 and Module='Sales'
    GROUP BY BRANCHID
) AS PMap ON PMap.BRANCHID = BM.BRANCHID
JOIN COMPANY_MASTER CM 
ON CM.COMPANYID = BM.COMPANYID 
AND (CM.COMPANYTYPE = 2 )--AND CM.COMPANYSUBTYPE is null)
AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND BM.IMPORTEDDATE = (SELECT MAX(BM1.IMPORTEDDATE) FROM BRANCH_MASTER BM1 WHERE BM.BRANCHID = BM1.BRANCHID)
) A where  PRODUCT_GROUP<> 'None'


UNION ALL
select * from (
SELECT 
    DISTINCT 
    BM.BRANCHID AS PK_BRANCHID,
    BM.CODE AS BRANCH_CODE,
    BM.NAME AS BRANCH_NAME,
    CM.CITYID AS BRANCH_CITYID,
  COALESCE(CON.CITYNAME, AM1.NAME,AM2.NAME ) AS BRANCH_CITY_NAME,
	CASE 
        WHEN PMAP.KTM = 1 AND PMAP.TRM = 1 THEN 'K+T'
        WHEN PMAP.KTM = 1 THEN 'K'
        WHEN PMAP.TRM = 1 THEN 'T'
		WHEN CM.COMPANYTYPE = 2 AND CM.COMPANYSUBTYPE='Triumph' and CM.ISACTIVE=0  THEN 'T'  -- Added to include inactive branchs 
        ELSE 'None'
    END AS PRODUCT_GROUP
FROM BRANCH_MASTER BM 
LEFT JOIN CDMS_BRANCH_PRODUCT_MAPPING_VEHICLE CBM ON BM.BRANCHID= CBM.BRANCHID
-- Join the Pivoted logic as a derived table or CTE-style inline join
LEFT JOIN (
    SELECT 
        BRANCHID,
        MAX(CASE WHEN ProductType IN ('KTM', 'Husqvarna') THEN 1 ELSE 0 END) AS KTM,
        MAX(CASE WHEN ProductType = 'Triumph' THEN 1 ELSE 0 END) AS TRM
    FROM CDMS_BRANCH_PRODUCT_MAPPING_VEHICLE where IsActive=1 and Module='Sales'
    GROUP BY BRANCHID
) AS PMap ON PMap.BRANCHID = BM.BRANCHID
	JOIN COMPANY_MASTER CM 
	ON CM.COMPANYID = BM.COMPANYID AND (CM.COMPANYTYPE = 2)-- AND CM.COMPANYSUBTYPE='Triumph') 
	LEFT JOIN (SELECT CONTACTID,CITYID,CITYNAME ,ROW_NUMBER() OVER (PARTITION BY CONTACTID ORDER BY IMPORTEDDATE DESC) RNK  FROM CONTACT_MASTER) CON 
	ON CON.CONTACTID=BM.CONTACTID
    AND CON.RNK=1
	LEFT JOIN AREA_MASTER AM1 
	ON  CON.CITYID= AM1.AREAMASTERID
	LEFT JOIN CONTACT_ADDRESS CON_ADD 
	ON BM.CONTACTID=CON_ADD.CONTACTID
	LEFT JOIN AREA_MASTER AM2 
	ON CON_ADD.CITYID=AM2.AREAMASTERID
	WHERE CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
	AND BM.IMPORTEDDATE = (SELECT MAX(BM1.IMPORTEDDATE) FROM BRANCH_MASTER BM1 WHERE BM.BRANCHID = BM1.BRANCHID)
	) B where  PRODUCT_GROUP<> 'None'

;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_BRANCHID ORDER BY PK_BRANCHID, BRANCH_CITYID DESC)RNK                   
  FROM ASM_PB_HKT_BRANCH_MASTER_DIM                
 )                  
delete FROM CTE              
 WHERE RNK<>1; 

--****************************************************************************************

End
GO
