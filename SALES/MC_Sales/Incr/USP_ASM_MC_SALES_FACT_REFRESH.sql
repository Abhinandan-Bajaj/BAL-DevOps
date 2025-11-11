SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter PROC [dbo].[USP_ASM_MC_SALES_FACT_REFRESH] AS
BEGIN

--***************************START************************************************
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-04-29 	|	Robin Singh		| Added Session Time Field for Mixed Panel          			*/
/*	2024-09-19 	|	Lachamnan		| Added First source Lead type for Retail And Booking         	*/
/*   2025-05-15 	|	Richa		| Added MC Visited Salesview                                    */
/*   2025-09-23 	|	Ashwini		| uncommented subsource and source and audit code added         */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/	


--------------AUdit table --------------------------
PRINT 'Audit Execution Started ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_MC_SALES_FACT_REFRESH';

---Audit parameters --------------

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			@table_name1 VARCHAR(128) = 'ASM_MC_SALES_FACT', 
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT,   
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX);  
 


 BEGIN TRY			


TRUNCATE TABLE ASM_MC_SALES_FACT

--**************************
--## Enquiry:
--****************************

	INSERT INTO ASM_MC_SALES_FACT
(
FK_DEALERCODE,
FK_ASDCode,
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
BRANCHID,
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
BookingDaysBucket,
BaseFlag,
TEHSILID,
SALESPERSON,
LEADTYPE,
SESSIONTIME,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource
)
SELECT --DISTINCT
FK_DEALERCODE,
'' AS FK_ASDCode,
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
'' AS StockAgeingBucket,
'' AS StockAgeing,
CASE 
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 0 AND 30 THEN '0-30'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 31 AND 60 THEN '31-60'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 61 AND 90 THEN '61-90'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 91 AND 120 THEN '91-120'
ELSE '>120'
END AS EnquiryDaysBucket,
'' AS BookingDaysBucket,
BaseFlag,
TEHSILID,
REPLACE(REPLACE(REPLACE(SALESPERSON,' ',' |'),'| ',''),' |',' ') AS SALESPERSON,
LEADTYPE,
SESSIONTIME,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource
FROM
  ASM_MC_ENQUIRY_FACT -- (171066 records affected)




  --***********************************************************************************************

--*******************
--## Retail :
--*******************

INSERT INTO ASM_MC_SALES_FACT
(
FK_DEALERCODE,
FK_ASDCode,
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
BRANCHID,
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
BookingDaysBucket,
BaseFlag,
TEHSILID,
SALESPERSON,
LEADTYPE,
TRAN_TYPE,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource
)
SELECT --DISTINCT
FK_DEALERCODE,
'' AS FK_ASDCode,
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
'' AS StockAgeingBucket,
'' AS StockAgeing,
'' AS EnquiryDaysBucket,
'' AS BookingDaysBucket,
0,
TEHSILID,
REPLACE(REPLACE(REPLACE(SALESPERSON,' ',' |'),'| ',''),' |',' ') AS SALESPERSON,
ISNULL(LEADTYPE,'Not Available') LEADTYPE,
TRAN_TYPE,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource
FROM ASM_MC_RETAIL_FACT -- (564575 records affected)

--******************************************************************************

--********************
 --## BILLING :
--*********************
INSERT INTO ASM_MC_SALES_FACT
(  
FK_DEALERCODE,
FK_ASDCode,
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
StockAgeingBucket,
StockAgeing,
EnquiryDaysBucket,
BookingDaysBucket,
BaseFlag,
TEHSILID,
SALESPERSON,
PLANT
)
SELECT -- DISTINCT 
FK_DEALERCODE,
'' AS FK_ASDCode,
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
'' AS COMPANYTYPE,
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
LASTUPDATEDDATETIME,
'' AS IMPORTEDDATE,
FLAG,
'' AS StockAgeingBucket,
'' AS StockAgeing,
'' AS EnquiryDaysBucket,
'' AS BookingDaysBucket,
0,
TEHSILID,
SALESPERSON,
PLANT
FROM 
ASM_MC_BILLING_FACT -- (1962671 records affected)

--******************************************************************************

