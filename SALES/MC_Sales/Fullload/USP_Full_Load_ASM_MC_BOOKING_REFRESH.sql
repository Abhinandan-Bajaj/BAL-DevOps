SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Alter PROC [dbo].[USP_Full_Load_ASM_MC_BOOKING_REFRESH] AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-09-20 	|	Nikita L		| ADDED First Source LeadType field        			*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/


--1. Booking Dim:
Truncate table ASM_MC_BOOKING_DIM
INSERT INTO ASM_MC_BOOKING_DIM
SELECT DISTINCT
PK_BOOKINGHEADERID,
BOOKINGDATE,
[BOOKING STATUS],
BOOKINGDAYSBUCKET,
CREATEDDATETIME,
IMPORTEDDATE,
CDMS_BATCHNO,
ISNULL(LEAD_TYPE_CDMS,LEAD_TYPE_LSQ) BOOKING_LEAD_TYPE
FROM
(SELECT DISTINCT
BH.HEADERID AS PK_BOOKINGHEADERID,
CAST(BH.DOCDATE AS DATE) AS BOOKINGDATE,
BH.STATUS AS [BOOKING STATUS],
'' AS BOOKINGDAYSBUCKET,
EH.LEADTYPE AS LEAD_TYPE_CDMS,
COALESCE(LSQ_PBASE.mx_Enquiry_Mode,LSQ_PBASE.mx_Mode_of_Enquiry,'Not Available') AS LEAD_TYPE_LSQ,
GETDATE() AS CREATEDDATETIME,
BH.IMPORTEDDATE,
BH.CDMS_BATCHNO
--INTO ASM_MC_BOOKING_DIM
FROM BOOKING_HEADER BH
INNER JOIN COMPANY_MASTER ON (BH.COMPANYID=COMPANY_MASTER.COMPANYID AND COMPANY_MASTER.COMPANYTYPE IN (1,8))
LEFT JOIN BOOKING_LINE BL ON BL.HEADERID = BH.HEADERID
LEFT JOIN BOOKING_HEADER_EXT BHE ON BH.HEADERID = BHE.HEADERID
LEFT JOIN ENQUIRY_LINE EL ON EL.LINEID = BL.ENQUIRYDATALINEID
LEFT JOIN ENQUIRY_HEADER EH ON EH.HEADERID = EL.DOCID
LEFT JOIN LSQ_ProspectActivity_ExtensionBase PAE ON (Cast(PAE.RelatedProspectId+','+PAE.ProspectActivityExtensionId as varchar(8000))=BHE.LMSBOOKINGID) and PAE.ActivityEvent=12002 and PAE.mx_Custom_48 IS NULL
LEFT JOIN LSQ_Prospect_Base LSQ_PBASE ON (LSQ_PBASE.ProspectID=PAE.RelatedProspectId)
WHERE 
   --BH.IMPORTEDDATE          >      (SELECT MAX(IMPORTEDDATE) FROM ASM_MC_BOOKING_DIM)  AND
--CAST(BH.IMPORTEDDATE AS DATE) >= CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_MC_BOOKING_DIM)AS DATE)  AND  -- UPDATED ON 12/06
CAST(BH.DOCDATE AS DATE) BETWEEN '2020-04-01' AND Cast(Getdate()-1 as date) AND
BH.DOCTYPE=135) A
  --

Delete from ASM_MC_BOOKING_DIM Where Cast(BOOKINGDATE as Date)>Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate()))) - 1 as date)

 --**********************************************************************
  ;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_BOOKINGHEADERID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_MC_BOOKING_DIM                  
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;   

 --**********************************************************

