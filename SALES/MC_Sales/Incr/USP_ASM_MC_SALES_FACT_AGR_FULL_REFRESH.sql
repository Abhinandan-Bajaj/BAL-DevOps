SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_MC_SALES_FACT_AGR_FULL_REFRESH] AS


--***************************START************************************************
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-04-29 	|	Robin Singh		| Added Session Time Field for Mixed Panel          			*/
/*	2024-10-22 	|	Nikita L		| Added  First_Source_Lead_Type in AGGR       			*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/	




TRUNCATE TABLE [dbo].[ASM_MC_SALES_FACT_AGR];

INSERT INTO ASM_MC_SALES_FACT_AGR 
SELECT DD.DealerCode,
    [FK_ASDCode],
    PSD.SKU_CODE,
    [FK_Type],
    [Date],
    [FK_EnquiryDocID],
    [FK_BookingDocID],
    [FK_AllocationDocID],
    PD.ModelCode,
    [CompanyType],
    [BRANCHID],
    [FK_RetailDocID],
    [StockStatus],
    [FLAG],
    [StockAgeingBucket],
    [EnquiryDaysBucket],
    [BookingDaysBucket],
    [BaseFlag],
    [SALESPERSON],
    [PLANT],
    [LEADTYPE],
    DD.CIRCLE,
    DD.REGION,
    DD.STATE_NAME,
    DD.HUB,
    DD.CITY,
    DD.DEALERNAME,
    CONCAT(DD.DEALERNAME, '-', CAST(CAST(DD.DEALERCODE as int) AS VARCHAR)) AS 'DEALER',
	BD.BRANCH_CODE,
	BD.BRANCH_NAME,
    COUNT([SalesFactID]) AS Ct,
    SUM([Stock Value]) AS [Stock Value],
    SUM([Stock Quantity]) AS [Stock Quantity],
    SUM([TargetQuantity]) AS TargetQuantity,
    SUM([ActualQuantity]) AS ActualQuantity,
    SUM([Pending_Orders]) AS Pending_Orders,
    SUM([BAL Outstanding (O/S)]) AS [BAL Outstanding (O/S)],
    SUM([Bank Outstanding (O/S)]) AS [Bank Outstanding (O/S)],
    SUM([Remittance (In Lakh)]) AS [Remittance (In Lakh)],
    SUM([Target Own Funds (OF)]) AS [Target Own Funds (OF)],
    SUM([Actual BG]) AS [Actual BG],
    SUM([Target BG]) AS [Target BG],
	TRAN_TYPE,
	SUM(SESSIONTIME) SESSIONTIME,
	FT.First_Source_Lead_Type
FROM dbo.ASM_MC_SALES_FACT FT
    LEFT JOIN ASM_MC_DEALER_MASTER_DIM DD ON DD.PK_DEALERCODE = FT.FK_DEALERCODE
	LEFT JOIN ASM_MC_BRANCH_MASTER_DIM BD ON FT.BRANCHID = BD.PK_BRANCHID
    LEFT JOIN ASM_MC_PRODUCT_DIM PD ON PD.PK_MODEL_CODE = FT.FK_MODEL_CODE
    LEFT JOIN ASM_MC_PRODUCT_SKU_DIM PSD ON PSD.PK_SKU = FT.FK_SKU
GROUP BY DD.DealerCode,
    [FK_ASDCode],
    [SKU_CODE],
    [FK_Type],
    [Date],
    [FK_EnquiryDocID],
    [FK_BookingDocID],
    [FK_AllocationDocID],
    PD.ModelCode,
    [CompanyType],
    [BRANCHID],
    [FK_RetailDocID],
    [StockStatus],
    [FLAG],
    [StockAgeingBucket],
    [EnquiryDaysBucket],
    [BookingDaysBucket],
    [BaseFlag],
    [SALESPERSON],
    [PLANT],
    [LEADTYPE],
    DD.CIRCLE,
    DD.REGION,
    DD.STATE_NAME,
    DD.HUB,
    DD.CITY,
    DD.DEALERNAME,
    CONCAT(DD.DEALERNAME, '-', CAST(DD.DEALERCODE AS VARCHAR)),
	BD.BRANCH_CODE,
	BD.BRANCH_NAME,
    TRAN_TYPE,
	FT.First_Source_Lead_Type
	GO