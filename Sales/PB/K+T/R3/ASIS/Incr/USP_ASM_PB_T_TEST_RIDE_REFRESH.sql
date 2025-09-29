
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Create PROC [dbo].[USP_ASM_PB_T_TEST_RIDE_REFRESH] AS
BEGIN
	
--***************************START************************************************
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-06-05 	|	Nikita L		| Created for displaying Sales view of Testrides      			*/
/*	2024-10-22 	|	Nikita L		| LSQ-MX_First_Source Addition   
    2024-11-11	|	Richa		| Addition of Sales view of Visited             			        */
/*	2025-03-19 	|	Lachmanna		| First Mode Source and sub source  Addition	                */
/*  2025-07-18 	|	Lachmanna		        | Newly Added script for K+T        */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
------------------------------------------------------------------------------------------------------------------------------------------

INSERT INTO ASM_PB_T_TEST_RIDE_FACT
SELECT 
DEALERCODE,
SKU,
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
DATE,
ENQUIRYLINEID,
FK_ENQUIRYDOCID,
COMPANYTYPE,
BRANCHID,
Isnull(Count(ProspectId),0) as ACTUALQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
CDMS_BATCHNO,
TARGETQUANTITY,
PERIODNAME,
COLOUR_CODE,
MODELCODE,
FK_MODEL,
FLAG,
BaseFlag,
TEHSILID,
SalesPerson,
Leadtype,
First_Source_Lead_Type ,
First_Mode_Source,
First_Mode_SubSource
 from (
SELECT
   DISTINCT
   CM.CODE AS DEALERCODE,
   IM.CODE+IV.CODE As SKU,
   Cast(0 as int) as FK_DEALERCODE,
   Cast(0 as int) as FK_SKU,
   10008 As FK_TYPE_ID,
   Cast(LSQ_TESTRIDE.createdon As Date) As DATE,
   LSQ_TESTRIDE.PROSPECTACTIVITYEXTENSIONID as ENQUIRYLINEID,
   LSQ_PBASE.ProspectID as FK_ENQUIRYDOCID, 
   2 AS COMPANYTYPE,
   BM.BRANCHID as BRANCHID,
   LSQ_PBASE.ProspectId,
   getdate() as LASTUPDATEDDATETIME,
   LSQ_TESTRIDE.Modifiedon AS IMPORTEDDATE,
   null as CDMS_BATCHNO,
   Cast(0 as decimal(19,0)) As TARGETQUANTITY,
   (LEFT(DATENAME( MONTH,LSQ_PEXTBASE.mx_Dealer_Assignment_Date),3)+'-'+Cast(Year(LSQ_PEXTBASE.mx_Dealer_Assignment_Date) as varchar(4))) As PERIODNAME,
   IV.CODE As COLOUR_CODE,
   IM.CODE As MODELCODE,
   Cast(0 as int) as FK_MODEL,
   100011 As FLAG,
   1 as BaseFlag,
   null as TEHSILID,
   null as SalesPerson,
   ISNULL(LSQ_PBASE.mx_Enquiry_Mode,'Not Available') AS LeadType,
   --,CASE WHEN CAST(LSQ_PBASE.CREATEDON AS DATE)>='2024-10-01' THEN LSQ_PBASE.MX_FIRST_SOURCE ELSE COALESCE(LSQ_PBASE.mx_Enquiry_Mode, LSQ_PBASE.MX_MODE_OF_ENQUIRY,'Not Available') END as First_Source_Lead_Type
   CASE WHEN CAST(LSQ_PEXTBASE.mx_Dealer_Assignment_Date AS DATE)>='2024-12-01' THEN COALESCE(PE.mx_Qualified_First_Source, LSQ_PBASE.mx_Enquiry_Mode,LSQ_PBASE.MX_MODE_OF_ENQUIRY,'Not Available')
   ELSE COALESCE(LSQ_PBASE.mx_Enquiry_Mode, LSQ_PBASE.MX_MODE_OF_ENQUIRY,'Not Available') END as First_Source_Lead_Type,
   ISNULL(PE.mx_Qualified_Source_of_Enquiry, 'Not Available')   AS First_Mode_Source,
   ISNULL(PE.mx_Qualified_Sub_Source, 'Not Available') AS First_Mode_SubSource
   FROM
    LSQ_Prospect_Base LSQ_PBASE
 
	INNER JOIN DBO.BRANCH_MASTER BM 
	ON LSQ_PBASE.mx_Branch_Code=BM.CODE
    
	INNER JOIN DBO.COMPANY_MASTER CM 
	ON CM.COMPANYID=BM.COMPANYID
	AND (CM.COMPANYTYPE=2 ) --AND CM.COMPANYSUBTYPE='Triumph')
    
    LEFT JOIN LSQ_Prospect_ExtensionBase LSQ_PEXTBASE
    ON (LSQ_PBASE.ProspectId = LSQ_PEXTBASE.ProspectId) 

    	LEFT JOIN LSQ_Prospect_Extension2Base PE
    ON (LSQ_PBASE.ProspectId = PE.ProspectId) 
    
    INNER JOIN LSQ_ProspectActivity_ExtensionBase LSQ_PACTEXTBASE
    ON (LSQ_PBASE.ProspectId = LSQ_PACTEXTBASE.RelatedProspectID) 
	
	 -------TestRIDE Logic------------------------------------------------------
	LEFT JOIN (select PROSPECTACTIVITYEXTENSIONID,RelatedProspectID ,CREATEDON,Modifiedon, ROW_NUMBER() OVER (PARTITION BY RelatedProspectID ORDER BY createdon DESC) AS RANK1
	from 
	LSQ_ProspectActivity_ExtensionBase 
	where ActivityEvent = 202 AND STATUS='Completed'
	)LSQ_TESTRIDE
	ON LSQ_TESTRIDE.RelatedProspectID=LSQ_PBASE.ProspectId
 
 ----------------------------------------------------------------------------------------------------------------------------------------------
    LEFT JOIN LSQ_CustomObjectProspectActivity_Base LSQ_CUSTPACT
    ON LSQ_CUSTPACT.RelatedProspectActivityID=LSQ_PACTEXTBASE.RelatedProspectActivityID
    AND LSQ_CUSTPACT.CustomObjectProspectActivityId=LSQ_PACTEXTBASE.mx_custom_14
    
    LEFT JOIN ITEM_MASTER IM
    ON cast(IM.ITEMID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_11
    
    LEFT JOIN ITEMVARMATRIX_MASTER IV
    ON cast(IV.ITEMVARMATRIXID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_14

     INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
    ON  PM.Modelcode = IM.Code and PM.BRAND in('TRIUMPH') and rnk = 1

    WHERE LSQ_PACTEXTBASE.ActivityEvent=12002 
	--and LSQ_PEXTBASE.mx_BU_sub_type='TRM'
    AND LSQ_PEXTBASE.mx_Dealer_Assignment_Date  IS NOT NULL
    AND CAST( LSQ_TESTRIDE.CREATEDON AS DATE)  >=cast ((SELECT MAX(IMPORTEDDATE) FROM ASM_PB_T_TEST_RIDE_FACT where FK_TYPE_ID='10008') as date)
  ) TMP
	GROUP BY 
DEALERCODE, SKU,FK_DEALERCODE, FK_SKU,  FK_TYPE_ID,DATE,ENQUIRYLINEID,
 FK_ENQUIRYDOCID,COMPANYTYPE,BRANCHID,LASTUPDATEDDATETIME,IMPORTEDDATE,CDMS_BATCHNO ,TARGETQUANTITY,PERIODNAME
,COLOUR_CODE, MODELCODE, FK_MODEL,FLAG, BaseFlag,TEHSILID,SalesPerson,LeadType,First_Source_Lead_Type,First_Mode_Source,First_Mode_SubSource;


Delete from ASM_PB_T_TEST_RIDE_FACT Where DATE>Cast(Getdate()-1 as date)  ;
--Dedup Process:
WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_ENQUIRYDOCID,ENQUIRYLINEID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_T_TEST_RIDE_FACT                 
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;  
 
 ---------------------------------------------------------------------------------------------
 
update B set B.FK_SKU=C.PK_SKU from ASM_PB_T_TEST_RIDE_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_PB_T_TEST_RIDE_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_DIM C on (B.MODELCODE=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].[ASM_PB_T_TEST_RIDE_FACT] B INNER JOIN ASM_PB_HKT_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)


