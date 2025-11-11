SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_Full_Load_ASM_MC_DENORM_REFRESH_second] AS BEGIN

--***************************START************************************************
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-04-29 	|	Robin Singh		| Added Session Time Field for Mixed Panel          			*/
/*	2024-07-09 	|	Sarvesh Kulkarni	    | Added Source,SubSourceOfEnquiry and Booking status filed to EBRS        */
/*	2024-07-10 	|	Lachmanna    | Added ED.ENQUIRY_STAGE,OPPORTUNITY_STATUS,REASON_FOR_CHOOSING_COMPETITION,IS_ANY_FOLLOWUP_OVERDUE,
 ENQUIRY_ORIGIN,COMPETITION_BRAND,COMPETITION_MODEL and Follow_up_Dispositions,      
     2024-08-13  |    Richa       |  Addtion of NPS */
/*	 2024-09-19  |    Lachmanna       |  Add First source lead type to EBRS */
/*	2024-10-22 	|	Nikita L		| Added  First_Source_Lead_Type in denorm       			*/
/*	2024-12-01 	|	Nikita L		| Added SalesPersonEmail in EBRS			*/
/*	2024-12-15 	|	Nikita L		| case to COALESCE for EMAILADDRESS			*/
/*	2025-06-02 	|	Ashwini A		| Added source, subsource and Feedbackdate			*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/	

DECLARE @year INT = YEAR(GETDATE())-1 ;
DECLARE @start_date DATE = DATEADD(MONTH, 3, DATEFROMPARTS(@year, 1, 1));
DECLARE @end_date DATE = DATEFROMPARTS(@year + 1, 3, 31);
--SELECT @start_date AS StartDate, @end_date AS EndDate;

PRINT 'Start Date: ' + CONVERT(VARCHAR, @start_date, 120);
PRINT 'End Date: ' + CONVERT(VARCHAR, @end_date, 120);

/*
DELETE FROM ASM_MC_SALES_DENORM_MODEL
WHERE DATE > @DATA_DATE;
PRINT('INSERTING DATA IN ASM_MC_SALES_DENORM_MODEL')
INSERT INTO ASM_MC_SALES_DENORM_MODEL
SELECT DATE,
    FISCAL_YEAR,
    MONTH_NAME,
    FISCAL_MONTH,
    CALENDAR_QUARTER,
    FISCAL_QUARTER,
    FISCAL_WEEK,
    CALENDAR_DAY,
    CIRCLE,
    REGION,
    STATE_NAME,
    HUB,
    CITY,
    DEALERNAME,
    DEALERCODE,
    CONCAT(DEALERNAME, '-', CAST(DEALERCODE AS VARCHAR)) AS 'DEALER',
    BRANCH_CODE,
    BRANCH_NAME,
    SALESPERSON,
    TYPEOFCHANNEL,
    SALESCHANNEL,
    ENQUIRYSTATUS,
    MODEOFPURCHASE,
    FINANCECOMPANY,
    IsEXCHANGEAPPLICABLE,
    LEADLOSTREASON,
    FOLLOWUPBUCKET,
    EXCHANGE_STATUS,
    EXCHANGE_MAKE,
    EXCHANGE_MODEL,
    EXCHANGE_MARSHALL_NAME,
    LEADTYPE,
    FK_TYPE,
    ENQUIRY,
    FOLLOWUP_BUCKET_3Hrs,
    FOLLOWUP_BUCKET3_24Hrs,
    FOLLOWUP_BUCKET_24Hrs,
    (
        FOLLOWUP_BUCKET_3Hrs + FOLLOWUP_BUCKET3_24Hrs + FOLLOWUP_BUCKET_24Hrs
    ) as 'TOTAL_FOLLOWUP',
    VISITED -- VISITED
,
    TESTRIDE --TEST RIDE
,
    CUSTOMERCONTACTED --CUSTOMER CONTACTED
,
    EXCHANGE --EXCHANGE
,
    LOST_TO_COMPETETION -- LOST TO COMPETETION
,
    NEED_ASSESMENT -- NEED ASSESSMENT
,
    DEMO -- DEMO
,
    RETAIL -- RETAIL
,
    BOOKING -- BOOKING
,
   NULL as EXCHANGE_PRICE -- INTO TEMPTABLE
,
    RETAIL_IN_1_DAY,
    NULL as ECR,
	ISMIGRATED,
	ENQUIRY_SESSIONTIME_MORETHAN_2MINS,
	First_Source_Lead_Type	
FROM (
        SELECT FT.DATE,
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
            END AS [FISCAL_YEAR],
            CD.MONTH_NAME,
            CD.FISCAL_MONTH,
            CD.CALENDAR_QUARTER,
            CONCAT('Q', CAST(CD.FISCAL_QUARTER AS VARCHAR)) AS FISCAL_QUARTER,
            CD.FISCAL_WEEK,
            CD.CALENDAR_DAY,
            DD.CIRCLE,
            DD.REGION,
            DD.STATE_NAME,
            DD.HUB,
            DD.CITY,
            DD.DEALERNAME,
            DD.DEALERCODE,
            --ASM Name
            BD.BRANCH_CODE,
            BD.BRANCH_NAME,
            FT.SALESPERSON,
            BD.TYPEOFCHANNEL,
            -- 'TYPE OF OUTLET'
            RD.SALESCHANNEL,
            ED.ENQUIRYSTATUS,
            ED.MODEOFPURCHASE,
            ED.FINANCECOMPANY,
            ED.IsEXCHANGEAPPLICABLE,
            ED.LEADLOSTREASON,
            ED.FOLLOWUPBUCKET,
            ED.EXCHANGE_STATUS,
            ED.EXCHANGE_MAKE,
            ED.EXCHANGE_MODEL,
            ED.EXCHANGE_MARSHALL_NAME,
            FT.LEADTYPE,
            FT.FK_TYPE,
            count(
                distinct CASE
                    WHEN FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) as [ENQUIRY] -- FOLLOW UP
,
            COUNT(
                DISTINCT CASE
                    WHEN FOLLOWUPBUCKET = '<3 Hrs'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'FOLLOWUP_BUCKET_3Hrs',
            COUNT(
                DISTINCT CASE
                    WHEN FOLLOWUPBUCKET = '3-24 Hrs'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'FOLLOWUP_BUCKET3_24Hrs',
            COUNT(
                DISTINCT CASE
                    WHEN FOLLOWUPBUCKET = '>24 Hrs'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'FOLLOWUP_BUCKET_24Hrs',
            COUNT(
                DISTINCT CASE
                    WHEN ISVISITED = 'Yes'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'VISITED' -- VISITED
,
            COUNT(
                DISTINCT CASE
                    WHEN ISTESTRIDETAKEN = 'Yes'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'TESTRIDE' --TEST RIDE
,
            COUNT(
                DISTINCT CASE
                    WHEN FT.BASEFLAG = 1
                    AND ED.FIRSTISCUSTOMERCONTACTED = 'YES'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'CUSTOMERCONTACTED' --CUSTOMER CONTACTED
,
            COUNT(
                DISTINCT CASE
                    WHEN ED.IsExchangeApplicable = 'YES'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'EXCHANGE' --EXCHANGE
,
            COUNT(
                DISTINCT CASE
                    WHEN ED.LostToCompetition = 'YES'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'LOST_TO_COMPETETION' -- LOST TO COMPETETION
,
            COUNT(
                DISTINCT CASE
                    WHEN ED.ISNEEDSASSESSMENT = 'YES'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'NEED_ASSESMENT' -- NEED ASSESSMENT
,
            COUNT(
                DISTINCT CASE
                    WHEN ED.ISDEMO = 'YES'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'DEMO' -- DEMO
,
            SUM(
                CASE
                    WHEN FT.FK_TYPE = 10002 and tran_type in ('VSI','AVSI','INST') 
                    THEN FT.ACTUALQUANTITY
                    ELSE NULL
                END
            ) 'RETAIL' -- RETAIL
,
            SUM(
                CASE
                    WHEN FT.FK_TYPE = 10006 THEN FT.ACTUALQUANTITY
                    ELSE NULL
                END
            ) 'BOOKING' -- BOOKING
,
            COUNT(
                DISTINCT CASE
                    WHEN ED.RETAIL_CONVERSION_IN_DAYS IN (0, 1)
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) AS RETAIL_IN_1_DAY
,CASE WHEN ED.ISMIGRATED=1 THEN 'Yes' Else 'No' END AS ISMIGRATED
            --,            SUM( CASE WHEN FT.FK_TYPE = 10002 and tran_type in ('VSI','ASDA') THEN FT.ACTUALQUANTITY ELSE NULL END) 'ECR'
            ,COUNT(
                DISTINCT (CASE
                    WHEN SESSIONTIME>=120
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END)
            ) AS ENQUIRY_SESSIONTIME_MORETHAN_2MINS,
			FT.First_Source_Lead_Type
            
        FROM ASM_MC_SALES_FACT FT
            LEFT JOIN ASM_MC_DEALER_MASTER_DIM DD ON DD.PK_DEALERCODE = FT.FK_DEALERCODE
            LEFT JOIN ASM_MC_BRANCH_MASTER_DIM BD ON FT.BRANCHID = BD.PK_BRANCHID
            LEFT JOIN ASM_MC_PRODUCT_DIM PD ON PD.PK_MODEL_CODE = FT.FK_MODEL_CODE
            LEFT JOIN ASM_MC_PRODUCT_SKU_DIM PSD ON PSD.PK_SKU = FT.FK_SKU
            LEFT JOIN ASM_MC_ENQUIRY_DIM ED ON ED.PK_ENQUIRYHEADERID = FT.FK_ENQUIRYDOCID
            LEFT JOIN ASM_MC_RETAIL_DIM RD ON RD.PK_RETAILHEADERID = FT.FK_RETAILDOCID
            LEFT JOIN ASM_CV_CALENDAR_DIM CD ON FT.DATE = CD.CALENDAR_DATE
        WHERE 1 = 1
            AND FT.FK_TYPE in (10001, 10002, 10006)
            AND FT.DATE > @DATA_DATE
        GROUP BY FT.DATE,
            CASE
                WHEN FISCAL_QUARTER = 4 THEN CONCAT(
                    'FY ',
                    SUBSTRING(CAST ((CALENDAR_YEAR -1) AS VARCHAR), 3, 2),
                    '-',
                    SUBSTRING(CAST ((CALENDAR_YEAR) AS VARCHAR), 3, 2)
                )
                ELSE CONCAT(
                    'FY ',
                    SUBSTRING(CAST ((CALENDAR_YEAR) AS VARCHAR), 3, 2),
                    '-',
                    SUBSTRING(CAST ((FISCAL_YEAR + 1) AS VARCHAR), 3, 2)
                )
            END,
            CD.FISCAL_MONTH,
            CD.MONTH_NAME,
            CD.CALENDAR_QUARTER,
            CD.FISCAL_QUARTER,
            CONCAT('Q', CAST(CD.FISCAL_QUARTER AS VARCHAR)),
            CD.FISCAL_WEEK,
            CD.CALENDAR_DAY,
            DD.CIRCLE,
            DD.REGION,
            DD.STATE_NAME,
            DD.HUB,
            DD.CITY,
            DD.DEALERNAME,
            DD.DEALERCODE,
            BD.BRANCH_CODE,
            BD.BRANCH_NAME,
            FT.SALESPERSON,
            BD.TYPEOFCHANNEL,
            RD.SALESCHANNEL,
            ED.ENQUIRYSTATUS,
            ED.MODEOFPURCHASE,
            ED.FINANCECOMPANY,
            ED.IsEXCHANGEAPPLICABLE,
            ED.LEADLOSTREASON,
            ED.FOLLOWUPBUCKET,
            ED.EXCHANGE_STATUS,
            ED.EXCHANGE_MAKE,
            ED.EXCHANGE_MODEL,
            ED.EXCHANGE_MARSHALL_NAME,
            FT.LEADTYPE,
            FT.FK_TYPE,
            FK_DEALERCODE,
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
            END,
            CASE WHEN ED.ISMIGRATED=1 THEN 'Yes' Else 'No' END,
	FT.First_Source_Lead_Type

    ) base;
PRINT('DATA INSERTED IN ASM_MC_SALES_DENORM_MODEL');
*/

