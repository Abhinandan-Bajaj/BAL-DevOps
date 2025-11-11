SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_CV_SALES_FACT_REFRESH] AS
BEGIN

/********************************************HISTORY********************************************/
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/
/*  DATE       |  CREATED BY/MODIFIED BY |              CHANGE DESCRIPTION                     */
/*---------------------------------------------------------------------------------------------*/
/*  09/05/2024 |  Robin Singh            |   Same day retail flag added                        */
/*  20/03/2025 |  Richa            |   Visited sales added                 */
/*  26/03/2025 |  Ashwini Ahire            |First_Source_Lead_Type, First_Mode_Source,   First_Mode_SubSource*/
/*    14/08/2025 |  Richa Mishra            |        Addition of LSQ Targets  */
/*    14/08/2025 |  Ashwini Ahire            |        Docdate added  */
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/
/********************************************HISTORY********************************************/


TRUNCATE TABLE ASM_CV_SALES_FACT

INSERT INTO ASM_CV_SALES_FACT
(
FK_DEALERCODE,
FK_SKU,
FK_TYPE,
[DATE],
EnquiryLineID,
FK_EnquiryDocID,
BookingLineID,
FK_BookingDocID,
AllocationLineID,
FK_AllocationDocID,
FK_Model_Code,
CompanyType,
FK_BRANCHID,
FK_TALUKAID,
SALES_PERSON,
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
LOANTOVALUE,
TAT_BOOKING_RETAIL,
StockAgeingBucket,
StockAgeing,
ExchangeAgeBucket,
EnquiryDaysBucket,
BOOKINGDAYSBUCKET, 
BaseFlag,
LEADTYPE,
Campaign_Code,
Pincode,
Area,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource,
Salesperson_id,
Designation,
Recurrence_id,
Subgoal,
PhoneMobile,
Model,
TeamTarget
)
SELECT --DISTINCT
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
[DATE],
ENQUIRYLINEID,
FK_ENQUIRYDOCID,
'' AS BookingLineID,
'' AS FK_BookingDocID,
'' AS AllocationLineID,
'' AS FK_AllocationDocID,
FK_MODEL,
CompanyType,
BRANCHID,
TEHSILID,
REPLACE(REPLACE(REPLACE(SALES_PERSON,' ',' |'),'| ',''),' |',' ') AS SALES_PERSON,
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
0 As LOANTOVALUE,
0 As TAT_BOOKING_RETAIL,
'' AS StockAgeingBucket,
'' AS StockAgeing,
'' as ExchangeAgeBucket,
CASE 
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 0 AND 30 THEN '0-30'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 31 AND 60 THEN '31-60'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 61 AND 90 THEN '61-90'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 91 AND 120 THEN '91-120'
ELSE '>120'
END,
'' As BOOKINGDAYSBUCKET,
BaseFlag
,LEADTYPE
,Campaign_Code
,Pincode
,Area
,First_Source_Lead_Type
,First_Mode_Source
,First_Mode_SubSource,
Salesperson_id,
Designation,
Recurrence_id,
Subgoal,
 REPLACE(REPLACE(PhoneMobile, '+91-', ''), '-', '') , Model,
 TeamTarget
FROM 
  ASM_CV_ENQUIRY_FACT

--***********************************************************************************************

--Retail Sales Fact Insertation
INSERT INTO ASM_CV_SALES_FACT
(
FK_DEALERCODE,
FK_SKU,
FK_TYPE,
[DATE],
EnquiryLineID,
FK_EnquiryDocID,
BookingLineID,
FK_BookingDocID,
AllocationLineID,
FK_AllocationDocID,
FK_Model_Code,
CompanyType,
FK_BRANCHID,
FK_TALUKAID,
SALES_PERSON,
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
LOANTOVALUE,
DISTRICT_NAME,
TAT_BOOKING_RETAIL,
StockAgeingBucket,
StockAgeing,
ExchangeAgeBucket,
EnquiryDaysBucket,
BOOKINGDAYSBUCKET,
BaseFlag,
LEADTYPE,
Campaign_Code,
IS_SAMEDAYRETAIL,
Pincode,
Area,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource,
Salesperson_id,
Designation,
Recurrence_id,
Subgoal,
PhoneMobile,
Model,
RetailSalesperson_id,
TeamTarget
)
SELECT --DISTINCT
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
[DATE],
''  AS EnquiryLineID,
''  AS FK_EnquiryDocID,
''  AS BookingLineID,
''  AS FK_BookingDocID,
''  AS AllocationLineID,
''  AS FK_AllocationDocID,
FK_MODEL,
COMPANYTYPE,
BRANCHID,
TEHSILID,
REPLACE(REPLACE(REPLACE(SALES_PERSON,' ',' |'),'| ',''),' |',' ') AS SALES_PERSON,
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
LOANTOVALUE,
DISTRICT_NAME,
0 As TAT_BOOKING_RETAIL,
'' AS StockAgeingBucket,
'' AS StockAgeing,
CASE 
WHEN DATEDIFF(year, DATE, GETDATE()) BETWEEN 1 AND 2 THEN '1-2'
WHEN DATEDIFF(year, DATE, GETDATE()) BETWEEN 2 AND 3 THEN '2-3'
WHEN DATEDIFF(year, DATE, GETDATE()) BETWEEN 3 AND 4 THEN '3-4'
WHEN DATEDIFF(year, DATE, GETDATE()) BETWEEN 4 AND 5 THEN '4-5'
END,
'' As EnquiryDaysBucket,
'' As BOOKINGDAYSBUCKET,
0,
ISNULL(LEADTYPE,'KAM'),
Campaign_Code,
IS_SAMEDAYRETAIL,
Pincode,
Area,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource,
Salesperson_id,
Designation,
Recurrence_id,
Subgoal,
 REPLACE(REPLACE(PhoneMobile, '+91-', ''), '-', ''),
