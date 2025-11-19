SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_Full_Load_ASM_MC_MARKET_SHARE_FACT_REFRESH] AS
BEGIN

-- ASM_MC_MARKET_SHARE_FACT :
TRUNCATE TABLE ASM_MC_MARKET_SHARE_FACT

INSERT INTO ASM_MC_MARKET_SHARE_FACT
SELECT 
--Distinct 
Case 
		When MONTH1=1 Then 'Jan'
		When MONTH1=2 Then 'Feb'
	    When MONTH1=3 Then 'Mar'
		When MONTH1=4 Then 'Apr'
		When MONTH1=5 Then 'May'
		When MONTH1=6 Then 'Jun'
		When MONTH1=7 Then 'Jul'
		When MONTH1=8 Then 'Aug'
		When MONTH1=9 Then 'Sep'
		When MONTH1=10 Then 'Oct'
		When MONTH1=11 Then 'Nov'
		When MONTH1=12 Then 'Dec'
	End+''+CAST(GJAHR as char(4)) AS PERIODNAME,
CAST(convert(datetime, replace(Case 
		When MONTH1=1 Then 'Jan'
		When MONTH1=2 Then 'Feb'
	    When MONTH1=3 Then 'Mar'
		When MONTH1=4 Then 'Apr'
		When MONTH1=5 Then 'May'
		When MONTH1=6 Then 'Jun'
		When MONTH1=7 Then 'Jul'
		When MONTH1=8 Then 'Aug'
		When MONTH1=9 Then 'Sep'
		When MONTH1=10 Then 'Oct'
		When MONTH1=11 Then 'Nov'
		When MONTH1=12 Then 'Dec'
	End+''+CAST(GJAHR as char(4)), '-', ' ')) as date) As DATE,
A.COMP AS MANUFACTURERNAME,
LTRIM(RTRIM(LEFT(A.SEGMENT,2))) AS SEGMENT,
A.BRAND,
A.BRAND AS MODEL_CODE,
CAST('' AS VARCHAR(100) ) AS CATEGORY,
CAST('' AS VARCHAR(100) ) AS SUB_CATEGORY,
A.TOTAL AS VOLUME,
GETDATE() AS LASTUPDATEDTIMESTAMP,
A.[STATE] AS STATE,
A.[CTYNAME] AS CITY
--INTO ASM_MC_MARKET_SHARE_FACT
FROM 
SAP_ZMS_BRAND_DATA A INNER JOIN SAP_ZSHARE_MASTER B ON A.BRAND = B.BRAND
WHERE 
CAST(CAST(convert(datetime, replace(Case 
		When MONTH1=1 Then 'Jan'
		When MONTH1=2 Then 'Feb'
	    When MONTH1=3 Then 'Mar'
		When MONTH1=4 Then 'Apr'
		When MONTH1=5 Then 'May'
		When MONTH1=6 Then 'Jun'
		When MONTH1=7 Then 'Jul'
		When MONTH1=8 Then 'Aug'
		When MONTH1=9 Then 'Sep'
		When MONTH1=10 Then 'Oct'
		When MONTH1=11 Then 'Nov'
		When MONTH1=12 Then 'Dec'
	End+' '+CAST(GJAHR as char(4)), '-', ' ')) as date) AS DATE) >='2020-04-01'  -- (46819 records affected)
	--AND LTRIM(RTRIM(LEFT(A.SEGMENT,2))) NOT IN ('SC','ZM','MO')
END
GO