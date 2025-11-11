
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_Full_Load_ASM_CV_BOOKING_REFRESH] AS
BEGIN

--***********************************************************************************************************************

/********************************************HISTORY********************************************/
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/
/*  DATE       |  CREATED BY/MODIFIED BY |              CHANGE DESCRIPTION                     */
/*---------------------------------------------------------------------------------------------*/
/*  23/04/2024 |  Robin Singh            |            LSQ  Leadtype logic change               */
/*  26/03/2025 |  Ashwini Ahire          | First_Source_Lead_Type, First_Mode_Source,   First_Mode_SubSource*/
/* 28/08/2025 |  Lachmanna           | Bug fix for open bookings							*/
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/
/********************************************HISTORY********************************************/


--2. Booking Dim:

Truncate table ASM_CV_BOOKING_DIM
INSERT INTO ASM_CV_BOOKING_DIM
SELECT DISTINCT
BOOKING_HEADER.HEADERID AS PK_BOOKINGHEADERID,
CAST(BOOKING_HEADER.DOCDATE AS DATE) AS BOOKINGDATE,
--BOOKING_HEADER.STATUS AS [BOOKING STATUS],
--Added below open booking status logic post confirmation of CDMS team and approval of Mahesh Kumar S sir on 02.06.2023
CASE 
WHEN Qty = QtyPending AND QtyCancelled = 0 THEN 'Open'    
WHEN QtyAllocated > QtyInvoiced and QtyInvoiced<>0 Then 'Partially Invoiced'             
WHEN Qty > QtyAllocated and QtyAllocated <> 0 and QtyInvoiced = QtyAllocated Then 'Partially Invoiced'
--WHEN QtyCancelled > 0 OR (IsNull(CancellationDate,'') <> '' and IsNull(CancellationType,0) <> 0)  THEN 'Cancelled' 
WHEN QtyCancelled > 0 OR (IsNull(CancellationDate,'') <> '' and IsNull(CancellationType,'0') <> '0')  THEN 'Cancelled' 
When QtyAllocated=QtyInvoiced and QtyInvoiced<>0 Then 'Invoiced'
WHEN Qty = QtyAllocated and QtyAllocated <> 0 and QtyInvoiced = 0 THEN 'Allocated'   
when Qty>QtyAllocated and QtyAllocated<>0 and QtyInvoiced= 0 Then 'Partially Allocated'
END As [BOOKING STATUS],
GETDATE() AS [CREATEDATETIME],
BOOKING_HEADER.IMPORTEDDATE,
BOOKING_HEADER.CDMS_BATCHNO,
(CASE
WHEN Qty = QtyPending AND QtyCancelled = 0 THEN DATEDIFF(day,BOOKING_HEADER.DOCDATE,(Cast(SYSDATETIME() as date)))
ELSE 0
END) AS BOOKINGDAYS,
Case
When (CASE WHEN Qty = QtyPending AND QtyCancelled = 0 THEN DATEDIFF(day,BOOKING_HEADER.DOCDATE,(Cast(SYSDATETIME() as date))) ELSE 0 END) BETWEEN 0 and 30 Then '0-30'
When (CASE WHEN Qty = QtyPending AND QtyCancelled = 0 THEN DATEDIFF(day,BOOKING_HEADER.DOCDATE,(Cast(SYSDATETIME() as date))) ELSE 0 END) BETWEEN 31 and 60 Then '31-60'
When (CASE WHEN Qty = QtyPending AND QtyCancelled = 0 THEN DATEDIFF(day,BOOKING_HEADER.DOCDATE,(Cast(SYSDATETIME() as date))) ELSE 0 END) BETWEEN 61 and 90 Then '61-90'
When (CASE WHEN Qty = QtyPending AND QtyCancelled = 0 THEN DATEDIFF(day,BOOKING_HEADER.DOCDATE,(Cast(SYSDATETIME() as date))) ELSE 0 END) BETWEEN 91 and 120 Then '91-120'
Else '>120'
End As BOOKINGDAYSBUCKET,
Qty, 
QtyPending, 
QtyCancelled 
--INTO ASM_CV_BOOKING_DIM select top(10) * from ASM_CV_BOOKING_DIM
FROM BOOKING_HEADER INNER JOIN COMPANY_MASTER ON (BOOKING_HEADER.COMPANYID=COMPANY_MASTER.COMPANYID AND 
COMPANY_MASTER.COMPANYTYPE = 7)
JOIN BOOKING_LINE ON BOOKING_HEADER.HEADERID=BOOKING_LINE.HEADERID
WHERE 
--CAST(BOOKING_HEADER.DOCDATE AS DATE) BETWEEN '2020-04-01' AND '2023-01-10' and
CAST(BOOKING_HEADER.DOCDATE AS DATE) between '2020-04-01' and Cast(Getdate()-1 as date)
--and (Qty = QtyPending AND QtyCancelled = 0) 
AND BOOKING_HEADER.DOCTYPE=1000386 -- AND
--BOOKING_HEADER.IMPORTEDDATE>(SELECT MAX(IMPORTEDDATE) FROM ASM_CV_BOOKING_DIM) --(16984 rows affected)

 