--DELETE FROM ASM_MC_SALES_CUSTOM_EBRS
--WHERE DATE > @DATA_DATE;
--PRINT(
--    'Deleted last 120 days data from ASM_MC_SALES_CUSTOM_EBRS table'
--)

--TRUNCATE table ASM_MC_SALES_CUSTOM_EBRS
----------------------------------------------------------------
INSERT INTO ASM_MC_SALES_CUSTOM_EBRS
SELECT FT.Date,
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
    PD.Modelcode,
    PSD.SKU_CODE,
    FT.CompanyType,
    FT.BRANCHID,
    FT.StockStatus,
    FT.FLAG,
    FT.BaseFlag,
    FT.SALESPERSON,
    FT.PLANT,
    FT.LEADTYPE,
    FT.FK_TYPE,
    DD.CIRCLE,
    DD.REGION,
    DD.STATE_NAME,
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
    BD.TYPEOFCHANNEL,
    RD.SALESCHANNEL,
    RD.EXCHANGESTATUS as EXCHANGESTATUS_RETAIL,
    RD.INSURER_DETAIL,
    RD.MODEOFPURCHASE AS MODEOFPURCHASE_RETAIL,
    ED.ENQUIRYSTATUS,
    ED.MODEOFPURCHASE AS MODEOFPURCHASE_ENQUIRY, --enquiry
    ED.FINANCECOMPANY,
    ED.IsEXCHANGEAPPLICABLE,
    ED.LEADLOSTREASON,
    ED.FOLLOWUPBUCKET,
    ED.EXCHANGE_STATUS as EXCHANGE_STATUS_ENQUIRY,
    ED.EXCHANGE_MAKE,
    ED.EXCHANGE_MODEL,
    ED.EXCHANGE_MARSHALL_NAME,
	ED.FIRSTISCUSTOMERCONTACTED,
	ED.ISDEMO,
