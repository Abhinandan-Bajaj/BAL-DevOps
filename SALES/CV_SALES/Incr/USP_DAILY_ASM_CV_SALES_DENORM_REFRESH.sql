SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_DAILY_ASM_CV_SALES_DENORM_REFRESH] AS
BEGIN 

--***********************************************************************************************************************

/********************************************HISTORY********************************************/
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/
/*  DATE       |  CREATED BY/MODIFIED BY |              CHANGE DESCRIPTION                     */
/*---------------------------------------------------------------------------------------------*/
/*  19/07/2024 |  Sarvesh Kulkarni       |           Created SP for daily execution    */
/*  08/06/2024 |  Sarvesh Kulkarni       |   Natural key for Product, Product SKU and Taluka dim added */
/*  07/01/2025 |  Nikita Lakhimale            |   Usage Details field addition against Retail  */
/*  12/03/2025 |  Lachmanna           |   Pincode and Aare  against Retail  */
/*  26/03/2025 |  Ashwini Ahire            |First_Source_Lead_Type, First_Mode_Source,   First_Mode_SubSource*/
/*    14/08/2025 |  Richa Mishra            |        Addition of LSQ Targets  */
/*  03/11/2025 |  Ashwini Ahire          | Docdate added                */
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/
/********************************************HISTORY********************************************/

/* Step 1 : Loading USP_DAILY_ASM_CV_SALES_DENORM_REFRESH  */

DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_DAILY_ASM_CV_SALES_DENORM_REFRESH';
----------------------------------------------------------------
    -- Audit Segment 1: ASM_CV_SALES_CUSTOM_EBRS
----------------------------------------------------------------  

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			@table_name1 VARCHAR(128) = 'ASM_CV_SALES_CUSTOM_EBRS', 
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT,   
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX);  
BEGIN TRY

DECLARE @DATA_DATE DATE;
SET @DATA_DATE = DATEADD(DAY, -60, CAST(GETDATE() AS date));
PRINT(@DATA_DATE);
PRINT(
    'Deleted last 60 days data from ASM_CV_SALES_CUSTOM_EBRS table'
)
DELETE FROM ASM_CV_SALES_CUSTOM_EBRS
WHERE DATE > @DATA_DATE;
PRINT('INSERTING DATA IN ASM_CV_SALES_CUSTOM_EBRS')

INSERT INTO ASM_CV_SALES_CUSTOM_EBRS
SELECT 
FT.Date,
    CASE
        WHEN FISCAL_QUARTER = 4 THEN CONCAT(
            'FY ',
            CAST((CALENDAR_YEAR -1) AS VARCHAR),
            '-',
            SUBSTRING(CAST((CALENDAR_YEAR) AS VARCHAR), 3, 2)
        )
        ELSE CONCAT(
            'FY ',
            CAST((CALENDAR_YEAR) AS VARCHAR),
            '-',
            SUBSTRING(CAST((FISCAL_YEAR + 1) AS VARCHAR), 3, 2)
        )
    END AS FISCAL_YEAR,
    CD.MONTH_NAME,
    CD.FISCAL_MONTH,
    CD.CALENDAR_QUARTER,
    CONCAT('Q', CAST(CD.FISCAL_QUARTER AS VARCHAR)) AS FISCAL_QUARTER,
    CD.FISCAL_WEEK,
    CD.CALENDAR_DAY,
    FT.FK_EnquiryDocID,
    FT.FK_Model_Code,
    FT.FK_SKU,
    FT.CompanyType,
    FT.FK_BRANCHID,
    FT.StockStatus,
    FT.FLAG,
    FT.BaseFlag,
    FT.SALES_PERSON,
    --FT.PLANT,
    FT.LEADTYPE,
    FT.FK_TYPE,