--
Delete from ASM_CV_BOOKING_DIM Where Cast(BOOKINGDATE as Date)>Cast(Getdate()-1 as date) 

--**********************************************************************
 ;WITH CTE AS                  
(                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_BOOKINGHEADERID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_CV_BOOKING_DIM                   
)                  
DELETE FROM CTE                  
WHERE RNK<>1;   

                  
DELETE FROM ASM_CV_BOOKING_DIM    where (Qty <> QtyPending AND (QtyCancelled = 1 or QtyCancelled = 0 ) ) ;   


--**********************************************************

 

--Booking Fact:
Truncate table ASM_CV_BOOKING_FACT
INSERT INTO ASM_CV_BOOKING_FACT 
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
COUNT(BH.HEADERID) AS ACTUALQUANTITY,
getdate() AS LASTUPDATEDDATETIME,
BH.IMPORTEDDATE,
IM.CODE As MODEL,
Cast(0 as int) As FK_MODEL,
Cast(0 As decimal(19,0)) As FLAG,
DATEDIFF(DAY,BH.DOCDATE,RH.DOCDATE) AS TAT_Booking_Retail,
ISNULL(COALESCE(EH.LEADTYPE,LSQ_PBASE.mx_Enquiry_Mode ,LSQ_PBASE.mx_Mode_of_Enquiry),'KAM') as LeadType,

CASE WHEN CAST(PE.MX_dEALER_ASSIGNMENT_DATE AS DATE)>='2024-12-01' THEN COALESCE(EH.LEADTYPE,PE2.mx_Qualified_First_Source, 'KAM') END  AS First_Source_Lead_Type,
ISNULL(PE2.mx_Qualified_Source_of_Enquiry, 'Not Available')   AS First_Mode_Source,
ISNULL(PE2.mx_Qualified_Sub_Source, 'Not Available') AS First_Mode_SubSource,
BL.Qty , BL.QtyPending , BL.QtyCancelled 

