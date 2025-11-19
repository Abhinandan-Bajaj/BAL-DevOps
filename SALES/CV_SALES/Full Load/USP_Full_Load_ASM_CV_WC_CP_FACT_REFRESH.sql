SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_Full_Load_ASM_CV_WC_CP_FACT_REFRESH] AS
BEGIN

TRUNCATE TABLE dbo.ASM_CV_WORKING_CAP_FACT;
INSERT INTO dbo.ASM_CV_WORKING_CAP_FACT
(
[FK_dealercode],
[DEALERCODE],
[DEALERNAME],
[YEAR],
[MONTH],
[RECORDDATE],
[IMPORTEDDATE],
[FK_TYPE_ID],
[VehicleStockValue_lacs],
[BALCreditSales_lacs],
[TotalBorrowed_lacs],
[TotalOwnFund_lacs],
[OwnFund%],
[BGExpiryDate_Status1],
[BGExpiryDate_Status2],
[BGExpiryDate_Status3],
[BGExpiryDate_Status4],
[BGExpiryDate_Status5],
[BGExpiryDate_Status6],
[BGExpiryDate_Status7],
[BAL Credit/ BG Ratio],
[CREATEDDATETIME]
 )
 SELECT 
Cast(0 as int) AS FK_DEALERCODE,
[DEALERCODE],
[DEALERNAME],
CAST(YEAR AS VARCHAR) AS YEAR,
CAST(MONTH AS VARCHAR) AS MONTH,
convert(date, RECORDDATE, 105) AS RECORDDATE,
[IMPORTEDDATE],
10008 AS FK_TYPE_ID,
[VEHICLESTOCKVALUE_LACS],
[BALCREDITSALES_LACS],
[TOTALBORROWED_LACS],
[TOTALOWNFUND_LACS],
[OwnFund%],

CASE WHEN BGExpiryDate1 < CAST(GETDATE()-1 AS DATE) AND BGExpiryDate1 IS NOT NULL THEN 
  (CASE WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate1) <1 THEN '<1 month'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate1) >= 1 AND DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate1) <2  THEN '1-2 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate1) BETWEEN 2 AND 3  THEN '2-3 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate1) >3 THEN '>3 months'
  END)
  WHEN BGExpiryDate1 >= CAST(GETDATE()-1 AS DATE) then
  'Not Expired'
 END AS BGExpiryDate_Status1,

CASE WHEN BGExpiryDate2 < CAST(GETDATE()-1 AS DATE) AND BGExpiryDate2 IS NOT NULL THEN 
  (CASE WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate2) <1 THEN '<1 month'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate2) >= 1 AND DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate2) <2  THEN '1-2 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate2) BETWEEN 2 AND 3  THEN '2-3 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate2) >3 THEN '>3 months'
  END)
  WHEN BGExpiryDate2 >= CAST(GETDATE()-1 AS DATE) then
  'Not Expired'
 END AS BGExpiryDate_Status2,

CASE WHEN BGExpiryDate3 < CAST(GETDATE()-1 AS DATE) AND BGExpiryDate3 IS NOT NULL THEN 
  (CASE WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate3) <1 THEN '<1 month'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate3) >= 1 AND DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate3) <2  THEN '1-2 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate3) BETWEEN 2 AND 3  THEN '2-3 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate3) >3 THEN '>3 months'
  END)
  WHEN BGExpiryDate3 >= CAST(GETDATE()-1 AS DATE) then
  'Not Expired'
 END AS BGExpiryDate_Status3,

CASE WHEN BGExpiryDate4 < CAST(GETDATE()-1 AS DATE) AND BGExpiryDate4 IS NOT NULL THEN 
  (CASE WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate4) <1 THEN '<1 month'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate4) >= 1 AND DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate4) <2  THEN '1-2 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate4) BETWEEN 2 AND 3  THEN '2-3 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate4) >3 THEN '>3 months'
  END)
  WHEN BGExpiryDate4 >= CAST(GETDATE()-1 AS DATE) then
  'Not Expired'
 END AS BGExpiryDate_Status4,