Model,
RetailSalesperson_id,
TeamTarget
FROM ASM_CV_RETAIL_FACT 


--****************************************************************************************************

--BILLING_FACT :

INSERT INTO ASM_CV_SALES_FACT
(  
FK_DEALERCODE,
FK_SKU,
FK_TYPE,
[DATE],
EnquiryLineID,
FK_EnquiryDocID,
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
LOANTOVALUE,
TAT_BOOKING_RETAIL,
StockAgeingBucket,
StockAgeing,
ExchangeAgeBucket,
EnquiryDaysBucket,
BOOKINGDAYSBUCKET,
BaseFlag,
Docdate)
SELECT  
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
[DATE],
'' AS EnquiryLineID,
'' AS FK_EnquiryDocID,
'' AS BookingLineID,
'' AS FK_BookingDocID,
'' AS AllocationLineID,
'' AS FK_AllocationDocID,
FK_MODEL,
--CM.COMPANYTYPE AS COMPANYTYPE,
7 As COMPANYTYPE,
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
0 As LOANTOVALUE,
0 As TAT_BOOKING_RETAIL,
'' AS StockAgeingBucket,
'' AS StockAgeing,
'' As ExchangeAgeBucket,
'' As EnquiryDaysBucket,
'' As BOOKINGDAYSBUCKET,
0,
Docdate
FROM 
ASM_CV_BILLING_FACT ABF INNER JOIN COMPANY_MASTER CM ON (ABF.DEALERCODE = CM.CODE)


--************************************************************************************


--Stock Insertation:

INSERT INTO ASM_CV_SALES_FACT
(  
FK_DEALERCODE,
FK_SKU,
FK_TYPE,
[DATE],
EnquiryLineID,
FK_EnquiryDocID,
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
LOANTOVALUE,
TAT_BOOKING_RETAIL,
StockAgeingBucket,
StockAgeing,
ExchangeAgeBucket,
EnquiryDaysBucket,
BOOKINGDAYSBUCKET,
BaseFlag)
SELECT --DISTINCT
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
[DATE],
'' AS EnquiryLineID,
'' AS FK_EnquiryDocID,
'' AS BookingLineID,
'' AS FK_BookingDocID,
'' AS AllocationLineID,
'' AS FK_AllocationDocID,
FK_MODEL,
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
0 As LOANTOVALUE,
0 As TAT_BOOKING_RETAIL,
CASE 
WHEN DATEDIFF(day,STOCKDATE,GETDATE()) BETWEEN 0 AND 30 THEN '0-30'
WHEN DATEDIFF(day,STOCKDATE,GETDATE()) BETWEEN 31 AND 60 THEN '31-60'
WHEN DATEDIFF(day,STOCKDATE,GETDATE()) BETWEEN 61 AND 90 THEN '61-90'
ELSE '>90'
END AS StockAgeingBucket,
DATEDIFF(day,STOCKDATE,GETDATE()) AS StockAgeing,
'' As ExchangeAgeBucket,
'' As EnquiryDaysBucket,
'' As BOOKINGDAYSBUCKET,
0
FROM 
ASM_CV_STOCK_FACT 


--****************************************************************

--Booking:


INSERT INTO ASM_CV_SALES_FACT
(
FK_DEALERCODE,
FK_SKU,
FK_TYPE,
[DATE],
EnquiryLineID,
FK_EnquiryDocID,
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
LOANTOVALUE,
TAT_BOOKING_RETAIL,
StockAgeingBucket,
StockAgeing,
ExchangeAgeBucket,
EnquiryDaysBucket,
BOOKINGDAYSBUCKET,
BaseFlag,
LEADTYPE)
SELECT --DISTINCT
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
[DATE],
'' AS EnquiryLineID,
'' AS FK_EnquiryDocID,
BookingLineID,
FK_BookingDocID,
'' AS AllocationLineID,
'' AS FK_AllocationDocID,
FK_MODEL,
CompanyType,
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
0 As LOANTOVALUE,
TAT_BOOKING_RETAIL,
'' AS StockAgeingBucket,
'' AS StockAgeing,
'' As ExchangeAgeBucket,
'' As EnquiryDaysBucket,
CASE
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 0 and 30 THEN '0-30'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 31 and 60 THEN '31-60'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 61 and 90 THEN '61-90'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 91 and 120 THEN '91-120'
ELSE '>120'
END,
0,
LEADTYPE
FROM 
ASM_CV_BOOKING_FACT


