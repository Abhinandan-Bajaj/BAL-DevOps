

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON 
GO

Alter PROC [dbo].[USP_ASM_UB_SALES_FACT_REFRESH] AS
BEGIN
--***************************START************************************************
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-12-24 	|	Nikita		        | First_Source_Lead_type Changes 		*/
/*	2025-04-04 	|	Lachmanna		| First Mode Source and sub source  Addition	*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
TRUNCATE TABLE ASM_UB_SALES_FACT
INSERT INTO ASM_UB_SALES_FACT
(
FK_DEALERCODE,
FK_SKU,
FK_TYPE,
[DATE],
[FK_EnquiryProspectID],
[ProspectActivityExtensionId],
BookingLineID,
FK_BookingDocID,
AllocationLineID,
FK_AllocationDocID,
FK_Model_Code,
CompanyType,
FK_BRANCHID,
RetailLineID,
FK_RetailDocID,
ACTUALQUANTITY,
Pending_Orders,
[BAL Outstanding (O/S)],
[Bank Outstanding (O/S)],
[Remittance (In Lakh)],
[Target Own Funds (OF)],
[Actual BG],
[Target BG],
StockStatus,
[Stock Value],
[Stock Quantity],
TARGETQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
FLAG,
EnquiryDaysBucket, 	   
BaseFlag,
TEHSILID,
SALESPERSON_ID,
LEADTYPE,
First_Source_Lead_Type
,SourceOfEnquiry
,SubSourceOfEnquiry
,mx_dse_enquiry_status,
mx_Lead_Score,
mx_first_lead_classification,
 First_Mode_Source,
 First_Mode_SubSource
)
SELECT --DISTINCT
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
[DATE],
[FK_EnquiryProspectID],
[ProspectActivityExtensionId],
'' AS BookingLineID,
'' AS FK_BookingDocID,
'' AS AllocationLineID,
'' AS FK_AllocationDocID,
FK_MODEL,
CompanyType,
BRANCHID,
'' AS RetailLineID,
'' AS FK_RetailDocID,
ACTUALQUANTITY,
'' AS Pending_Orders,
'' AS [BAL Outstanding (O/S)],
'' AS [Bank Outstanding (O/S)],
'' AS [Remittance (In Lakh)],
'' AS [Target Own Funds (OF)],
'' AS [Actual BG],
'' AS [Target BG],
'' AS StockStatus,
'' AS [Stock Value],
'' AS [Stock Quantity],
TARGETQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
FLAG,
CASE 
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 0 AND 30 THEN '0-30'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 31 AND 60 THEN '31-60'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 61 AND 90 THEN '61-90'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 91 AND 120 THEN '91-120'
ELSE '>120'
END,  
0,
TEHSILID,
SALESPERSON_ID,
LEADTYPE,
First_Source_Lead_Type
,SourceOfEnquiry
,SubSourceOfEnquiry,
mx_dse_enquiry_status,
mx_Lead_Score,
mx_first_lead_classification,
 First_Mode_Source,
 First_Mode_SubSource
FROM 
  ASM_UB_ENQUIRY_FACT

--***********************************************************************************************

--Retail Sales Fact Insertation

INSERT INTO ASM_UB_SALES_FACT
(
FK_DEALERCODE,
FK_SKU,
FK_TYPE,
[DATE],
[FK_EnquiryProspectID],
[ProspectActivityExtensionId],
BookingLineID,
FK_BookingDocID,
AllocationLineID,
FK_AllocationDocID,
FK_Model_Code,
CompanyType,
FK_BRANCHID,
RetailLineID,
FK_RetailDocID,
ACTUALQUANTITY,
Pending_Orders,
[BAL Outstanding (O/S)],
[Bank Outstanding (O/S)],
[Remittance (In Lakh)],
[Target Own Funds (OF)],
[Actual BG],
[Target BG],
StockStatus,
[Stock Value],
[Stock Quantity],
TARGETQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
FLAG,
EnquiryDaysBucket,
	  
BaseFlag,
TEHSILID,   
LEADTYPE,
SALESPERSON_ID,
First_Source_Lead_Type
,SourceOfEnquiry
,SubSourceOfEnquiry
,mx_dse_enquiry_status,
mx_Lead_Score,
mx_first_lead_classification,
 First_Mode_Source,
 First_Mode_SubSource
)
SELECT --DISTINCT
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
[DATE],
''  AS [FK_EnquiryProspectID],
''  AS [ProspectActivityExtensionId],
''  AS BookingLineID,
''  AS FK_BookingDocID,
''  AS AllocationLineID,
''  AS FK_AllocationDocID,
FK_MODEL,
COMPANYTYPE,
BRANCHID,
RETAILLINEID,
FK_RETAILDOCID,
ACTUALQUANTITY,
'' AS Pending_Orders,
'' AS [BAL Outstanding (O/S)],
'' AS [Bank Outstanding (O/S)],
'' AS [Remittance (In Lakh)],
'' AS [Target Own Funds (OF)],
'' AS [Actual BG],
'' AS [Target BG],
'' AS StockStatus,
'' AS [Stock Value],
'' AS [Stock Quantity],
TARGETQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
FLAG,
'' As EnquiryDaysBucket,
	  
0,
TEHSILID,   
ISNULL(LEADTYPE,'Not Available') LEADTYPE,
SALESPERSON_ID,
First_Source_Lead_Type
,SourceOfEnquiry
,SubSourceOfEnquiry
,mx_dse_enquiry_status,
mx_Lead_Score,
mx_first_lead_classification,
 First_Mode_Source,
 First_Mode_SubSource
FROM ASM_UB_RETAIL_FACT 


--****************************************************************************************************

--BILLING_FACT :

INSERT INTO ASM_UB_SALES_FACT
(  
FK_DEALERCODE,
FK_SKU,
FK_TYPE,
[DATE],
[FK_EnquiryProspectID],
[ProspectActivityExtensionId],
BookingLineID,
FK_BookingDocID,
AllocationLineID,
FK_AllocationDocID,
FK_Model_Code,
CompanyType,
RetailLineID,
FK_RetailDocID,
ACTUALQUANTITY,
Pending_Orders,
[BAL Outstanding (O/S)],
[Bank Outstanding (O/S)],
[Remittance (In Lakh)],
[Target Own Funds (OF)],
[Actual BG],
[Target BG],
StockStatus,
[Stock Value],
[Stock Quantity],
TARGETQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
FLAG,
EnquiryDaysBucket,
	  
BaseFlag,
TEHSILID
	 
)
SELECT  
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
[DATE],
'' AS [FK_EnquiryProspectID],
'' AS [ProspectActivityExtensionId],
'' AS BookingLineID,
'' AS FK_BookingDocID,
'' AS AllocationLineID,
'' AS FK_AllocationDocID,
FK_MODEL,
10 As COMPANYTYPE,
'' AS RetailLineID,
'' AS FK_RetailDocID,
ACTUALQUANTITY,
PENDING_ORDERS,
'' AS [BAL Outstanding (O/S)],
'' AS [Bank Outstanding (O/S)],
'' AS [Remittance (In Lakh)],
'' AS [Target Own Funds (OF)],
'' AS [Actual BG],
'' AS [Target BG],
'' AS StockStatus,
'' AS [Stock Value],
'' AS [Stock Quantity],
TARGETQUANTITY,
GETDATE() AS LASTUPDATEDDATETIME,
'' AS IMPORTEDDATE,
FLAG,
'' As EnquiryDaysBucket,
	  
0,
TEHSILID
	 
FROM 
ASM_UB_BILLING_FACT


--************************************************************************************


--Stock Insertation:

INSERT INTO ASM_UB_SALES_FACT
(  
FK_DEALERCODE,
FK_SKU,
FK_TYPE,
[DATE],
[FK_EnquiryProspectID],
[ProspectActivityExtensionId],
BookingLineID,
FK_BookingDocID,
AllocationLineID,
FK_AllocationDocID,
FK_Model_Code,
FK_BRANCHID,
CompanyType,
RetailLineID,
FK_RetailDocID,
ACTUALQUANTITY,
Pending_Orders,
[BAL Outstanding (O/S)],
[Bank Outstanding (O/S)],
[Remittance (In Lakh)],
[Target Own Funds (OF)],
[Actual BG],
[Target BG],
StockStatus,
[Stock Value],
[Stock Quantity],
TARGETQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
FLAG,
StockAgeingBucket,
StockAgeing,
EnquiryDaysBucket,
	  
BaseFlag,
TEHSILID
	 
)
SELECT --DISTINCT
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
[DATE],
'' AS [FK_EnquiryProspectID],
'' AS [ProspectActivityExtensionId],
'' AS BookingLineID,
'' AS FK_BookingDocID,
'' AS AllocationLineID,
'' AS FK_AllocationDocID,
FK_MODEL,
BRANCHID,
COMPANYTYPE,
'' AS RetailLineID,
'' AS FK_RetailDocID,
ACTUALQUANTITY,
'' AS Pending_Orders,
'' AS [BAL Outstanding (O/S)],
'' AS [Bank Outstanding (O/S)],
'' AS [Remittance (In Lakh)],
'' AS [Target Own Funds (OF)],
'' AS [Actual BG],
'' AS [Target BG],
STOCKSTATUS,
'' AS [Stock Value],
[Stock Quantity],
'' AS TARGETQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
Cast(0 as decimal(19,0)) As FLAG,
CASE WHEN PURCHASE_DATE IS NOT NULL THEN 
CASE
WHEN DATEDIFF(day,PURCHASE_DATE,GETDATE()) BETWEEN 0 AND 10 THEN '0-10 days'
WHEN DATEDIFF(day,PURCHASE_DATE,GETDATE()) BETWEEN 11 AND 20 THEN '11-20 days'
WHEN DATEDIFF(day,PURCHASE_DATE,GETDATE()) BETWEEN 21 AND 30 THEN '21-30 days'
WHEN DATEDIFF(day,PURCHASE_DATE,GETDATE()) BETWEEN 30 AND 60 THEN '30-60 days'
WHEN DATEDIFF(day,PURCHASE_DATE,GETDATE()) BETWEEN 60 AND 90 THEN '60-90 days'
ELSE '>90 days'
END 
ELSE '0-10 days' END AS StockAgeingBucket,
CASE WHEN PURCHASE_DATE IS NOT NULL THEN DATEDIFF(day,PURCHASE_DATE,GETDATE()) 
ELSE  DATEDIFF(day,(GETDATE()-10),GETDATE()) END  AS StockAgeing,
'' As EnquiryDaysBucket,
	  
0,
TEHSILID
	 
FROM 
ASM_UB_STOCK_FACT 


--****************************************************************

--Booking:


INSERT INTO ASM_UB_SALES_FACT
(
FK_DEALERCODE,
FK_SKU,
FK_TYPE,
[DATE],
[FK_EnquiryProspectID],
[ProspectActivityExtensionId],
BookingLineID,
FK_BookingDocID,
AllocationLineID,
FK_AllocationDocID,
FK_Model_Code,
CompanyType,
FK_BRANCHID,
RetailLineID,
FK_RetailDocID,
ACTUALQUANTITY,
Pending_Orders,
[BAL Outstanding (O/S)],
[Bank Outstanding (O/S)],
[Remittance (In Lakh)],
[Target Own Funds (OF)],
[Actual BG],
[Target BG],
StockStatus,
[Stock Value],
[Stock Quantity],
TARGETQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
FLAG,
EnquiryDaysBucket,
BaseFlag,
TEHSILID,
SALESPERSON_ID,
LEADTYPE,
BOOKINGDAYSBUCKET_LESS30,
BOOKINGDAYSBUCKET_MORE30,
Booking_Source,
First_Source_Lead_Type,
SourceOfEnquiry,
SubSourceOfEnquiry,
First_Mode_Source,
First_Mode_SubSource

)
SELECT --DISTINCT
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
[DATE],
'' AS [FK_EnquiryProspectID],
'' AS [ProspectActivityExtensionId],
BookingLineID,
FK_BookingDocID,
'' AS AllocationLineID,
'' AS FK_AllocationDocID,
FK_MODEL,
CompanyType,
BRANCHID,
'' AS RetailLineID,
'' AS FK_RetailDocID,
ACTUALQUANTITY,
'' AS Pending_Orders,
'' AS [BAL Outstanding (O/S)],
'' AS [Bank Outstanding (O/S)],
'' AS [Remittance (In Lakh)],
'' AS [Target Own Funds (OF)],
'' AS [Actual BG],
'' AS [Target BG],
'' AS StockStatus,
'' AS [Stock Value],
'' AS [Stock Quantity],
0 AS TARGETQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
FLAG,
'' As EnquiryDaysBucket,
0,
TEHSILID,
SALESPERSON_ID,
LEADTYPE,
CASE 
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 0 AND 3 THEN '0-3 days'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 4 AND 7 THEN '4-7 days'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 8 AND 14 THEN '8-14 days'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 15 AND 30 THEN '15-30 days'
ELSE 'More Than 30 Days' END AS BOOKINGDAYSBUCKET_LESS30,
CASE 
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 0 AND 30 THEN '0-30 days'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 31 AND 45 THEN '31-45 days'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 46 AND 60 THEN '46-60 days'
ELSE 'More Than 60 Days' END AS BOOKINGDAYSBUCKET_MORE30,
Booking_Source,
First_Source_Lead_Type
,SourceOfEnquiry
,SubSourceOfEnquiry
 ,First_Mode_Source
 ,First_Mode_SubSource
FROM 
ASM_UB_BOOKING_FACT


--************************************************************
--Allocation:

INSERT INTO ASM_UB_SALES_FACT
(
FK_DEALERCODE,
FK_SKU,
FK_TYPE,
[DATE],
[FK_EnquiryProspectID],
[ProspectActivityExtensionId],
BookingLineID,
FK_BookingDocID,
AllocationLineID,
FK_AllocationDocID,
FK_Model_Code,
CompanyType,
FK_BRANCHID,
RetailLineID,
FK_RetailDocID,
ACTUALQUANTITY,
Pending_Orders,
[BAL Outstanding (O/S)],
[Bank Outstanding (O/S)],
[Remittance (In Lakh)],
[Target Own Funds (OF)],
[Actual BG],
[Target BG],
StockStatus,
[Stock Value],
[Stock Quantity],
TARGETQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
FLAG,
EnquiryDaysBucket,
	  
BaseFlag
   
	 
)
SELECT --DISTINCT
FK_DealerCode,
FK_SKU,
FK_TYPE_ID,
[DATE],
'' AS [FK_EnquiryProspectID],
'' AS [ProspectActivityExtensionId],
'' AS BookingLineID,
'' AS FK_BookingDocID,
AllocationLineID,
FK_AllocationDocID,
FK_MODEL,
CompanyType,
BRANCHID,
'' AS RetailLineID,
'' AS FK_RetailDocID,
ACTUALQUANTITY,
'' AS Pending_Orders,
'' AS [BAL Outstanding (O/S)],
'' AS [Bank Outstanding (O/S)],
'' AS [Remittance (In Lakh)],
'' AS [Target Own Funds (OF)],
'' AS [Actual BG],
'' AS [Target BG],
'' AS StockStatus,
'' AS [Stock Value],
'' AS [Stock Quantity],
0 AS TARGETQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
FLAG,
'' As EnquiryDaysBucket,
	  
0
 
FROM 
ASM_UB_ALLOCATION_FACT

--*******************************************************

END
GO