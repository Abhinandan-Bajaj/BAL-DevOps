SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_SPARES_ICMC_RETAIL_BASE_INCLOAD]
AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			                            */
/*--------------------------------------------------------------------------------------------------*/
/*	2025-01-03 	|	 	Aswani	  |        Initiation of the SP                                     */
/*	2025-06-30	|		Aswani	  |		   Updated the BU column from company_master to             */ 
/*										   SAP_CUSTOMER_MASTER_KNA1									*/  
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

PRINT('LOADING DATA FROM Source TABLE');

---------------------------------------------------*RETAILER BASE DATA LOAD*---------------------------------------------------
WITH RETAILER_MASTER AS (
SELECT C.CODE as SOLD_TO_DEALER_DISTRIBUTOR, 
C.NAME AS DISTRIBUTOR_NAME,
CAST(A.FROMDATE AS DATE) as DATE_OF_ADDITION, 
A.TODATE as EXIT_DATE, 
B.CODE as RETAILER_CODE,
CASE WHEN B.GSTNumber IS NOT NULL AND TRIM(B.GSTNumber)<>''  THEN B.GSTNumber
     WHEN (B.GSTNumber IS NULL AND TRIM(B.GSTNumber)='') OR (B.PANCARDNO IS NOT NULL AND TRIM(B.PANCARDNO)<>'') THEN B.PANCARDNO
     WHEN (B.GSTNumber IS NULL AND TRIM(B.GSTNumber)='') AND (B.PANCARDNO IS NULL AND TRIM(B.PANCARDNO)='') OR (B.AADHARNO IS NOT NULL and TRIM(B.AADHARNO)<>'') THEN B.AADHARNO
     ELSE NULL END AS GOVT_ID
FROM CDMS_RETAILER_DATA A
LEFT JOIN  CONTACT_MASTER B ON A.CONTACTID = B.CONTACTID AND A.CONTACTIDENTIFIER = B.CONTACTIDENTIFIER
LEFT JOIN COMPANY_MASTER C on A.GCOMPANYID = C.COMPANYID
WHERE UPPER(A.CONTACTIDENTIFIER) IN ('RETAILER','CUSTOMER') AND UPPER(B.CONTACTIDENTIFIER) IN ('RETAILER','CUSTOMER')
AND A.TODATE IS NULL
),

RMTEST AS (
SELECT SOLD_TO_DEALER_DISTRIBUTOR, CONCAT_DLDB_GOVT_ID,DISTRIBUTOR_NAME,KYC_REGISTERED
FROM (
SELECT SOLD_TO_DEALER_DISTRIBUTOR,
       RETAILER_CODE,
       CONCAT(SOLD_TO_DEALER_DISTRIBUTOR,'_',GOVT_ID) AS CONCAT_DLDB_GOVT_ID,
       DISTRIBUTOR_NAME,
       CASE WHEN GOVT_ID IS NULL THEN '1' ELSE '0' END AS KYC_REGISTERED
       FROM RETAILER_MASTER M
  ) L
),

RETAILER_BASE  AS (
select SOLD_TO_DEALER_DISTRIBUTOR,DISTRIBUTOR_NAME,COUNT(DISTINCT CONCAT_DLDB_GOVT_ID) AS RETAILER_BASE,FIRST_OF_QUARTER FROM (
SELECT A.SOLD_TO_DEALER_DISTRIBUTOR,
CONCAT_DLDB_GOVT_ID,
UPPER(DISTRIBUTOR_NAME) AS DISTRIBUTOR_NAME,
CASE WHEN MONTH(GETDATE()) BETWEEN 1 AND 3 THEN CONCAT(YEAR(GETDATE()), '-01-01')
			WHEN MONTH(GETDATE()) BETWEEN 4 AND 6 THEN CONCAT(YEAR(GETDATE()), '-04-01')
			WHEN MONTH(GETDATE()) BETWEEN 7 AND 9 THEN CONCAT(YEAR(GETDATE()), '-07-01')
			WHEN MONTH(GETDATE()) BETWEEN 10 AND 12 THEN CONCAT(YEAR(GETDATE()), '-10-01')
    END AS FIRST_OF_QUARTER
FROM RMTEST A
LEFT JOIN SAP_CUSTOMER_MASTER_KNA1 CM ON A.SOLD_TO_DEALER_DISTRIBUTOR = CM.KUNNR
WHERE CM.KATR6 IN ('2WH','3WH') and KYC_REGISTERED=0
)P
GROUP BY SOLD_TO_DEALER_DISTRIBUTOR,DISTRIBUTOR_NAME,FIRST_OF_QUARTER
)

INSERT INTO [QUARTERLY_RETAILER_BASE_ICMC]
(
[CODE],
[DISTRIBUTOR NAME],
[DATE],
[BASE],
[CREATE_DATE]
)

SELECT
SUBSTRING(SOLD_TO_DEALER_DISTRIBUTOR, PATINDEX('%[^0 ]%', SOLD_TO_DEALER_DISTRIBUTOR + ' '),LEN(SOLD_TO_DEALER_DISTRIBUTOR)) as CODE,
DISTRIBUTOR_NAME,
FIRST_OF_QUARTER,
RETAILER_BASE,
CAST(getdate() AS DATE) AS CREATE_DATE
FROM RETAILER_BASE;

PRINT('The Quarterly Retailer Base data is loaded for Retailer screen successfully')

END
GO