--2. Booking Fact:
Truncate table ASM_MC_BOOKING_FACT
INSERT INTO ASM_MC_BOOKING_FACT
SELECT DISTINCT 
DEALERCODE,
SKU,
FK_DealerCode,
FK_SKU,
FK_TYPE_ID,
DATE,
BookingLineID,
FK_BookingDocID,
COMPANYTYPE,
BRANCHID,
ACTUALQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
MODEL,
FK_MODEL,
FLAG,
TEHSILID,
SALESPERSON,
ISNULL(ISNULL(LEAD_TYPE_CDMS,LEAD_TYPE_LSQ),'Not Available') LEADTYPE
,First_Source_Lead_Type  -- Post Update in Digital Leads SP
,First_Mode_Source
,First_Mode_SubSource
FROM
(SELECT
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
NULL AS TEHSILID,
NULL AS SALESPERSON,
EH.LEADTYPE AS LEAD_TYPE_CDMS,
COALESCE(LSQ_PBASE.mx_Enquiry_Mode,LSQ_PBASE.mx_Mode_of_Enquiry) AS LEAD_TYPE_LSQ,
CASE WHEN CAST(PE.MX_dEALER_ASSIGNMENT_DATE AS DATE)>='2024-12-01' THEN COALESCE(EH.LEADTYPE,PE2.mx_Qualified_First_Source) END  AS First_Source_Lead_Type,
ISNULL(PE2.mx_Qualified_Source_of_Enquiry, 'Not Available')   AS First_Mode_Source,
ISNULL(PE2.mx_Qualified_Sub_Source, 'Not Available') AS First_Mode_SubSource
--INTO ASM_MC_BOOKING_FACT
FROM
BOOKING_HEADER BH INNER JOIN COMPANY_MASTER CM ON (BH.COMPANYID=CM.COMPANYID AND CM.COMPANYTYPE IN (1,8))
INNER JOIN BOOKING_LINE BL ON (BH.HEADERID=BL.HEADERID)
JOIN ITEM_MASTER IM ON (IM.ItemId=BL.ItemID)
LEFT JOIN RETAIL_LINE RL ON (BL.LINEID=RL.BOOKINGDATALINEID)
LEFT JOIN ITEMVARMATRIX_MASTER IV ON (RL.VARMATRIXID=IV.ITEMVARMATRIXID)
LEFT JOIN BOOKING_HEADER_EXT BHE ON BH.HEADERID = BHE.HEADERID
LEFT JOIN ENQUIRY_LINE EL ON EL.LINEID = BL.ENQUIRYDATALINEID
LEFT JOIN ENQUIRY_HEADER EH ON EH.HEADERID = EL.DOCID
LEFT JOIN LSQ_ProspectActivity_ExtensionBase PAE ON (Cast(PAE.RelatedProspectId+','+PAE.ProspectActivityExtensionId as varchar(8000))=BHE.LMSBOOKINGID) and PAE.ActivityEvent=12002 
--and PAE.mx_Custom_48 IS NULL
LEFT JOIN LSQ_Prospect_Base LSQ_PBASE ON (LSQ_PBASE.ProspectID=PAE.RelatedProspectId)
LEFT JOIN LSQ_Prospect_ExtensionBase PE ON (PE.ProspectID=LSQ_PBASE.ProspectID)
LEFT JOIN LSQ_Prospect_Extension2Base PE2 ON (PE2.ProspectID=LSQ_PBASE.ProspectID)
WHERE 
CAST(BH.DOCDATE AS DATE) BETWEEN '2020-04-01' AND Cast(Getdate()-1 as date)	 AND
   --BH.IMPORTEDDATE>(SELECT MAX(IMPORTEDDATE) FROM ASM_MC_BOOKING_FACT) AND 
--CAST(BH.IMPORTEDDATE AS DATE) >= CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_MC_BOOKING_FACT) AS DATE) AND  -- UPDATED ON 12/06
  --STATUS = 'Open' AND 
  BH.DOCTYPE=135 
  
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
COALESCE(LSQ_PBASE.mx_Enquiry_Mode,LSQ_PBASE.mx_Mode_of_Enquiry),
PE2.mx_Qualified_First_Source,
CAST(PE.MX_dEALER_ASSIGNMENT_DATE AS DATE),
PE2.mx_Qualified_Source_of_Enquiry,
PE2.mx_Qualified_Sub_Source
)BASE

--

DELETE FROM ASM_MC_BOOKING_FACT WHERE DATE>Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate()))) - 1 as date)

--Dedup Process:

  ;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_BookingDocID,BookingLineID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_MC_BOOKING_FACT                
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1; -- (25 rows affected)


 --*****************************************************************************************************************

--update B set B.FK_SKU=C.PK_SKU from ASM_MC_BOOKING_FACT B INNER JOIN ASM_MC_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE) -- (1725342 rows affected)
--update B set B.FK_MODEL=C.PK_Model_Code from ASM_MC_BOOKING_FACT B INNER JOIN ASM_MC_PRODUCT_DIM C on (B.MODEL=C.MODELCODE) -- (3837506 rows affected)
--update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].ASM_MC_BOOKING_FACT B INNER JOIN ASM_MC_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE) -- (67866 rows affected)



END
GO
