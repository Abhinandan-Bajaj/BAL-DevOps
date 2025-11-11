SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Alter PROC [dbo].[USP_ASM_UB_BOOKING_REFRESH] AS
BEGIN
--***************************START************************************************
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-12-24 	|	Nikita		        | First_Source_Lead_type Changes 		*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
--***************************START*****************************
--1. Booking Dim:
INSERT INTO ASM_UB_BOOKING_DIM
SELECT DISTINCT
BOOKING_HEADER.HEADERID AS PK_BOOKINGHEADERID,
CAST(BOOKING_HEADER.DOCDATE AS DATE) AS BOOKINGDATE,
CASE 
WHEN Qty = QtyPending AND QtyCancelled = 0 THEN 'Open'    
WHEN QtyAllocated > QtyInvoiced and QtyInvoiced<>0 Then 'Partially Invoiced'             
WHEN Qty > QtyAllocated and QtyAllocated <> 0 and QtyInvoiced = QtyAllocated Then 'Partially Invoiced'
WHEN QtyCancelled > 0 OR (IsNull(CancellationDate,'') <> '' and IsNull(CancellationType,0) <> 0)  THEN 'Cancelled' 
When QtyAllocated=QtyInvoiced and QtyInvoiced<>0 Then 'Invoiced'
WHEN Qty = QtyAllocated and QtyAllocated <> 0 and QtyInvoiced = 0 THEN 'Allocated'   
when Qty>QtyAllocated and QtyAllocated<>0 and QtyInvoiced= 0 Then 'Partially Allocated'
ELSE 'Closed'
END As [BOOKING STATUS],
'' AS BOOKINGDAYSBUCKET,
GETDATE() AS CREATEDDATETIME,
BOOKING_HEADER.IMPORTEDDATE,
BOOKING_HEADER.CDMS_BATCHNO
--INTO ASM_UB_BOOKING_DIM
FROM BOOKING_HEADER INNER JOIN COMPANY_MASTER ON (BOOKING_HEADER.COMPANYID=COMPANY_MASTER.COMPANYID AND 
COMPANY_MASTER.COMPANYTYPE = 10)
JOIN BOOKING_LINE ON BOOKING_HEADER.HEADERID=BOOKING_LINE.HEADERID
WHERE 
--CAST(BOOKING_HEADER.DOCDATE AS DATE) BETWEEN '2021-01-01' AND '2022-12-31' AND 
--BOOKING_HEADER.STATUS = 'Open' AND 
BOOKING_HEADER.DOCTYPE=1012737 
AND CAST(BOOKING_HEADER.IMPORTEDDATE AS DATE)>= CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_UB_BOOKING_DIM) AS DATE)
--(SELECT CASE WHEN (SELECT COUNT(*) FROM ASM_UB_BOOKING_DIM)=0 THEN '1900-01-01 00:00:00.0000' ELSE MAX(IMPORTEDDATE) END FROM ASM_UB_BOOKING_DIM)

Delete from ASM_UB_BOOKING_DIM Where Cast(BOOKINGDATE as Date)>Cast(Getdate()-1 as date)

--Dedup Process
;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_BOOKINGHEADERID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_UB_BOOKING_DIM                  
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;
--*************************************************************************
--2. Booking Fact:

INSERT INTO ASM_UB_BOOKING_FACT
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
NULL AS TEHSILID,
NULL AS LeadType,
NULL AS SALESPERSON_ID,
NULL AS Booking_Source,
Null as First_Source_Lead_Type,
NULL AS SourceOfEnquiry,
NULL AS SubSourceOfEnquiry,
NULL  AS First_Mode_Source,
NULL AS First_Mode_SubSource
--INTO ASM_UB_BOOKING_FACT
FROM
BOOKING_HEADER BH
INNER JOIN COMPANY_MASTER CM ON (BH.COMPANYID=CM.COMPANYID AND CM.COMPANYTYPE =10)
INNER JOIN BOOKING_LINE BL ON (BH.HEADERID=BL.HEADERID)
JOIN ITEM_MASTER IM ON (IM.ItemId=BL.ItemID)
LEFT JOIN RETAIL_LINE RL ON (BL.LINEID=RL.BOOKINGDATALINEID)
LEFT JOIN ITEMVARMATRIX_MASTER IV ON (RL.VARMATRIXID=IV.ITEMVARMATRIXID)

