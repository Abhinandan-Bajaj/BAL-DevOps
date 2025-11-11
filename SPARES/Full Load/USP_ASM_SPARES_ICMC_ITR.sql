
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


Alter PROC [dbo].[USP_ASM_SPARES_ICMC_ITR]
AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			                            */
/*--------------------------------------------------------------------------------------------------*/
/*	2025-03-13 	|	 	Aswani	  |        Initiation of the SP. Calculating the Inventory turnover Ratio  */
/*	2025-06-10 	|	 	Lachmanna	  |        add code last 5 months + current month logic */
/*	2025-06-30	|		Aswani	  |		   Updated the BU column from company_master to             */ 
/*										   SAP_CUSTOMER_MASTER_KNA1									*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

PRINT('LOADING DATA FROM Source TABLE')
----------------------------------------USP_ASM_SPARES_ICMC_ITR------------------------------------
DECLARE @Today DATE = CAST(GETDATE() AS DATE);
DECLARE @StartOfCurrentMonth DATE = DATEADD(MONTH, DATEDIFF(MONTH, 0, @Today), 0);
DECLARE @StartOfSixMonthsAgo DATE = DATEADD(MONTH, -5, @StartOfCurrentMonth); -- 5 full months ago + current month
-------------------------------------------------------------------------------------------------
WITH INVOICED_QTY AS (
select  
DATEADD(month, DATEDIFF(month, 0, BILLING_DATE), 0) AS BILLING_MONTH,
BU,
INVOICE_MATERIAL, SUM(ACTUAL_BILLED_QTY) as ACTUAL_BILLED_QTY
from (SELECT DISTINCT A.ORDER_NO,A.INVOICE_ITEM,A.INVOICE_MATERIAL,A.INVOICE_NUMBER, A.ACTUAL_BILLED_QTY,A.SOLD_TO_DEALER_OR_DISTRIBUTOR,
    A.billing_date, A.distribution_channel,INVOICE_CANCELLATION,
    CASE WHEN CM.KATR6='2WH' THEN '2W'
     WHEN CM.KATR6='3WH' THEN '3W'
     ELSE NULL END AS BU
    FROM VW_SPARES_ICMC_ODI_DATA A
    LEFT JOIN SAP_CUSTOMER_MASTER_KNA1 CM 
ON A.sold_to_dealer_or_distributor=CM.KUNNR 
WHERE A.sales_organization='ZDOM' and A.invoice_division='B1'  and A.distribution_channel in (10,20)  
and A.billing_type_analytics in ('ZSTD','ZSCH','ZVOR','ZPSD','ZPSH','ZPVR','ZSPD','ZSPD') 
AND A.billing_date IS NOT NULL 
and CM.KATR6 IN ('2WH','3WH') 
AND FKSTO<>'X'
AND billing_date BETWEEN @StartOfSixMonthsAgo and @Today
) A 
GROUP BY  DATEADD(month, DATEDIFF(month, 0, BILLING_DATE), 0),INVOICE_MATERIAL , BU
),

ATP AS (
SELECT distinct ATP_MONTH, MATERIAL,MIN_ATP_QTY, MAX_ATP_QTY
FROM (
SELECT DATEADD(month, DATEDIFF(month, 0, STOCK_DATE), 0) as ATP_MONTH, MATERIAL,
    FIRST_VALUE([QTY]) OVER (PARTITION BY [MATERIAL], DATEADD(month, DATEDIFF(month, 0, STOCK_DATE), 0) ORDER BY CAST([STOCK_DATE] as DATE) ASC) AS MIN_ATP_QTY,
    FIRST_VALUE([QTY]) OVER (PARTITION BY [MATERIAL], DATEADD(month, DATEDIFF(month, 0, STOCK_DATE), 0) ORDER BY CAST([STOCK_DATE] as DATE) DESC) AS MAX_ATP_QTY
FROM (
    SELECT 
        DATALOADDATE as Stock_Date,
        MATNR_Item_Code as Material, 
        SHPRO_Item_Segment as BU, 
        SUM(cast(LABST_Unrestricted_Stock as float)) as QTY
    FROM SPD_ATP
    WHERE LGORT_Storage_Location in ('SPR1', 'SPR2', 'SPR3', 'SP01', 'SP02', 'SP03') AND  WERKS_Plant in ('WA02','PT02')
    GROUP BY DATALOADDATE, MATNR_Item_Code, SHPRO_Item_Segment

    ) URS 
    --ORDER BY DATALOADDATE
) A
),

PO_RATE AS (
SELECT MATERIAL_NUMBER, PO_RATE
FROM (
SELECT *, DENSE_RANK() OVER(PARTITION BY MATERIAL_NUMBER ORDER BY PO_RATE DESC) AS RNK
FROM (
SELECT DISTINCT MATERIAL_NUMBER, PO_RATE
FROM  dbo.SPD_SCHDULE_ADHERENCE
WHERE MATERIAL_NUMBER is not null ) A ) RNKN
WHERE RNK = 1
),

BU_TABLE as (SELECT MATNR, SHPRO
FROM (
SELECT MATNR, CREATED_ON, SHPRO, RANK() OVER (PARTITION BY MATNR ORDER BY CREATED_ON DESC, SHPRO) as RNK
FROM (SELECT DISTINCT MATNR, CREATED_ON, SHPRO
FROM SAP_YPIM481
WHERE MATNR is not null AND SHPRO <>'') A )B 
WHERE RNK = 1
),


CAL_CTE as (
SELECT 
IQ.BILLING_MONTH as IN_DATE, 
IQ.INVOICE_MATERIAL as MATERIAL, 
ISNULL(B.SHPRO,IQ.BU) as BU ,
IQ.ACTUAL_BILLED_QTY, 
PR.PO_RATE, 
(ATP.MIN_ATP_QTY + ATP.MAX_ATP_QTY) / 2 as AVGE,
IQ.ACTUAL_BILLED_QTY * ISNULL(PR.PO_RATE,0) as COGS,
ISNULL((ATP.MIN_ATP_QTY + ATP.MAX_ATP_QTY) / 2 ,0) * ISNULL(PR.PO_RATE,0) as AVG_STOCK_VAL
FROM INVOICED_QTY IQ 
LEFT JOIN ATP
ON IQ.BILLING_MONTH = ATP.ATP_MONTH AND IQ.INVOICE_MATERIAL = ATP.MATERIAL
LEFT JOIN PO_RATE PR
ON IQ.INVOICE_MATERIAL = PR.MATERIAL_NUMBER
LEFT JOIN BU_TABLE B
ON IQ.INVOICE_MATERIAL = B.MATNR 
)SELECT * INTO #CAL_CTE FROM CAL_CTE;

IF NOT EXISTS (SELECT 1 FROM SPARES_INVENTORY_TURN_RATIO_FACT)
BEGIN
    PRINT 'Table is empty. Loading data for last 6 months (5 full months + current month).';

    INSERT INTO SPARES_INVENTORY_TURN_RATIO_FACT
    (
        [DATE],
        [BU],
        [NUM],
        [DENO],
        [CREATE_DATE]
    )
    SELECT 
        CAST(IN_DATE AS DATE) AS DATE, 
        BU, 
        SUM(COGS) AS NUM, 
        SUM(AVG_STOCK_VAL) AS DENO,
        @Today AS CREATE_DATE
    FROM #CAL_CTE
    WHERE IN_DATE >= @StartOfSixMonthsAgo AND IN_DATE <= @Today
    GROUP BY IN_DATE, BU;
END
ELSE
BEGIN
    PRINT 'Table has data. Refreshing current month only.';
DELETE FROM SPARES_INVENTORY_TURN_RATIO_FACT
    WHERE [DATE] >= @StartOfCurrentMonth AND [DATE] <= @Today;
    INSERT INTO SPARES_INVENTORY_TURN_RATIO_FACT
    (
        [DATE],
        [BU],
        [NUM],
        [DENO],
        [CREATE_DATE]
    )
    SELECT 
        CAST(IN_DATE AS DATE) AS DATE, 
        BU, 
        SUM(COGS) AS NUM, 
        SUM(AVG_STOCK_VAL) AS DENO,
        @Today AS CREATE_DATE
    FROM #CAL_CTE
    WHERE IN_DATE >= @StartOfCurrentMonth AND IN_DATE <= @Today
    GROUP BY IN_DATE, BU;

	Delete FROM SPARES_INVENTORY_TURN_RATIO_FACT
    WHERE [DATE] < @StartOfSixMonthsAgo

	Drop Table #CAL_CTE
END
	PRINT('Inventory Turnover Ratio data has been loaded successfully')

END
GO