--------------------------------------Visited Salesview--------------------------

INSERT INTO ASM_PB_T_TEST_RIDE_FACT
SELECT 
DEALERCODE,
SKU,
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
DATE,
ENQUIRYLINEID,
FK_ENQUIRYDOCID,
COMPANYTYPE,
BRANCHID,
Isnull(Count(ProspectId),0) as ACTUALQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
CDMS_BATCHNO,
TARGETQUANTITY,
PERIODNAME,
COLOUR_CODE,
MODELCODE,
FK_MODEL,
FLAG,
BaseFlag,
TEHSILID,
SalesPerson,
Leadtype,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource
from (
SELECT
   DISTINCT
   CM.CODE AS DEALERCODE,
   IM.CODE+IV.CODE As SKU,
   Cast(0 as int) as FK_DEALERCODE,
   Cast(0 as int) as FK_SKU,
   10011 As FK_TYPE_ID,
   Cast(LSQ_PEXTBASE.mx_Enquiry_update_date_and_time as date) As DATE,
   LSQ_PACTEXTBASE.PROSPECTACTIVITYEXTENSIONID as ENQUIRYLINEID,
   LSQ_PBASE.ProspectID as FK_ENQUIRYDOCID, 
   2 AS COMPANYTYPE,
   BM.BRANCHID as BRANCHID,
   LSQ_PBASE.ProspectId,
   getdate() as LASTUPDATEDDATETIME,
   LSQ_PEXTBASE.mx_Enquiry_update_date_and_time AS IMPORTEDDATE,
   null as CDMS_BATCHNO,
   Cast(0 as decimal(19,0)) As TARGETQUANTITY,
   (LEFT(DATENAME( MONTH,LSQ_PEXTBASE.mx_Dealer_Assignment_Date),3)+'-'+Cast(Year(LSQ_PEXTBASE.mx_Dealer_Assignment_Date) as varchar(4))) As PERIODNAME,
   IV.CODE As COLOUR_CODE,
   IM.CODE As MODELCODE,
   Cast(0 as int) as FK_MODEL,
   100011 As FLAG,
   1 as BaseFlag,
   null as TEHSILID,
   null as SalesPerson,
   ISNULL(LSQ_PBASE.mx_Enquiry_Mode,'Not Available') AS LeadType,
   --,CASE WHEN CAST(LSQ_PBASE.CREATEDON AS DATE)>='2024-10-01' THEN LSQ_PBASE.MX_FIRST_SOURCE ELSE COALESCE(LSQ_PBASE.mx_Enquiry_Mode, LSQ_PBASE.MX_MODE_OF_ENQUIRY,'Not Available') END as First_Source_Lead_Type
   CASE WHEN CAST(LSQ_PEXTBASE.mx_Dealer_Assignment_Date AS DATE)>='2024-12-01' THEN COALESCE(PE.mx_Qualified_First_Source, LSQ_PBASE.mx_Enquiry_Mode,LSQ_PBASE.MX_MODE_OF_ENQUIRY,'Not Available')
   ELSE COALESCE(LSQ_PBASE.mx_Enquiry_Mode, LSQ_PBASE.MX_MODE_OF_ENQUIRY,'Not Available') END as First_Source_Lead_Type,
      ISNULL(PE.mx_Qualified_Source_of_Enquiry, 'Not Available')   AS First_Mode_Source,
   ISNULL(PE.mx_Qualified_Sub_Source, 'Not Available') AS First_Mode_SubSource
  
   FROM
    LSQ_Prospect_Base LSQ_PBASE
 
	INNER JOIN DBO.BRANCH_MASTER BM 
	ON LSQ_PBASE.mx_Branch_Code=BM.CODE
    
	INNER JOIN DBO.COMPANY_MASTER CM 
	ON CM.COMPANYID=BM.COMPANYID
	AND (CM.COMPANYTYPE=2 )--AND CM.COMPANYSUBTYPE='Triumph')
    
    LEFT JOIN LSQ_Prospect_ExtensionBase LSQ_PEXTBASE
    ON (LSQ_PBASE.ProspectId = LSQ_PEXTBASE.ProspectId) 
    
    	LEFT JOIN LSQ_Prospect_Extension2Base PE
    ON (LSQ_PBASE.ProspectId = PE.ProspectId) 
    
    INNER JOIN LSQ_ProspectActivity_ExtensionBase LSQ_PACTEXTBASE
    ON (LSQ_PBASE.ProspectId = LSQ_PACTEXTBASE.RelatedProspectID) 
	
 ----------------------------------------------------------------------------------------------------------------------------------------------
    LEFT JOIN LSQ_CustomObjectProspectActivity_Base LSQ_CUSTPACT
    ON LSQ_CUSTPACT.RelatedProspectActivityID=LSQ_PACTEXTBASE.RelatedProspectActivityID
    AND LSQ_CUSTPACT.CustomObjectProspectActivityId=LSQ_PACTEXTBASE.mx_custom_14
    
    LEFT JOIN ITEM_MASTER IM
    ON cast(IM.ITEMID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_11
    
    LEFT JOIN ITEMVARMATRIX_MASTER IV
    ON cast(IV.ITEMVARMATRIXID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_14

     INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
    ON  PM.Modelcode = IM.Code and PM.BRAND in('TRIUMPH') and rnk = 1

    WHERE LSQ_PACTEXTBASE.ActivityEvent=12002 
	--and LSQ_PEXTBASE.mx_BU_sub_type='TRM'
    AND LSQ_PEXTBASE.mx_Dealer_Assignment_Date  IS NOT NULL
    AND CAST( LSQ_PEXTBASE.mx_Enquiry_update_date_and_time as date)  >=cast ((SELECT ISNULL(MAX(IMPORTEDDATE), '2023-04-01') FROM ASM_PB_T_TEST_RIDE_FACT where FK_TYPE_ID='10011') as date)
  ) TMP
	GROUP BY 
DEALERCODE, SKU,FK_DEALERCODE, FK_SKU,  FK_TYPE_ID,DATE,ENQUIRYLINEID,
 FK_ENQUIRYDOCID,COMPANYTYPE,BRANCHID,LASTUPDATEDDATETIME,IMPORTEDDATE,CDMS_BATCHNO ,TARGETQUANTITY,PERIODNAME
,COLOUR_CODE, MODELCODE, FK_MODEL,FLAG, BaseFlag,TEHSILID,SalesPerson,LeadType,First_Source_Lead_Type,First_Mode_Source,First_Mode_SubSource;


Delete from ASM_PB_T_TEST_RIDE_FACT Where DATE>Cast(Getdate()-1 as date)  ;
--Dedup Process:
WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_ENQUIRYDOCID,ENQUIRYLINEID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_T_TEST_RIDE_FACT where FK_TYPE_ID='10011'              
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;  
 
 ---------------------------------------------------------------------------------------------
 
update B set B.FK_SKU=C.PK_SKU from ASM_PB_T_TEST_RIDE_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
where FK_TYPE_ID='10011' 
update B set B.FK_MODEL=C.PK_Model_Code from ASM_PB_T_TEST_RIDE_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_DIM C on (B.MODELCODE=C.MODELCODE)
where FK_TYPE_ID='10011' 
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].[ASM_PB_T_TEST_RIDE_FACT] B INNER JOIN ASM_PB_HKT_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)
where FK_TYPE_ID='10011' 


END 
GO
