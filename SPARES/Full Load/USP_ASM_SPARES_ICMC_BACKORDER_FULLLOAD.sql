SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_SPARES_ICMC_BACKORDER_FULLLOAD]
AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			                            */
/*--------------------------------------------------------------------------------------------------*/
/*	2025-01-03 	|	 	Aswani	  |        Initiation of the SP                                     */ 
/*  2025-02-24  |       Aswani    |        Included the partially cancelled orders logic            */
/*  2025-03-19  |       Aswani    |        Included the distinct at item level and take BO sum      */
/*	2025-04-09	|		Aswani	  |		   Updated the code to include delivery criteria columns 	*/
/*	2025-04-22	|		Aswani	  |		   Updated the whole code with the existing SPD_VBBE table	*/
/*										   for BackOrder											*/
/*	2025-06-30	|		Aswani	  |		   Updated the BU column from company_master to             */ 
/*										   SAP_CUSTOMER_MASTER_KNA1									*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

PRINT('LOADING DATA FROM Source TABLE')
TRUNCATE TABLE [dbo].[ASM_ICMC_SPARES_BACKORDER_DAILY_FACT];

-----------------------------------------------------------------------------------------------------------------------------------

DECLARE @CurrentDate DATE = GETDATE();
DECLARE @StartDate DATE = DATEADD(MONTH, -12, @CurrentDate); 


WITH VBBE AS 
(
SELECT 
REFRESH_DATE, 
AUART, 
KUNNR, 
MATNR, 
SUM(OMENG) OMENG, 
SUM(VMENG) VMENG, 
POSNR,
VBELN,
WERKS, 
VBTYP
FROM SPD_VBBE 
WHERE WERKS IN ('WA02', 'PT02')
GROUP BY REFRESH_DATE , AUART , KUNNR , MATNR ,  POSNR , VBELN , WERKS , VBTYP
)
SELECT * INTO #VBBE_SUMMARIZED
FROM VBBE;


--===============================================================================================================
WITH VBAP_VBAK_TMP AS 
(
SELECT 
VBAP.MATNR   AS   VBAP_MATNR, 
VBAP.VBELN   AS   VBAP_VBELN, 
VBAP.POSNR   AS   VBAP_POSNR, 
VBAP.ERDAT   AS   VBAP_ERDAT, 
VBAK.VKORG   AS   VBAK_VKORG, 
VBAP.LGORT   AS   VBAP_LGORT,
VBAK.KUNNR   AS   VBAK_KUNNR, 
VBAP.KWMENG  AS   VBAP_KWMENG,
VBAP.KZWI1   AS   VBAP_KZWI1,
VBAP.ARKTX   AS   VBAP_ARKTX
FROM SAP_VBAP_TMP VBAP 
LEFT JOIN  SAP_VBAK_TMP VBAK 
ON VBAP.VBELN = VBAK.VBELN
WHERE VBAP.SPART = 'B1'
AND VBAP.KWMENG > 0
AND VBAP.NETWR <> 0
AND VBAP.KZWI1 <> 0 
AND VBAP.WERKS IN ('WA02','PT02') 
AND VBAK.VKORG IN ('ZDOM') 
AND VBAP.ABGRU IN ('',' ','A1')
AND VBAK.AUART IN ('ZSTD', 'ZSCH', 'ZVOR', 'ZPSD', 'ZPSH', 'ZPVR', 'ZSPD')
), 

OUTBOUND_TMP AS (
SELECT  
VBAP_MATNR,
VBAP_VBELN,
VBAP_POSNR, 
VBAP_ERDAT, 
VBAK_VKORG, 
VBAK_KUNNR, 
VBAP_LGORT,
VBAP_KWMENG, 
VBAP_KZWI1, 
VBAP_ARKTX
FROM SPD_FINAL_OUTBOUND_TBL
WHERE  VBAP_ERDAT  
BETWEEN @StartDate AND @CurrentDate
AND ORDER_CANCELLATION = 'A'
AND VBAP_WERKS IN ('WA02','PT02') 
AND VBAK_AUART IN ('ZSTD', 'ZSCH', 'ZVOR', 'ZPSD', 'ZPSH', 'ZPVR', 'ZSPD')
AND VBAK_VKORG IN ('ZDOM') 


UNION 

SELECT   
VBAP_MATNR, 
VBAP_VBELN, 
VBAP_POSNR, 
VBAP_ERDAT, 
VBAK_VKORG,
VBAK_KUNNR, 
VBAP_LGORT,
VBAP_KWMENG, 
VBAP_KZWI1, 
VBAP_ARKTX
FROM VBAP_VBAK_TMP
)

SELECT 
	VBAP_MATNR,
	VBAP_VBELN,
	VBAP_POSNR,
	VBAP_ERDAT,
	VBAK_VKORG,
	VBAK_KUNNR,
	VBAP_LGORT,
	VBAP_KWMENG,
	VBAP_KZWI1, 
	VBAP_ARKTX
INTO  #MB_ORDER 
FROM OUTBOUND_TMP;

-------------------------------------------------BO CALCULATION FOR PRIMARY-----------------------------------------------------

WITH CTE_CAL AS (
SELECT CALENDAR_DATE, SOLD_TO_DEALER_OR_DISTRIBUTOR, BU, SUM(BACKORDER_AMOUNT) AS BACKORDER_AMOUNT FROM (
SELECT CALENDAR_DATE, SOLD_TO_DEALER_OR_DISTRIBUTOR, ORDER_MATERIAL, ORDER_NO, BO_QTY, ORDER_ITEM, 
ORDER_TYPE, (PER_ORDER_AMOUNT*BO_QTY) AS BACKORDER_AMOUNT, BU FROM (
SELECT REFRESH_DATE AS CALENDAR_DATE, A.KUNNR AS SOLD_TO_DEALER_OR_DISTRIBUTOR ,MATNR AS ORDER_MATERIAL , VBELN AS ORDER_NO, OMENG AS BO_QTY, 
POSNR AS ORDER_ITEM, AUART AS ORDER_TYPE, 
CASE WHEN CAST(OMENG AS FLOAT)=0 THEN 0 ELSE (B.VBAP_KZWI1/B.VBAP_KWMENG) END AS PER_ORDER_AMOUNT,
CASE WHEN CM.KATR6='2WH' THEN '2W'
     WHEN CM.KATR6='3WH' THEN '3W'
     ELSE NULL END AS BU
FROM #VBBE_SUMMARIZED A
JOIN #MB_ORDER B ON A.VBELN = B.VBAP_VBELN AND A.MATNR = B.VBAP_MATNR AND A.POSNR = B.VBAP_POSNR AND A.KUNNR = B.VBAK_KUNNR
LEFT JOIN SAP_CUSTOMER_MASTER_KNA1 CM ON A.KUNNR=CM.KUNNR
WHERE VBAK_VKORG = 'ZDOM' AND CAST(OMENG AS FLOAT) >0 AND A.KUNNR NOT LIKE '%C' AND CM.KATR6 IN ('2WH','3WH')
AND AUART IN ('ZSTD','ZSCH','ZVOR','ZPSD','ZPSH','ZPVR','ZSPD') 
)A
)B GROUP BY CALENDAR_DATE, SOLD_TO_DEALER_OR_DISTRIBUTOR, BU
)

INSERT INTO [DBO].[ASM_ICMC_SPARES_BACKORDER_DAILY_FACT]
(
CALENDAR_DATE,
SOLD_TO_DEALER_OR_DISTRIBUTOR,
BU,
BACKORDER_AMOUNT,
CREATE_DATE
)

SELECT
CALENDAR_DATE,
SOLD_TO_DEALER_OR_DISTRIBUTOR,
BU,
BACKORDER_AMOUNT,
CAST(GETDATE() AS DATE) AS CREATE_DATE
FROM CTE_CAL;

---------------------------------------------BO AS ON 1ST OF EVERY MONTH_HISTORICAL---------------------------------------------

TRUNCATE TABLE [dbo].[ASM_ICMC_SPARES_BACKORDER_MONTHLY_FACT];

WITH CTE_CAL AS (
SELECT 
CALENDAR_DATE,
SOLD_TO_DEALER_OR_DISTRIBUTOR,
BU,
BACKORDER_AMOUNT
FROM ASM_ICMC_SPARES_BACKORDER_DAILY_FACT
WHERE DAY(CALENDAR_DATE) =1 
)

INSERT INTO [DBO].[ASM_ICMC_SPARES_BACKORDER_MONTHLY_FACT]
(             [CALENDAR_DATE],
			  [SOLD_TO_DEALER_OR_DISTRIBUTOR],
              [BU],
              [BACKORDER_AMOUNT],
              [CREATE_DATE]
)
SELECT 
CALENDAR_DATE,
SOLD_TO_DEALER_OR_DISTRIBUTOR,
BU,
BACKORDER_AMOUNT,
CAST(getdate() AS DATE) AS CREATE_DATE
FROM CTE_CAL;

------------------------------------------------------------DROPPING THE TEMP TABLES----------------------------------------------

DROP TABLE #MB_ORDER
DROP TABLE #VBBE_SUMMARIZED


PRINT('Backorder historical data loaded successfully')

END
GO
