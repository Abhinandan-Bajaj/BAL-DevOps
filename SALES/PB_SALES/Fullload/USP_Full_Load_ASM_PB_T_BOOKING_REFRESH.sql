/****** Object:  StoredProcedure [dbo].[USP_Full_Load_ASM_PB_T_BOOKING_REFRESH]    Script Date: 6/23/2024 11:22:40 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Alter PROC [dbo].[USP_Full_Load_ASM_PB_T_BOOKING_REFRESH] AS
BEGIN
--***************************START*****************************
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION				                        	*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-06-21 	|	Lachmanna L		| Added sales person to Booking  Fact Table            */
/*	2024-09-23 	|	Nikita Lakhimale		| First Source Lead Type Addition	*/
/*	2025-03-19 	|	Lachmanna		| First Mode Source and sub source  Addition	*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
--1. Booking Dim:
--Select count(*) from ASM_PB_T_BOOKING_DIM

Truncate table ASM_PB_T_BOOKING_DIM
Truncate table ASM_PB_T_BOOKING_FACT


INSERT INTO ASM_PB_T_BOOKING_DIM
SELECT DISTINCT
BOOKING_HEADER.HEADERID AS PK_BOOKINGHEADERID,
CAST(BOOKING_HEADER.DOCDATE AS DATE) AS BOOKINGDATE,
BOOKING_HEADER.STATUS AS [BOOKING STATUS],
'' AS BOOKINGDAYSBUCKET,
GETDATE() AS CREATEDDATETIME,
BOOKING_HEADER.IMPORTEDDATE,
BOOKING_HEADER.CDMS_BATCHNO
--INTO ASM_PB_T_BOOKING_DIM
FROM BOOKING_HEADER 
LEFT JOIN BOOKING_LINE BL ON (BOOKING_HEADER.HEADERID=BL.HEADERID)
JOIN ITEM_MASTER IM ON (IM.ItemId=BL.ItemID)
--newly added code for test<
INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND in('TRIUMPH') and rnk = 1
--newly added code for test>
INNER JOIN COMPANY_MASTER ON (BOOKING_HEADER.COMPANYID=COMPANY_MASTER.COMPANYID 
AND (COMPANY_MASTER.COMPANYTYPE = 2 ))-- AND COMPANY_MASTER.COMPANYSUBTYPE='Triumph' ))
WHERE 
CAST(BOOKING_HEADER.DOCDATE AS DATE) between '2025-06-09' AND Cast(Getdate()-1 as date)  and 
--BOOKING_HEADER.STATUS = 'Open' AND 
BOOKING_HEADER.DOCTYPE=1000050
--AND BOOKING_HEADER.IMPORTEDDATE>(SELECT MAX(IMPORTEDDATE) FROM ASM_PB_T_BOOKING_DIM)

INSERT INTO ASM_PB_T_BOOKING_DIM
SELECT DISTINCT
BOOKING_HEADER.HEADERID AS PK_BOOKINGHEADERID,
CAST(BOOKING_HEADER.DOCDATE AS DATE) AS BOOKINGDATE,
BOOKING_HEADER.STATUS AS [BOOKING STATUS],
'' AS BOOKINGDAYSBUCKET,
GETDATE() AS CREATEDDATETIME,
BOOKING_HEADER.IMPORTEDDATE,
BOOKING_HEADER.CDMS_BATCHNO
--INTO ASM_TRIUMPH_BOOKING_DIM
FROM BOOKING_HEADER 
INNER JOIN COMPANY_MASTER ON (BOOKING_HEADER.COMPANYID=COMPANY_MASTER.COMPANYID 
AND (COMPANY_MASTER.COMPANYTYPE = 2  AND COMPANY_MASTER.COMPANYSUBTYPE='Triumph' ))
WHERE 
CAST(BOOKING_HEADER.DOCDATE AS DATE) between '2022-04-01' AND '2025-06-08'  and 
--BOOKING_HEADER.STATUS = 'Open' AND 
BOOKING_HEADER.DOCTYPE=1000050
--AND BOOKING_HEADER.IMPORTEDDATE>(SELECT MAX(IMPORTEDDATE) FROM ASM_TRIUMPH_BOOKING_DIM)

Delete from ASM_PB_T_BOOKING_DIM Where Cast(BOOKINGDATE as Date)>Cast(Getdate()-1 as date)

--Dedup Process
;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_BOOKINGHEADERID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_T_BOOKING_DIM                  
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;
--*************************************************************************
--2. Booking Fact:
--Select count(*) from ASM_PB_T_BOOKING_FACT
--Truncate table ASM_PB_T_BOOKING_FACT
INSERT INTO ASM_PB_T_BOOKING_FACT
SELECT
DISTINCT 
CM.CODE AS DEALERCODE,
IM.CODE+IV.CODE As SKU,
Cast(0 as int) AS FK_DealerCode,
Cast(0 as int) AS FK_SKU,
10006 AS FK_TYPE_ID,
CAST(BH.DOCDATE AS DATE) AS DATE,
BL.LINEID AS BookingLineID,
BL.HEADERID AS FK_BookingDocID,
CM.COMPANYTYPE AS COMPANYTYPE,
BH.BRANCHID,
COUNT(BH.HEADERID) AS ACTUALQUANTITY,
getdate() AS LASTUPDATEDDATETIME,
BH.IMPORTEDDATE,
IM.CODE As MODEL,
Cast(0 as int) As FK_MODEL,
Cast(0 As decimal(19,0)) As FLAG,
CAST (Null AS VARCHAR(10)) as TEHSILID,
REPLACE(REPLACE(REPLACE(REPLACE(UPPER(LSQ_User.Firstname),CHAR(160),''),' ',' |'),'| ',''),' |',' ') as SalesPerson,
ISNULL(COALESCE(EH.LEADTYPE,LSQ_PBASE.mx_Enquiry_Mode),'Not Available') as LeadType, 
CASE WHEN CAST(PE.MX_dEALER_ASSIGNMENT_DATE AS DATE)>='2024-12-01' THEN COALESCE(EH.LEADTYPE,PE2.mx_Qualified_First_Source) END  AS First_Source_Lead_Type,
ISNULL(PE2.mx_Qualified_Source_of_Enquiry, 'Not Available')   AS First_Mode_Source,
ISNULL(PE2.mx_Qualified_Sub_Source, 'Not Available') AS First_Mode_SubSource
--INTO ASM_PB_T_BOOKING_FACT
FROM
BOOKING_HEADER BH 
INNER JOIN COMPANY_MASTER CM 
ON (BH.COMPANYID=CM.COMPANYID 
AND (CM.COMPANYTYPE =2 ))-- AND CM.COMPANYSUBTYPE='Triumph' ))
INNER JOIN BOOKING_LINE BL ON (BH.HEADERID=BL.HEADERID)
JOIN ITEM_MASTER IM ON (IM.ItemId=BL.ItemID)
--newly added code for test<
INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND in('TRIUMPH') and rnk = 1
--newly added code for test>
LEFT JOIN RETAIL_LINE RL ON (BL.LINEID=RL.BOOKINGDATALINEID)
LEFT JOIN ITEMVARMATRIX_MASTER IV ON (RL.VARMATRIXID=IV.ITEMVARMATRIXID)
LEFT JOIN BOOKING_HEADER_EXT BHE ON BH.HEADERID = BHE.HEADERID
LEFT JOIN ENQUIRY_LINE EL ON EL.LINEID = BL.ENQUIRYDATALINEID
LEFT JOIN ENQUIRY_HEADER EH ON EH.HEADERID = EL.DOCID
LEFT JOIN LSQ_ProspectActivity_ExtensionBase PAE ON (Cast(PAE.RelatedProspectId+','+PAE.ProspectActivityExtensionId as varchar(8000))=BHE.LMSBOOKINGID) and PAE.ActivityEvent=12002 and PAE.mx_Custom_48 IS NULL
LEFT JOIN LSQ_Prospect_Base LSQ_PBASE ON (LSQ_PBASE.ProspectID=PAE.RelatedProspectId)
LEFT JOIN LSQ_users LSQ_User  on LSQ_PBASE.OwnerId=LSQ_User.UserId
LEFT JOIN LSQ_Prospect_ExtensionBase PE ON (PE.ProspectID=LSQ_PBASE.ProspectID)
LEFT JOIN LSQ_Prospect_Extension2Base PE2 ON (PE2.ProspectID=LSQ_PBASE.ProspectID)
WHERE 
CAST(BH.DOCDATE AS DATE) BETWEEN '2025-06-09' AND Cast(Getdate()-1 as date)  AND 
BH.DOCTYPE=1000050
--AND BH.IMPORTEDDATE >(SELECT MAX(IMPORTEDDATE) FROM ASM_PB_T_BOOKING_FACT)
GROUP BY
CM.CODE,
IM.CODE+IV.CODE,
CAST(BH.DOCDATE AS DATE),
BL.LINEID,
BL.HEADERID,
CM.COMPANYTYPE,
BH.BRANCHID,
BH.IMPORTEDDATE,
IM.CODE,
EH.LEADTYPE,
LSQ_PBASE.mx_Enquiry_Mode,
LSQ_User.Firstname,
LSQ_PBASE.MX_MODE_OF_ENQUIRY,
PE2.mx_Qualified_First_Source,
CAST(PE.MX_dEALER_ASSIGNMENT_DATE AS DATE),
PE2.mx_Qualified_Source_of_Enquiry,
PE2.mx_Qualified_Sub_Source

INSERT INTO ASM_PB_T_BOOKING_FACT
SELECT
DISTINCT 
CM.CODE AS DEALERCODE,
IM.CODE+IV.CODE As SKU,
Cast(0 as int) AS FK_DealerCode,
Cast(0 as int) AS FK_SKU,
10006 AS FK_TYPE_ID,
CAST(BH.DOCDATE AS DATE) AS DATE,
BL.LINEID AS BookingLineID,
BL.HEADERID AS FK_BookingDocID,
CM.COMPANYTYPE AS COMPANYTYPE,
BH.BRANCHID,
COUNT(BH.HEADERID) AS ACTUALQUANTITY,
getdate() AS LASTUPDATEDDATETIME,
BH.IMPORTEDDATE,
IM.CODE As MODEL,
Cast(0 as int) As FK_MODEL,
Cast(0 As decimal(19,0)) As FLAG,
CAST (Null AS VARCHAR(10)) as TEHSILID,
REPLACE(REPLACE(REPLACE(REPLACE(UPPER(LSQ_User.Firstname),CHAR(160),''),' ',' |'),'| ',''),' |',' ') as SalesPerson,
ISNULL(COALESCE(EH.LEADTYPE,LSQ_PBASE.mx_Enquiry_Mode),'Not Available') as LeadType, 
CASE WHEN CAST(PE.MX_dEALER_ASSIGNMENT_DATE AS DATE)>='2024-12-01' THEN COALESCE(EH.LEADTYPE,PE2.mx_Qualified_First_Source) END  AS First_Source_Lead_Type,
ISNULL(PE2.mx_Qualified_Source_of_Enquiry, 'Not Available')   AS First_Mode_Source,
ISNULL(PE2.mx_Qualified_Sub_Source, 'Not Available') AS First_Mode_SubSource
--INTO ASM_TRIUMPH_BOOKING_FACT
FROM
BOOKING_HEADER BH 
INNER JOIN COMPANY_MASTER CM 
ON (BH.COMPANYID=CM.COMPANYID 
AND (CM.COMPANYTYPE =2  AND CM.COMPANYSUBTYPE='Triumph' ))
INNER JOIN BOOKING_LINE BL ON (BH.HEADERID=BL.HEADERID)
JOIN ITEM_MASTER IM ON (IM.ItemId=BL.ItemID)
LEFT JOIN RETAIL_LINE RL ON (BL.LINEID=RL.BOOKINGDATALINEID)
LEFT JOIN ITEMVARMATRIX_MASTER IV ON (RL.VARMATRIXID=IV.ITEMVARMATRIXID)
LEFT JOIN BOOKING_HEADER_EXT BHE ON BH.HEADERID = BHE.HEADERID
LEFT JOIN ENQUIRY_LINE EL ON EL.LINEID = BL.ENQUIRYDATALINEID
LEFT JOIN ENQUIRY_HEADER EH ON EH.HEADERID = EL.DOCID
LEFT JOIN LSQ_ProspectActivity_ExtensionBase PAE ON (Cast(PAE.RelatedProspectId+','+PAE.ProspectActivityExtensionId as varchar(8000))=BHE.LMSBOOKINGID) and PAE.ActivityEvent=12002 and PAE.mx_Custom_48 IS NULL
LEFT JOIN LSQ_Prospect_Base LSQ_PBASE ON (LSQ_PBASE.ProspectID=PAE.RelatedProspectId)
LEFT JOIN LSQ_users LSQ_User  on LSQ_PBASE.OwnerId=LSQ_User.UserId
LEFT JOIN LSQ_Prospect_ExtensionBase PE ON (PE.ProspectID=LSQ_PBASE.ProspectID)
LEFT JOIN LSQ_Prospect_Extension2Base PE2 ON (PE2.ProspectID=LSQ_PBASE.ProspectID)
WHERE 
CAST(BH.DOCDATE AS DATE) BETWEEN '2022-04-01' AND '2025-06-08'  AND 
BH.DOCTYPE=1000050
--AND BH.IMPORTEDDATE >(SELECT MAX(IMPORTEDDATE) FROM ASM_TRIUMPH_BOOKING_FACT)
GROUP BY
CM.CODE,
IM.CODE+IV.CODE,
CAST(BH.DOCDATE AS DATE),
BL.LINEID,
BL.HEADERID,
CM.COMPANYTYPE,
BH.BRANCHID,
BH.IMPORTEDDATE,
IM.CODE,
EH.LEADTYPE,
LSQ_PBASE.mx_Enquiry_Mode,
LSQ_User.Firstname,
LSQ_PBASE.MX_MODE_OF_ENQUIRY,
PE2.mx_Qualified_First_Source,
CAST(PE.MX_dEALER_ASSIGNMENT_DATE AS DATE),
PE2.mx_Qualified_Source_of_Enquiry,
PE2.mx_Qualified_Sub_Source


DELETE FROM ASM_PB_T_BOOKING_FACT WHERE DATE >Cast(Getdate()-1 as date)

--Dedup Process:

  ;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_BookingDocID,BookingLineID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_T_BOOKING_FACT                
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1; 


--*****************************************************************************************************************

update B set B.FK_SKU=C.PK_SKU from ASM_PB_T_BOOKING_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_PB_T_BOOKING_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_DIM C on (B.MODEL=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].ASM_PB_T_BOOKING_FACT B INNER JOIN ASM_PB_HKT_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)

--******************************************************************************************************************


END
GO