CASE WHEN BGExpiryDate5 < CAST(GETDATE()-1 AS DATE) AND BGExpiryDate5 IS NOT NULL THEN 
  (CASE WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate5) <1 THEN '<1 month'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate5) >= 1 AND DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate5) <2  THEN '1-2 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate5) BETWEEN 2 AND 3  THEN '2-3 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate5) >3 THEN '>3 months'
  END)
  WHEN BGExpiryDate5 >= CAST(GETDATE()-1 AS DATE) then
  'Not Expired'
 END AS BGExpiryDate_Status5,

CASE WHEN BGExpiryDate6 < CAST(GETDATE()-1 AS DATE) AND BGExpiryDate6 IS NOT NULL THEN 
  (CASE WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate6) <1 THEN '<1 month'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate6) >= 1 AND DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate6) <2  THEN '1-2 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate6) BETWEEN 2 AND 3  THEN '2-3 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate6) >3 THEN '>3 months'
  END)
  WHEN BGExpiryDate6 >= CAST(GETDATE()-1 AS DATE) then
  'Not Expired'
 END AS BGExpiryDate_Status6,

CASE WHEN BGExpiryDate7 < CAST(GETDATE()-1 AS DATE) AND BGExpiryDate7 IS NOT NULL THEN 
  (CASE WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate7) <1 THEN '<1 month'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate7) >= 1 AND DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate7) <2  THEN '1-2 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate7) BETWEEN 2 AND 3  THEN '2-3 months'
  WHEN DATEDIFF(MONTH, EOMONTH(convert(date, RECORDDATE, 105)), BGExpiryDate7) >3 THEN '>3 months'
  END)
  WHEN BGExpiryDate7 >= CAST(GETDATE()-1 AS DATE) then
  'Not Expired'
 END AS BGExpiryDate_Status7,

COALESCE(BALCreditSales_lacs / NULLIF(BGAmount1_lacs + BGAmount2_lacs + BGAmount3_lacs + BGAmount4_lacs + BGAmount5_lacs + BGAmount6_lacs + BGAmount7_lacs,0), 0) AS [BAL Credit/ BG Ratio],
GETDATE() AS CREATEDDATETIME
 FROM
 dbo.INVENTORY_FUNDING INV_FUND INNER JOIN (SELECT CODE,COMPANYTYPE FROM COMPANY_MASTER) CM ON (CM.CODE = INV_FUND.Dealercode 
and CM.COMPANYTYPE=7)
WHERE
 convert(date, RECORDDATE, 105)  BETWEEN '2020-04-01' AND  Cast(Getdate()-1 as date)
 --convert(date, RECORDDATE, 105) > ( SELECT CASE WHEN (SELECT COUNT(*) FROM ASM_CV_WORKING_CAP_FACT)=0 THEN 
--'2020-04-01' ELSE MAX(IMPORTEDDATE) END FROM ASM_CV_WORKING_CAP_FACT)

Delete from ASM_CV_WORKING_CAP_FACT Where CAST(IMPORTEDDATE AS DATE) > Cast(Getdate()-1 as date);

WITH CTE AS                  
 (                  
  SELECT *,                  
    ROW_NUMBER()OVER(PARTITION BY DEALERCODE,DEALERNAME,YEAR, MONTH, RECORDDATE ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_CV_WORKING_CAP_FACT                 
 )     
             
DELETE FROM CTE                  
 WHERE RNK<>1;  

update B set B.FK_DEALERCODE=C.PK_DEALERCODE from  [dbo].ASM_CV_WORKING_CAP_FACT  B INNER JOIN ASM_CV_DEALER_MASTER_DIM C on (B.DEALERCODE =C.DEALERCODE) WHERE B.FK_DEALERCODE=0

--*******************************************************

END
GO