SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_MC_SERVICE_TPM_FACT_FULLOAD_P3]
AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			    */
/*--------------------------------------------------------------------------------------------------*/
/* 2025-03-27 	|	Dewang Makani		    | ASM_MC_SPARE_STOCK_DATA  - New Dim Table Created for TPM Moving non-moving */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

PRINT('LOADING DATA FROM Source TABLE')

PRINT('INSERTING DATA INTO ASM_MC_SPARE_STOCK_DATA TABLE')

TRUNCATE TABLE ASM_MC_SPARE_STOCK_DATA;

WITH TotalStock AS (
    SELECT DISTINCT 
        SSD.COMPANYCODE AS DealerCode,
        SSD.BRANCHCODE AS BranchCode,
        IM.itemid AS itemid,
        SSD.TotalStock AS TotalStock,
        SSD.TotalStockValue AS TotalStockValue,
        SSD.Importeddate AS Importeddate
    FROM 
        SPARE_STOCK_DATA_NEW SSD
    INNER JOIN 
        COMPANY_MASTER CM ON (CM.CODE = SSD.COMPANYCODE 
        AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
        AND CM.COMPANYTYPE IN (1, 8))
    INNER JOIN 
        ITEM_MASTER IM ON IM.CODE = SSD.PartCode
    INNER JOIN 
        ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID = IM.ITEMID 
        AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
    WHERE 
        DAY(SSD.IMPORTEDDATE) = '02' 
        AND CAST(SSD.IMPORTEDDATE AS DATE) >= '2024-04-01'
        AND IG.ITEMGROUPTYPE = 'BAL Parts' 
        AND SSD.Branchcode = SSD.CompanyCode
),
ConsumptionData AS (
    SELECT DISTINCT 
        fct.dealercode AS DealerCode,
        CAST(fct.date AS DATE) AS Consumption_date,
        fct.itemid AS Itemid
    FROM 
        ASM_MC_SPARE_BGO_FACT fct
    INNER JOIN 
        branch_master bm 
        ON bm.branchid = fct.branchid 
        AND bm.code = fct.dealercode
    INNER JOIN 
        ITEM_GROUP_DETAIL_NEW IG 
        ON IG.ITEMID = fct.ITEMID 
        AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
    WHERE 
        fct.type IN ('Counter Sale', 'Workshop Sale', 'DealerTrade Sale')  
        AND CAST(fct.date AS DATE) >= '2023-04-01' 
        AND IG.ITEMGROUPTYPE = 'BAL Parts'
    GROUP BY 
        fct.dealercode, 
        fct.itemid,
        CAST(fct.date AS DATE)
)

-- Insert the data into the table
INSERT INTO ASM_MC_SPARE_STOCK_DATA (
    DealerCode,
    BranchCode,
    itemid,
    TotalStock,
    TotalStockValue,
    Importeddate,
    MaxConsumptionDate,
    DateDifference,
    Flag,
	Refreshdate
)
SELECT 
    TS.DealerCode,
    TS.BranchCode,
    TS.itemid,
    TS.TotalStock,
    TS.TotalStockValue,
    DATEADD(DAY, -1, TS.Importeddate) AS [Importeddate],
    MAX(CD.Consumption_date) AS MaxConsumptionDate,
    DATEDIFF(day, MAX(CD.Consumption_date), DATEADD(DAY, -1, TS.Importeddate)) AS DateDifference,
    CASE 
        WHEN DATEDIFF(day, MAX(CD.Consumption_date), DATEADD(DAY, -1, TS.Importeddate))>= 0 AND DATEDIFF(day, MAX(CD.Consumption_date), DATEADD(DAY, -1, TS.Importeddate)) <= 366 THEN 1 
        ELSE 0 
    END AS Flag,
	getdate() as Refreshdate
FROM 
    TotalStock TS
LEFT JOIN 
    ConsumptionData CD 
    ON TS.Dealercode = CD.Dealercode 
    AND TS.itemid = CD.Itemid
    AND CD.Consumption_date <= DATEADD(DAY, -1, TS.Importeddate)
GROUP BY 
    TS.itemid,
    TS.Dealercode,
    TS.BranchCode,
    TS.TotalStock,
    TS.TotalStockValue,
    TS.Importeddate

PRINT('ASM_MC_SPARE_STOCK_DATA TABLE LOADED')

END
GO