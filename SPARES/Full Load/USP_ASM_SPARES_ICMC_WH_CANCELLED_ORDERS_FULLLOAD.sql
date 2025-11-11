SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_SPARES_ICMC_WH_CANCELLED_ORDERS_FULLLOAD]
AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			                            */
/*--------------------------------------------------------------------------------------------------*/
/*	2025-03-24 	|	 	Aswani	  |        Initiation of the SP for warehouse                       */
/*	2025-06-30	|		Aswani	  |		   Updated the BU column from company_master to             */ 
/*										   SAP_CUSTOMER_MASTER_KNA1									*/  
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

PRINT('LOADING DATA FROM Source TABLE')
TRUNCATE TABLE [dbo].[ASM_ICMC_SPARES_WH_CANCELLED_ORDERS_FACT];

--------------------------------------------------*GETTING DATES*--------------------------------------------------------------
DECLARE @CurrentDate DATE = CAST(GETDATE() AS DATE);
DECLARE @StartDate DATE = CAST(DATEADD(MONTH, -1, @CurrentDate) AS DATE); 

-------------------------------------------------------**CANCELLED_ORDERS**-------------------------------------------------------

WITH CANCELLED_ORDERS AS (
SELECT CALENDAR_DATE, ORDER_MATERIAL, ORDER_NO,
SUM(GROSS_ORDER_AMOUNT) AS CANCELLED_ORDER_AMOUNT,BU,CHANNEL,ORDER_TYPE FROM (
SELECT distinct
CC.CALENDAR_DATE,
A.ORDER_MATERIAL,A.ORDER_NO,A.ITEM,
A.GROSS_ORDER_AMOUNT,A.ORDER_TYPE,
CASE WHEN CM.KATR6='2WH' THEN 'MC'
	WHEN CM.KATR6='3WH' THEN 'IC'
ELSE NULL END AS BU,
CASE WHEN DISTRIBUTION_CHANNEL=10 THEN 'Dealer'
	WHEN DISTRIBUTION_CHANNEL=20 THEN 'Distributor'
END AS CHANNEL
FROM ASM_CV_CALENDAR_DIM CC
JOIN VW_SPARES_ICMC_ODI_DATA A ON A.ORDER_DATE >= DATEADD(day, -90, CC.CALENDAR_DATE)  AND A.ORDER_DATE <= CC.CALENDAR_DATE
LEFT JOIN SAP_CUSTOMER_MASTER_KNA1 CM ON A.SOLD_TO_DEALER_OR_DISTRIBUTOR=CM.KUNNR
WHERE SALES_ORGANIZATION='ZDOM' AND ORDER_DIVISION='B1'  AND DISTRIBUTION_CHANNEL IN (10,20) 
AND ORDER_TYPE IN ('ZSTD','ZSCH','ZVOR','ZPSD','ZPSH','ZPVR','ZSPD') 
AND ORDER_REJECTION_REASON NOT IN ('','A1')
AND cc.CALENDAR_DATE >= @StartDate AND cc.CALENDAR_DATE < @CurrentDate
AND CM.KATR6 IN ('2WH','3WH')
)A
GROUP BY CALENDAR_DATE,ORDER_MATERIAL,BU,ORDER_TYPE,CHANNEL,ORDER_NO
)

INSERT INTO ASM_ICMC_SPARES_WH_CANCELLED_ORDERS_FACT
(
CANCELLED_ORDERS_90DAYS,
CANCELLED_ORDER_VALUE_90DAYS,
BU,
CHANNEL,
ORDER_TYPE,
CALENDAR_DATE
)

SELECT
ORDER_MATERIAL,
CANCELLED_ORDER_AMOUNT,
BU,
CHANNEL,
ORDER_TYPE,
CALENDAR_DATE
FROM CANCELLED_ORDERS;

PRINT('Cancelled orders data has been loaded successfully')

END
GO