--******************
--## STOCK :
--*******************
INSERT INTO ASM_MC_SALES_FACT
(  
FK_DEALERCODE,
FK_ASDCode,
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
StockAgeingBucket,
StockAgeing,
EnquiryDaysBucket,
BookingDaysBucket,
BaseFlag,
CityBV,
DPP
)
SELECT --DISTINCT
FK_DEALERCODE,
'' AS FK_ASDCode,
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
GETDATE() AS LASTUPDATEDDATETIME,
IMPORTEDDATE,
Cast(0 as decimal(19,0)) As FLAG,
CASE 
WHEN DATEDIFF(day,STOCKDATE,GETDATE()) BETWEEN 0 AND 30 THEN '0-30'
WHEN DATEDIFF(day,STOCKDATE,GETDATE()) BETWEEN 31 AND 60 THEN '31-60'
WHEN DATEDIFF(day,STOCKDATE,GETDATE()) BETWEEN 61 AND 90 THEN '61-90'
ELSE '>90'
END AS StockAgeingBucket,
DATEDIFF(day,STOCKDATE,GETDATE()) AS StockAgeing,
'' AS EnquiryDaysBucket,
'' AS BookingDaysBucket,
0,
CityBV,
DPP
FROM 
ASM_MC_STOCK_FACT -- (118592 records affected)
--***********************************************************************************

--*******************
--## BOOKING :
--**********************
INSERT INTO ASM_MC_SALES_FACT
(
FK_DEALERCODE,
FK_ASDCode,
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
BRANCHID,
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
BookingDaysBucket,
BaseFlag,
TEHSILID,
LEADTYPE,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource
)
SELECT --DISTINCT
FK_DEALERCODE,
'' AS FK_ASDCode,
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
'' AS StockAgeingBucket,
'' AS StockAgeing,
'' AS EnquiryDaysBucket,
CASE
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 0 and 30 THEN '0-30'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 31 and 60 THEN '31-60'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 61 and 90 THEN '61-90'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 91 and 120 THEN '91-120'
ELSE '>120'
END AS BookingDaysBucket,
0,
TEHSILID,
LEADTYPE,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource
FROM 
ASM_MC_BOOKING_FACT -- (2756 records affected)

--*******************************************************************************

--*********************
--## ALLOCATION :
--*********************

INSERT INTO ASM_MC_SALES_FACT
(
FK_DEALERCODE,
FK_ASDCode,
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
BRANCHID,
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
BookingDaysBucket,
BaseFlag,
TEHSILID
)
SELECT --DISTINCT
FK_DealerCode,
'' AS FK_ASDCode,
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
'' AS StockAgeingBucket,
'' AS StockAgeing,
'' AS EnquiryDaysBucket,
'' AS BookingDaysBucket,
0,
TEHSILID
FROM 
ASM_MC_ALLOCATION_FACT -- (61571 records affected)

--*************************************************************************************

-------------------------------------------VISITED------------------------------------------------------------------------------------------------------------


INSERT INTO ASM_MC_SALES_FACT
(
FK_DEALERCODE,
FK_ASDCode,
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
BRANCHID,
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
BookingDaysBucket,
BaseFlag,
TEHSILID,
SALESPERSON,
LEADTYPE,
SESSIONTIME,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource
)
SELECT --DISTINCT
FK_DEALERCODE,
'' AS FK_ASDCode,
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
'' AS StockAgeingBucket,
'' AS StockAgeing,
CASE 
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 0 AND 30 THEN '0-30'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 31 AND 60 THEN '31-60'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 61 AND 90 THEN '61-90'
WHEN DATEDIFF(day,DATE,GETDATE()) BETWEEN 91 AND 120 THEN '91-120'
ELSE '>120'
END AS EnquiryDaysBucket,
'' AS BookingDaysBucket,
BaseFlag,
TEHSILID,
REPLACE(REPLACE(REPLACE(SALESPERSON,' ',' |'),'| ',''),' |',' ') AS SALESPERSON,
LEADTYPE,
SESSIONTIME,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource
FROM
  ASM_MC_VISITED_FACT 

----------------------------------Audit Log 

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
        'MC',
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