--    FT.TRAN_TYPE,
    DD.CIRCLE,
    DD.REGION,
    DD.STATE_NAME,
	TD.TALUKA_NAME,
    DD.HUB,
    DD.CITY,
    DD.DEALERNAME,
    DD.DEALERCODE,
    CONCAT(
        DD.DEALERNAME,
        '-',
        CAST(DD.DEALERCODE AS VARCHAR)
    ) AS 'DEALER',
    BD.BRANCH_CODE,
    BD.BRANCH_NAME,
    --BD.TYPEOFCHANNEL,
    --RD.SALESCHANNEL,
    RD.EXCHANGESTATUS as EXCHANGESTATUS_RETAIL,
    --RD.INSURER_DETAIL,
    RD.MODEOFPURCHASE AS MODEOFPURCHASE_RETAIL,
    ED.ENQUIRYSTATUS,
    ED.MODEOFPURCHASE AS MODEOFPURCHASE_ENQUIRY, --enquiry
    RD.FINANCECOMPANY,
    ED.IsEXCHANGEAPPLICABLE,
    ED.LEADLOSTREASON,
    ED.FOLLOWUPBUCKET,
	ED.FIRSTISCUSTOMERCONTACTED,
	ED.ISDEMO,
ED.ISNEEDSASSESSMENT,
ED.IsTestRideTaken,
ED.ISVISITED,
ED.RetailConversionFlag,
ED.CustomerOwnershipProfileId, -- new
ED.EnquiryLeadSource,
ED.EnquirySubSource,
FT.Campaign_Code,--new
BOD.[BOOKING STATUS]
,RD.FUEL_TYPE_EXCHANGE_OEM, --new
ED.LostToCompetition,
ED.MODEOFPURCHASE,
RD.EXCHANGESTATUS,
CASE WHEN FT.FK_TYPE=10001 THEN ED.USAGEDETAILS 
	WHEN FT.FK_TYPE=10002 THEN RD.USAGEDETAILS END,
ED.TestRideOffered,
RD.FINANCECATEGORY, -- new
    SUM([Stock Value]) AS [Stock Value],
    SUM([Stock Quantity]) AS [Stock Quantity],
       SUM([TargetQuantity]) AS TargetQuantity,
    SUM([ActualQuantity]) AS ActualQuantity,
    SUM([Pending_Orders]) AS Pending_Orders,
    SUM([Actual BG]) AS [Actual BG],
    SUM([Target BG]) AS [Target BG],
GETDATE() as Refresh_Date,
    ED.IS_ANY_FOLLOWUP_OVERDUE,
	ED.ENQUIRY_ORIGIN,
	FT.IS_SAMEDAYRETAIL,
	ED.ENQUIRY_STAGE, 
    ED.OPPORTUNITY_STATUS,
	PD.[ModelCode],
	PSD.[SKU_CODE],
	TD.[TALUKA_CODE],
		FT.Pincode,
    FT.Area,
FT.First_Source_Lead_Type,
FT.First_Mode_Source,
FT.First_Mode_SubSource,
Case 
	when FT.Flag=100021 and FT.FK_TYPE=10002  then FT.RetailSalesperson_id
	else FT.Salesperson_id end,
	FT.Designation,
	FT.Recurrence_id,
	FT.Subgoal,
    FT.PhoneMobile,
	FT.Model,
SUM(CAST([TeamTarget] AS BIGINT)) AS TotalTarget,
FT.DOCDATE
FROM  dbo.ASM_CV_SALES_FACT FT
    LEFT JOIN ASM_CV_DEALER_MASTER_DIM DD ON DD.PK_DEALERCODE = FT.FK_DEALERCODE
    LEFT JOIN ASM_CV_BRANCH_MASTER_DIM BD ON FT.FK_BRANCHID = BD.PK_BRANCHID
	LEFT JOIN ASM_CV_TALUKA_MASTER_DIM TD ON TD.PK_TALUKAID = FT.FK_TALUKAID
    LEFT JOIN ASM_CV_ENQUIRY_DIM ED ON ED.PK_ENQUIRYHEADERID = FT.FK_ENQUIRYDOCID
    LEFT JOIN ASM_CV_RETAIL_DIM RD ON RD.PK_RETAILHEADERID = FT.FK_RETAILDOCID
    LEFT JOIN ASM_CV_CALENDAR_DIM CD ON FT.DATE = CD.CALENDAR_DATE
	LEFT JOIN ASM_CV_BOOKING_DIM BOD ON  BOD.PK_BOOKINGHEADERID = FT.FK_BookingDocID
	LEFT JOIN ASM_CV_PRODUCT_DIM PD ON PD.PK_MODEL_CODE = FT.FK_MODEL_CODE
    LEFT JOIN ASM_CV_PRODUCT_SKU_DIM PSD ON PSD.PK_SKU = FT.FK_SKU