--************************************************************
--Allocation:

INSERT INTO ASM_CV_SALES_FACT
(
FK_DEALERCODE,
FK_SKU,
FK_TYPE,
[DATE],
EnquiryLineID,
FK_EnquiryDocID,
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
LOANTOVALUE,
TAT_BOOKING_RETAIL,
StockAgeingBucket,
StockAgeing,
ExchangeAgeBucket,
EnquiryDaysBucket,
BOOKINGDAYSBUCKET,
BaseFlag)
SELECT --DISTINCT
FK_DealerCode,
FK_SKU,
FK_TYPE_ID,
[DATE],
'' AS EnquiryLineID,
'' AS FK_EnquiryDocID,
'' AS BookingLineID,
'' AS FK_BookingDocID,
AllocationLineID,
FK_AllocationDocID,
FK_MODEL,
CompanyType,
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
0 As LOANTOVALUE,
0 As TAT_BOOKING_RETAIL,
'' AS StockAgeingBucket,
'' AS StockAgeing,
'' As ExchangeAgeBucket,
'' As EnquiryDaysBucket,
'' As BOOKINGDAYSBUCKET,
0
FROM 
ASM_CV_ALLOCATION_FACT

--************************************************************
--Working Capital:
INSERT INTO ASM_CV_SALES_FACT
(
FK_DEALERCODE,
FK_TYPE,
[DATE],
CompanyType,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
VehicleStockValue_lacs,
BALCreditSales_lacs,
TotalBorrowed_lacs,
TotalOwnFund_lacs,
[OwnFund%],
BGExpiryDate_Status1,
BGExpiryDate_Status2,
BGExpiryDate_Status3,
BGExpiryDate_Status4,
BGExpiryDate_Status5,
BGExpiryDate_Status6,
BGExpiryDate_Status7,
[BAL Credit/ BG Ratio],
OwnFund_Status
)
SELECT --DISTINCT
FK_dealercode,
FK_TYPE_ID,
RecordDate,
7 AS CompanyType,
GETDATE() AS LASTUPDATEDDATETIME,
IMPORTEDDATE,
VehicleStockValue_lacs,
BALCreditSales_lacs,
TotalBorrowed_lacs,
TotalOwnFund_lacs,
[OwnFund%],
BGExpiryDate_Status1,
BGExpiryDate_Status2,
BGExpiryDate_Status3,
BGExpiryDate_Status4,
BGExpiryDate_Status5,
BGExpiryDate_Status6,
BGExpiryDate_Status7,
[BAL Credit/ BG Ratio],
CASE 
WHEN [OWNFUND%]>30 THEN 'Healthy'
WHEN [OWNFUND%] BETWEEN 20 AND 30 THEN 'Early Signs'
WHEN [OWNFUND%] <20 AND [OWNFUND%]>0 THEN 'Watchlist'
WHEN [OWNFUND%] <0 THEN 'Critical'
WHEN [OWNFUND%] =0 THEN 'Utility not Updated(Zero Stock)'
END AS OwnFund_Status
FROM 
ASM_CV_WORKING_CAP_FACT

---------------------------------------------------------------------------------------------------------------------------------------------------------
----Visited Salesview



INSERT INTO ASM_CV_SALES_FACT
(
FK_DEALERCODE,
FK_SKU,
FK_TYPE,
[DATE],
EnquiryLineID,
FK_EnquiryDocID,
BookingLineID,
FK_BookingDocID,
AllocationLineID,
FK_AllocationDocID,
FK_Model_Code,
CompanyType,
FK_BRANCHID,
SALES_PERSON,
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
LOANTOVALUE,
TAT_BOOKING_RETAIL,
StockAgeingBucket,
StockAgeing,
ExchangeAgeBucket,
EnquiryDaysBucket,
BOOKINGDAYSBUCKET, 
BaseFlag,
LEADTYPE,
Campaign_Code,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource

)
SELECT --DISTINCT
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
[DATE],
ENQUIRYLINEID,
FK_ENQUIRYDOCID,
'' AS BookingLineID,
'' AS FK_BookingDocID,
'' AS AllocationLineID,
'' AS FK_AllocationDocID,
FK_MODEL,
CompanyType,
BRANCHID,
REPLACE(REPLACE(REPLACE(SALES_PERSON,' ',' |'),'| ',''),' |',' ') AS SALES_PERSON,
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
0 As LOANTOVALUE,
0 As TAT_BOOKING_RETAIL,
'' AS StockAgeingBucket,
'' AS StockAgeing,
'' as ExchangeAgeBucket,
CASE 
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 0 AND 30 THEN '0-30'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 31 AND 60 THEN '31-60'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 61 AND 90 THEN '61-90'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 91 AND 120 THEN '91-120'
ELSE '>120'
END,
'' As BOOKINGDAYSBUCKET,
BaseFlag
,LEADTYPE
,Campaign_Code,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource
FROM 
  ASM_CV_VISITED_FACT




--***********************************************************************************************

END
GO