ED.ISNEEDSASSESSMENT,
ED.IsTestRideTaken,
ED.ISVISITED,
ED.RetailConversionFlag,
ED.RETAIL_CONVERSION_IN_DAYS,
ED.LostToCompetition,
    SUM([Stock Value]) AS [Stock Value],
    SUM([Stock Quantity]) AS [Stock Quantity],
    SUM([TargetQuantity]) AS TargetQuantity,
    SUM([ActualQuantity]) AS ActualQuantity,
    SUM([Pending_Orders]) AS Pending_Orders,
    SUM([Actual BG]) AS [Actual BG],
    SUM([Target BG]) AS [Target BG],
	CASE WHEN ED.ISMIGRATED=1 THEN 'Yes' Else 'No' END AS ISMIGRATED,
	FT.TRAN_TYPE,
     SUM(SESSIONTIME) SESSIONTIME,
     BKD.[BOOKING STATUS],
	 ED.SourceType,
	 ED.SubSourceOfEnquiry,
	 ED.ENQUIRY_STAGE,
	 ED.OPPORTUNITY_STATUS,
	 ED.REASON_FOR_CHOOSING_COMPETITION,	
	 ED.IS_ANY_FOLLOWUP_OVERDUE,
	 ED.ENQUIRY_ORIGIN,
	 ED.COMPETITION_BRAND,
	 ED.COMPETITION_MODEL,
	 ED.Follow_up_Dispositions,
	 
	 COUNT(
                DISTINCT CASE
                    WHEN FOLLOWUPBUCKET = '<3 Hrs'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'FOLLOWUP_BUCKET_3Hrs',
            COUNT(
                DISTINCT CASE
                    WHEN FOLLOWUPBUCKET = '3-24 Hrs'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'FOLLOWUP_BUCKET3_24Hrs',
            COUNT(
                DISTINCT CASE
                    WHEN FOLLOWUPBUCKET = '>24 Hrs'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'FOLLOWUP_BUCKET_24Hrs',
			(
				COUNT( DISTINCT CASE WHEN FOLLOWUPBUCKET = '<3 Hrs' AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID ELSE NULL END)
				+  COUNT( DISTINCT CASE WHEN FOLLOWUPBUCKET = '3-24 Hrs' AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID ELSE NULL END )
				+  COUNT( DISTINCT CASE WHEN FOLLOWUPBUCKET = '>24 Hrs' AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID  ELSE NULL END )
			) as 'TOTAL_FOLLOWUP',
            COUNT(
                DISTINCT CASE
                    WHEN ISVISITED = 'Yes'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'VISITED' -- VISITED
,
            COUNT(
                DISTINCT CASE
                    WHEN ISTESTRIDETAKEN = 'Yes'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'TESTRIDE' --TEST RIDE
,
            COUNT(
                DISTINCT CASE
                    WHEN FT.BASEFLAG = 1
                    AND ED.FIRSTISCUSTOMERCONTACTED = 'YES'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'CUSTOMERCONTACTED' --CUSTOMER CONTACTED
,
           
            COUNT(
                DISTINCT CASE
                    WHEN ED.LostToCompetition = 'YES'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'LOST_TO_COMPETETION' -- LOST TO COMPETETION
,
            COUNT(
                DISTINCT CASE
                    WHEN ED.ISNEEDSASSESSMENT = 'YES'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'NEED_ASSESMENT' -- NEED ASSESSMENT
,
            COUNT(
                DISTINCT CASE
                    WHEN ED.ISDEMO = 'YES'
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) 'DEMO' -- DEMO
,
            SUM(
                CASE
                    WHEN FT.FK_TYPE = 10002  and tran_type in ('VSI','AVSI','INST') 
                    THEN FT.ACTUALQUANTITY
                    ELSE NULL
                END
            ) 'RETAIL' -- RETAIL
,
            SUM(
                CASE
                    WHEN FT.FK_TYPE = 10006 THEN FT.ACTUALQUANTITY
                    ELSE NULL
                END
            ) 'BOOKING' -- BOOKING
,
            COUNT(
                DISTINCT CASE
                    WHEN ED.RETAIL_CONVERSION_IN_DAYS IN (0, 1)
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END
            ) AS RETAIL_IN_1_DAY,
			
			COUNT(
                DISTINCT (CASE
                    WHEN SESSIONTIME>=120
                    AND FT.FK_TYPE = 10001 THEN FK_ENQUIRYDOCID
                    ELSE NULL
                END)
            ) AS ENQUIRY_SESSIONTIME_MORETHAN_2MINS,	 
    FT.First_Source_Lead_Type,
	 ED.NPSKEY,
    ED.CUSTOMERTYPE,
    ED.L2DRIVERA,
COALESCE( ED.EMAILADDRESS , RD.SALESPERSONEMAIL),
    FT.First_Mode_Source,
    FT.First_Mode_SubSource
    --ED.FeedbackDate

			
    
FROM dbo.ASM_MC_SALES_FACT FT
    LEFT JOIN ASM_MC_DEALER_MASTER_DIM DD ON DD.PK_DEALERCODE = FT.FK_DEALERCODE
    LEFT JOIN ASM_MC_BRANCH_MASTER_DIM BD ON FT.BRANCHID = BD.PK_BRANCHID
    LEFT JOIN ASM_MC_ENQUIRY_DIM ED ON ED.PK_ENQUIRYHEADERID = FT.FK_ENQUIRYDOCID
    LEFT JOIN ASM_MC_RETAIL_DIM RD ON RD.PK_RETAILHEADERID = FT.FK_RETAILDOCID
	LEFT JOIN ASM_MC_BOOKING_DIM BKD ON BKD.PK_BOOKINGHEADERID = FT.FK_BookingDocID
    LEFT JOIN ASM_CV_CALENDAR_DIM CD ON FT.DATE = CD.CALENDAR_DATE
    LEFT JOIN ASM_MC_PRODUCT_DIM PD ON PD.PK_MODEL_CODE = FT.FK_MODEL_CODE
    LEFT JOIN ASM_MC_PRODUCT_SKU_DIM PSD ON PSD.PK_SKU = FT.FK_SKU
WHERE FT.DATE between  @start_date  and   @end_date 
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
    END,
    CD.MONTH_NAME,
    CD.FISCAL_MONTH,
    CD.CALENDAR_QUARTER,
    CONCAT('Q', CAST(CD.FISCAL_QUARTER AS VARCHAR)),
    CD.FISCAL_WEEK,
    CD.CALENDAR_DAY,
    FT.FK_EnquiryDocID,
    PD.Modelcode,
    PSD.SKU_CODE,
    FT.CompanyType,
    FT.BRANCHID,
    FT.StockStatus,
    FT.FLAG,
    FT.BaseFlag,
    FT.SALESPERSON,
    FT.PLANT,
    FT.LEADTYPE,
    FT.FK_TYPE,
	CASE WHEN ED.ISMIGRATED=1 THEN 'Yes' Else 'No' End,
    FT.TRAN_TYPE,
    DD.CIRCLE,
    DD.REGION,
    DD.STATE_NAME,
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
    BD.TYPEOFCHANNEL,
    RD.SALESCHANNEL,
    RD.EXCHANGESTATUS,
    RD.INSURER_DETAIL,
    RD.MODEOFPURCHASE,
    ED.ENQUIRYSTATUS,
    ED.MODEOFPURCHASE, --enquiry
    ED.FINANCECOMPANY,
    ED.IsEXCHANGEAPPLICABLE,
    ED.LEADLOSTREASON,
    ED.FOLLOWUPBUCKET,
    ED.EXCHANGE_STATUS,
    ED.EXCHANGE_MAKE,
    ED.EXCHANGE_MODEL,
    ED.EXCHANGE_MARSHALL_NAME,
	ED.FIRSTISCUSTOMERCONTACTED,
	ED.ISDEMO,
ED.ISNEEDSASSESSMENT,
ED.IsTestRideTaken,
ED.ISVISITED,
ED.RetailConversionFlag,
ED.RETAIL_CONVERSION_IN_DAYS,
ED.LostToCompetition,
ED.SourceType,
ED.SubSourceOfEnquiry,
ED.ENQUIRY_STAGE,
ED.OPPORTUNITY_STATUS,
ED.REASON_FOR_CHOOSING_COMPETITION,	
ED.IS_ANY_FOLLOWUP_OVERDUE,
ED.ENQUIRY_ORIGIN,
ED.COMPETITION_BRAND,
ED.COMPETITION_MODEL,
BKD.[BOOKING STATUS],
ED.Follow_up_Dispositions,
FT.First_Source_Lead_Type,
ED.NPSKEY,
ED.CUSTOMERTYPE,
ED.L2DRIVERA,
COALESCE( ED.EMAILADDRESS , RD.SALESPERSONEMAIL ),
FT.First_Mode_Source,
FT.First_Mode_SubSource
--ED.FeedbackDate


PRINT('DATA INSERTED IN ASM_MC_SALES_CUSTOM_EBRS');

END
GO