SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_SPARES_ICMC_VOR]
AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			                            */
/*--------------------------------------------------------------------------------------------------*/
/*	2025-03-13 	|	 	Aswani	  |        Initiation of the SP. Loading SCH and ROL parts data     */
/*	2025-04-22	|		Aswani	  |		   Update in the source structure, updated the query 		*/
/*										   accordingly to accomodate the changes					*/
/*	2025-06-30	|		Aswani	  |		   Updated the BU column from company_master to             */ 
/*										   SAP_CUSTOMER_MASTER_KNA1									*/ 
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

PRINT('LOADING DATA FROM Source TABLE')
TRUNCATE TABLE [dbo].[ASM_ICMC_SPARES_VOR_FACT];

-------------------------------------------------------ORDERLINES_SERVED_48HRS_72HRS------------------------------------------------

WITH ORDERLINES_SERVED_48HRS_72HRS AS (
SELECT ORDER_NO,ORDER_MATERIAL,DIFF,ORDER_DATE,
CASE WHEN DIFF IN (0,1,2) THEN 1 ELSE 0 END AS ORDERLINES_SERVED_48HRS,
CASE WHEN DIFF IN (0,1,2,3) THEN 1 ELSE 0 END AS ORDERLINES_SERVED_72HRS
FROM (
SELECT DISTINCT
ORDER_NO,
ORDER_MATERIAL,
ORDER_DATE,
DATEDIFF(DAY, ORDER_DATE, BILLING_DATE) AS DIFF
FROM VW_SPARES_ICMC_ODI_DATA
WHERE BILLING_DATE IS NOT NULL
AND ORDER_REJECTION_REASON IN ('', 'A1')
AND BILLING_TYPE_ANALYTICS IN ('ZVOR')
)A
),

CTE_CAL AS (
SELECT ORDER_DATE,ORDERLINE,ORDERLINES_SERVED_48HRS,ORDERLINES_SERVED_72HRS,BU,CHANNEL FROM (
SELECT 
CONCAT(V.ORDER_NO,'-',V.ORDER_MATERIAL) AS ORDERLINE,
V.ORDER_DATE,
ORDERLINES_SERVED_48HRS,
ORDERLINES_SERVED_72HRS,
CASE
    WHEN CM.KATR6='2WH' THEN 'MC'
    WHEN CM.KATR6='3WH' THEN 'IC'
ELSE NULL END AS BU,
CASE WHEN DISTRIBUTION_CHANNEL = '10' THEN 'DEALER'
     WHEN DISTRIBUTION_CHANNEL = '20' THEN 'DISTRIBUTOR' 
END AS CHANNEL
FROM VW_SPARES_ICMC_ODI_DATA V
LEFT JOIN SAP_CUSTOMER_MASTER_KNA1 CM ON V.SOLD_TO_DEALER_OR_DISTRIBUTOR=CM.KUNNR
LEFT JOIN ORDERLINES_SERVED_48HRS_72HRS O ON V.ORDER_NO=O.ORDER_NO AND V.ORDER_MATERIAL=O.ORDER_MATERIAL AND V.ORDER_DATE=O.ORDER_DATE
WHERE V.ORDER_REJECTION_REASON IN ('', 'A1')
AND V.ORDER_TYPE IN ('ZVOR')
)A
)

INSERT INTO [ASM_ICMC_SPARES_VOR_FACT]
(
ORDER_DATE,
BU,
CHANNEL,
ORDERLINE,
ORDERLINES_SERVED_48HRS,
ORDERLINES_SERVED_72HRS
)

SELECT 
ORDER_DATE,
BU,
CHANNEL,
ORDERLINE,
ORDERLINES_SERVED_48HRS,
ORDERLINES_SERVED_72HRS
FROM CTE_CAL
WHERE BU IN ('IC','MC');


---------------------------------------------SPARE_URS_STP_STCK_VAL-----------------------

TRUNCATE TABLE SPARE_URS_STP_STCK_VAL;

WITH ATP_STOCK AS (
 SELECT 
        DATALOADDATE as Stock_Date,
        MATNR_Item_Code as Material, 
        SHPRO_Item_Segment as BU, 
        SUM(cast(LABST_Unrestricted_Stock as float)) as URS_QTY,
		SUM(cast(MNG04_ATP_Stock as float)) as ATP_QTY
    FROM SPD_ATP
	WHERE DATALOADDATE = (SELECT MAX(DATALOADDATE)FROM SPD_ATP)
	GROUP BY DATALOADDATE, MATNR_Item_Code, SHPRO_Item_Segment 
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

CTE_CAL AS (
SELECT Stock_Date,
Material, 
BU, 
URS_QTY, 
ATP_QTY, 
PO_RATE, 
URS_QTY * ISNULL(PO_RATE,0) as URS_VAL, 
ATP_QTY * ISNULL(PO_RATE,0) as ATP_VAL
FROM ATP_STOCK A
LEFT JOIN PO_RATE B
ON A.Material = B.MATERIAL_NUMBER
WHERE BU in ('2W','3W','COM','4W')
)


INSERT INTO SPARE_URS_STP_STCK_VAL
(
STOCK_DATE,
MATERIAL,
BU,
URS_QTY,
ATP_QTY,
PO_RATE,
URS_VAL,
ATP_VAL,
CREATE_DATE
)

SELECT 
STOCK_DATE,
MATERIAL,
BU,
URS_QTY,
ATP_QTY,
PO_RATE,
URS_VAL,
ATP_VAL,
CAST(GETDATE() AS DATE) AS CREATE_DATE
FROM CTE_CAL;

PRINT('Orderlines served in 48hrs and 72hrs and Unrestricted stock data has been loaded successfully')

END
GO