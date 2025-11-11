
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_SPARES_ICMC_RETAIL_SALES_INCLOAD]
AS
BEGIN
/*******************************************INC LOAD**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			                            */
/*--------------------------------------------------------------------------------------------------*/
/*	2025-01-03 	|	 	Aswani	  |        Initiation of the SP                       */
/*	2025-06-30	|		Aswani	  |		   Updated the BU column from company_master to             */ 
/*										   SAP_CUSTOMER_MASTER_KNA1									*/   
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************INC LOAD**************************************************/


PRINT('LOADING DATA FROM Source TABLE');

---------------------------------------------------*RETAIL_SCREEN_DATA_LOAD*---------------------------------------------------
DECLARE @MAXDATESTG DATETIME2(7)= (SELECT Dateadd(Day,-1,MAX(IMPORTEDDATE)) FROM ASM_ICMC_SPARES_RETSALES_STG);

WITH RETAIL_SALES AS (
SELECT 
LINE_ID,
COMPANYCODE,
BU,
SUM(Totalamount) AS RETAIL_SALES,
DOCDATE AS DOCDATE_SALES,
CONTACTCODE,
Importeddate
FROM (
select 
DISTINCT
CDMSLINEID as LINE_ID
,ssd.docdate
,ssd.CONTACTCODE
,cast (ssd.COMPANYCODE as varchar) as COMPANYCODE 
,Totalamount
,ssd.Importeddate
,getdate() as Refresh_Date,
CASE WHEN CM.KATR6='2WH' THEN '2W'
     WHEN CM.KATR6='3WH' THEN '3W'
     ELSE NULL END AS BU
FROM SPARE_SALE_DATA_NEW SSD
LEFT JOIN SAP_CUSTOMER_MASTER_KNA1 CM ON SSD.COMPANYCODE = CM.KUNNR
INNER JOIN ITEM_MASTER IM ON SSD.ITEMCODE=IM.CODE AND IM.COMPANYID is null
WHERE (SSD.DOCNAME like 'DPSI%' or SSD.DOCNAME like 'PCSC%' or SSD.DOCNAME like 'PCSI%' or SSD.DOCNAME like 'PSI%' or SSD.DOCNAME like 'PSR%' or SSD.DOCNAME like 'CVCS%')
AND CM.KATR6 IN ('2WH','3WH') and SSD.ITEMCODE<>'TR' AND SSD.ITEMNAME<>'FRIEGHT/COURIER CHARGES/ROUNDED OFF'
AND SSD.ITEMCODE NOT IN ('83010498','83010499','83010500','83010501','83010503','83010505','83010505A','83010505-ML','83010519','83020111','83020311','83020330','83020331','83020332','83020333',
'83020334','83020335','83020337','83020338','83020340','83020355','83020402','83020407','83020408','83020410','83020411','83020413','83020415','83020430','83020433','83020435','83020436','83020437',
'83020438','83020454','83020455','83020459','83020460','83020461','83020462','83020463','83020469','83020470','83020471','83020483','83020487','83020503','83020504','83020510','83020510','83020511',
'83020511','83020512','83020524','83020550','83020550','83020550','83020550','83020550','83020550','83020551','83020552','83020552','83020552','83020552','83020552','83020552(1)','83020552','83020552',
'83020552','83020552','83020553','83020554','83020554','83020555','83020556','83020557','83020558','83020559','83020562','83020564','83020565','83020566','83020566A','83020567','83020567','83020569',
'83020570','83020570-1','83020571','83020572','83020574','83020576','83020577','83020578','83020580-1','83020586','83020587','83020588','83020591','83020592','83020598','83020598-1','83020599','83020601',
'83020602','83020624','83020626','83020627','83020630','83020653','83020653','83020654','83020672','83020673','83020673','83020673','83020808')
--AND DOCDATE BETWEEN '2024-05-01' AND '2024-05-31'
and COMPANYCODE >= '0000015000' AND COMPANYCODE <='0000018000'
and ssd.Importeddate  > @MAXDATESTG
)A GROUP BY COMPANYCODE, LINE_ID,BU,CONTACTCODE, DOCDATE,Importeddate
)

INSERT INTO ASM_ICMC_SPARES_RETSALES_STG
(
[LINE_ID],
[COMPANYCODE],
[DOCDATE_SALES],
[CONTACT_CODE],
[BU],
[RETAIL_SALES],
[IMPORTEDDATE],
[CREATE_DATE]
)

SELECT 
LINE_ID,
COMPANYCODE,
DOCDATE_SALES,
CONTACTCODE,
BU,
RETAIL_SALES,
IMPORTEDDATE,
CAST(GETDATE() AS DATE) AS CREATE_DATE
FROM RETAIL_SALES
WHERE BU IN ('2W','3W') ;

-------------------------------------------------DEDUP
WITH CTE AS                  
(                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY LINE_ID ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_ICMC_SPARES_RETSALES_STG              
)          
DELETE FROM CTE                  
WHERE RNK<>1;


PRINT('Retail sales data is loaded for Retailer screen successfully')

END
GO