--INTO ASM_CV_BOOKING_FACT  
FROM
BOOKING_HEADER BH INNER JOIN COMPANY_MASTER CM ON (BH.COMPANYID=CM.COMPANYID AND CM.COMPANYTYPE = 7)
INNER JOIN BOOKING_LINE BL ON (BH.HEADERID=BL.HEADERID)
LEFT JOIN ENQUIRY_LINE EL ON (EL.LINEID=BL.ENQUIRYDATALINEID)
LEFT JOIN ENQUIRY_HEADER EH ON (EH.HEADERID = EL.DOCID)
LEFT JOIN CONTACT_MASTER CN ON (EH.OWNERCONTACTID = CN.CONTACTID AND CN.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CN.CONTACTID = CN1.CONTACTID))
JOIN ITEM_MASTER IM ON (IM.ItemId=BL.ItemID)
LEFT JOIN RETAIL_LINE RL ON (BL.LINEID=RL.BOOKINGDATALINEID)
LEFT JOIN RETAIL_HEADER RH ON (RL.DOCID=RH.HEADERID)
LEFT JOIN ITEMVARMATRIX_MASTER IV ON (RL.VARMATRIXID=IV.ITEMVARMATRIXID)
LEFT JOIN BOOKING_HEADER_EXT BHE ON BH.HEADERID = BHE.HEADERID  --Added as part of LeadTypeChange
LEFT JOIN LSQ_ProspectActivity_ExtensionBase PAE ON (Cast(PAE.RelatedProspectId+','+PAE.ProspectActivityExtensionId as varchar(8000))=BHE.LMSBOOKINGID) and PAE.ActivityEvent=12003 
--and PAE.mx_Custom_48 IS NULL --Added as part of LeadTypeChange
LEFT JOIN LSQ_Prospect_Base LSQ_PBASE ON (LSQ_PBASE.ProspectID=PAE.RelatedProspectId) --Added as part of LeadTypeChange

LEFT JOIN LSQ_Prospect_ExtensionBase PE ON (PE.ProspectID=LSQ_PBASE.ProspectID)
LEFT JOIN LSQ_Prospect_Extension2Base PE2 ON (PE2.ProspectID=LSQ_PBASE.ProspectID)


WHERE 
    --CAST(BH.DOCDATE AS DATE) BETWEEN '2020-04-01' and '2023-01-10' and
    CAST(BH.DOCDATE AS DATE) between '2020-04-01' and Cast(Getdate()-1 as date) 
     --(BL.Qty = BL.QtyPending AND BL.QtyCancelled = 0) 
	 AND BH.DOCTYPE=1000386 --AND --Applied doctype filter after discussion had with PawanB on 05.01.2023
     --BH.IMPORTEDDATE>(SELECT MAX(IMPORTEDDATE) FROM ASM_CV_BOOKING_FACT)
GROUP BY
CM.CODE,
IM.CODE+IV.CODE,
CAST(BH.DOCDATE AS DATE),
BL.LINEID,
BL.HEADERID,
CM.COMPANYTYPE,
BH.BRANCHID,
CN.NAME,
BH.IMPORTEDDATE,
IM.CODE,
DATEDIFF(DAY,BH.DOCDATE,RH.DOCDATE),    --(17381 rows affected)
ISNULL(COALESCE(EH.LEADTYPE,LSQ_PBASE.mx_Enquiry_Mode ,LSQ_PBASE.mx_Mode_of_Enquiry),'KAM'),

EH.LEADTYPE,
PE2.mx_Qualified_First_Source,
CAST(PE.MX_dEALER_ASSIGNMENT_DATE AS DATE),
PE2.mx_Qualified_Source_of_Enquiry,
PE2.mx_Qualified_Sub_Source,
BL.Qty, 
BL.QtyPending , BL.QtyCancelled 


--

 

DELETE FROM ASM_CV_BOOKING_FACT WHERE DATE>Cast(Getdate()-1 as date)

 

--Dedup Process:

  ;WITH CTE AS                  
(                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_BookingDocID,BookingLineID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_CV_BOOKING_FACT                
)                  
DELETE FROM CTE                  
WHERE RNK<>1; 

DELETE FROM ASM_CV_BOOKING_FACT  where (Qty <> QtyPending AND (QtyCancelled = 1 or QtyCancelled = 0 ) ) ;   

--*****************************************************************************************************************


update B set B.FK_SKU=C.PK_SKU from ASM_CV_BOOKING_FACT B INNER JOIN ASM_CV_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE) --(13 rows affected)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_CV_BOOKING_FACT B INNER JOIN ASM_CV_PRODUCT_DIM C on (B.MODELCODE=C.MODELCODE) --(17360 rows affected)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].[ASM_CV_BOOKING_FACT] B INNER JOIN ASM_CV_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE) --(17361 rows affected)

 

--*****************************************************************************

 

END
GO