WHERE 1=1 
AND FT.DATE > @DATA_DATE
GROUP BY FT.Date,
    CASE
        WHEN FISCAL_QUARTER = 4 THEN CONCAT(
            'FY ',
            CAST((CALENDAR_YEAR -1) AS VARCHAR),
            '-',
            SUBSTRING(CAST((CALENDAR_YEAR) AS VARCHAR), 3, 2)
        )
        ELSE CONCAT(
            'FY ',
            CAST((CALENDAR_YEAR) AS VARCHAR),
            '-',
            SUBSTRING(CAST((FISCAL_YEAR + 1) AS VARCHAR), 3, 2)
        )
    END ,
    CD.MONTH_NAME,
    CD.FISCAL_MONTH,
    CD.CALENDAR_QUARTER,
    CONCAT('Q', CAST(CD.FISCAL_QUARTER AS VARCHAR)),
    CD.FISCAL_WEEK,
    CD.CALENDAR_DAY,
    FT.FK_EnquiryDocID,
    FT.FK_Model_Code,
    FT.FK_SKU,
    FT.CompanyType,
    FT.FK_BRANCHID,
    FT.StockStatus,
    FT.FLAG,
    FT.BaseFlag,
    FT.SALES_PERSON,
    --FT.PLANT,
    FT.LEADTYPE,
    FT.FK_TYPE,
--    FT.TRAN_TYPE,
    DD.CIRCLE,
    DD.REGION,
    DD.STATE_NAME,
	TD.TALUKA_NAME,
    DD.HUB,
    DD.CITY,
    DD.DEALERNAME,
    DD.DEALERCODE,
    CONCAT(
        DD.DEALERNAME,
        '-',
        CAST(DD.DEALERCODE AS VARCHAR)
    ) ,
    BD.BRANCH_CODE,
    BD.BRANCH_NAME,
    --BD.TYPEOFCHANNEL,
    --RD.SALESCHANNEL,
    RD.EXCHANGESTATUS ,
    --RD.INSURER_DETAIL,
    RD.MODEOFPURCHASE ,
    ED.ENQUIRYSTATUS,
    ED.MODEOFPURCHASE , --enquiry
    RD.FINANCECOMPANY,
    ED.IsEXCHANGEAPPLICABLE,
    ED.LEADLOSTREASON,
    ED.FOLLOWUPBUCKET,
	ED.FIRSTISCUSTOMERCONTACTED,
	ED.ISDEMO,
ED.ISNEEDSASSESSMENT,
ED.IsTestRideTaken,
ED.ISVISITED,
ED.RetailConversionFlag,
ED.CustomerOwnershipProfileId,
ED.EnquiryLeadSource,
ED.EnquirySubSource,
FT.Campaign_Code,
BOD.[BOOKING STATUS]
,RD.FUEL_TYPE_EXCHANGE_OEM, 
ED.LostToCompetition,
ED.MODEOFPURCHASE,
RD.EXCHANGESTATUS,
CASE WHEN FT.FK_TYPE=10001 THEN ED.USAGEDETAILS 
	WHEN FT.FK_TYPE=10002 THEN RD.USAGEDETAILS END,
ED.TestRideOffered,
RD.FINANCECATEGORY,
ED.IS_ANY_FOLLOWUP_OVERDUE,
ED.ENQUIRY_ORIGIN,
FT.IS_SAMEDAYRETAIL,
ED.ENQUIRY_STAGE, 
ED.OPPORTUNITY_STATUS,
PD.[ModelCode],
PSD.[SKU_CODE],
TD.[TALUKA_CODE],
FT.Pincode,
FT.Area,
FT.First_Source_Lead_Type,
FT.First_Mode_Source,
FT.First_Mode_SubSource,
FT.Salesperson_id,FT.RetailSalesperson_id,
	FT.Designation,
	FT.Recurrence_id,
	FT.Subgoal,
	FT.PhoneMobile, FT.Model, FT.TeamTarget,
    FT.DOCDATE

    
----------------------------------Audit Log Target

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
        'CV',
        @StartDate_utc1,
        @EndDate_utc1,
		@StartDate_ist1,
        @EndDate_ist1,
        @Duration1,  
        0,
        0,
        @Status1,
        @ErrorMessage1;

END
GO