WHERE 
--CAST(BH.DOCDATE AS DATE) BETWEEN '2021-01-01' AND '2022-12-31' AND 
--BH.STATUS = 'Open' AND 
BH.DOCTYPE = 1012737 
AND CAST(BH.IMPORTEDDATE AS DATE)>=CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_UB_BOOKING_FACT) AS DATE)
--(SELECT CASE WHEN (SELECT COUNT(*) FROM ASM_UB_BOOKING_FACT)=0 THEN '1900-01-01 00:00:00.0000' ELSE MAX(IMPORTEDDATE) END FROM ASM_UB_BOOKING_FACT)
GROUP BY
CM.CODE,
IM.CODE+IV.CODE,
CAST(BH.DOCDATE AS DATE),
BL.LINEID,
BL.HEADERID,
CM.COMPANYTYPE,
BH.BRANCHID,
BH.IMPORTEDDATE,
IM.CODE

DELETE FROM ASM_UB_BOOKING_FACT WHERE DATE>Cast(Getdate()-1 as date)


--Dedup Process:

  ;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_BookingDocID,BookingLineID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_UB_BOOKING_FACT                
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1; 


--*****************************************************************************************************************

update B set B.FK_SKU=C.PK_SKU from ASM_UB_BOOKING_FACT B INNER JOIN ASM_UB_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_UB_BOOKING_FACT B INNER JOIN ASM_UB_PRODUCT_DIM C on (B.MODEL=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].ASM_UB_BOOKING_FACT B INNER JOIN ASM_UB_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)

--******************************************************************************************************************

-----------------Update LEADTYPE and SALESPERSON- and Booking_Source-----------

update BF
set 
BF.LeadType = ISNULL(LSQ_PBASE.mx_Enquiry_Mode,'Not Available'),
BF.First_Source_Lead_type = CASE when Cast(PE.mx_Dealer_Assignment_Date As Date) >='2024-12-01' THEN  COALESCE (PE.MX_QUALIFIED_FIRST_SOURCE, LSQ_PBASE.MX_ENQUIRY_MODE, 'Not Available') ELSE ISNULL(LSQ_PBASE.mx_Enquiry_Mode,'Not Available') END,
BF.SALESPERSON_ID = LSQ_PBASE.OWNERID,
BF.Booking_Source = PAE.mx_Custom_36,
BF.SourceOfEnquiry =LSQ_PBASE.MX_SOURCE_OF_ENQUIRY,
BF.SubSourceOfEnquiry=LSQ_PBASE.mx_Enquiry_Subsource,
BF.First_Mode_Source = ISNULL(PE.mx_Qualified_Source_of_Enquiry, 'Not Available') ,
BF.First_Mode_SubSource= ISNULL(PE.mx_Qualified_Sub_Source, 'Not Available')
from
ASM_UB_BOOKING_FACT BF
LEFT JOIN BOOKING_HEADER_EXT BHE ON BF.FK_BookingDocID = BHE.HEADERID
LEFT JOIN LSQ_UB_PROSPECTACTIVITY_EXTENSIONBASE PAE ON (Cast(PAE.RelatedProspectId+','+PAE.ProspectActivityExtensionId as varchar(8000))=BHE.LMSBOOKINGID) and PAE.ActivityEvent=12000 
LEFT JOIN LSQ_UB_PROSPECT_BASE LSQ_PBASE ON (LSQ_PBASE.ProspectID=PAE.RelatedProspectId)
LEFT JOIN LSQ_UB_PROSPECT_EXTENSIONBASE PE ON (LSQ_PBASE.ProspectID=PE.ProspectID)

END

GO