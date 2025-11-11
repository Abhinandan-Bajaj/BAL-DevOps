SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_Full_Load_ASM_CV_SALES_DENORM_REFRESH] AS
BEGIN PRINT('Truncating ASM_CV_SALES_CUSTOM_EBRS table');

/********************************************HISTORY********************************************/
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/
/*  DATE       |  CREATED BY/MODIFIED BY |              CHANGE DESCRIPTION                     */
/*---------------------------------------------------------------------------------------------*/
/*  23/04/2024 |  Robin Singh            |            LSQ  Leadtype logic change               */
/*  09/05/2024 |  Robin Singh            |   Same day retail flag added                        */
/*  08/06/2024 |  Sarvesh Kulkarni       |   Natural key for Product, Product SKU and Taluka dim added */
/*  07/01/2025 |  Nikita Lakhimale            |   Usage Details field addition against Retail  */
/*  12/03/2025 |  Lachmanna           |   Pincode and Aare  against Retail  */
/*  26/03/2025 |  Ashwini Ahire            |First_Source_Lead_Type, First_Mode_Source,   First_Mode_SubSource*/
/*    14/08/2025 |  Richa Mishra            |        Addition of LSQ Targets  */
/*  03/11/2025 |  Ashwini Ahire          | Docdate added                */
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/
/********************************************HISTORY********************************************/






TRUNCATE TABLE [dbo].[ASM_CV_SALES_CUSTOM_EBRS];

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
	/*SUM(
    CASE 
        WHEN FT.Designation IN ('GM', 'M') THEN [FT.TeamTarget]
        ELSE [FT.TargetQuantity]
    END
) AS TargetQuantity, */
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
	--null as lsq_salespersonid,
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
	FT.Recurrence_id, FT.Subgoal, FT.PhoneMobile, FT.Model, FT.TeamTarget,
    FT.DOCDATE

END
GO