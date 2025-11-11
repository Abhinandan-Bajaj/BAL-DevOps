SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_PB_SERVICE_COUNTERSALE_INCLOAD] AS 
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*  2025-08-26  | Rashi Pradhan             | Commented delete statement to fix D-2 issue           */
/*  2025-06-25   |   Rashi Pradhan           | added partion on lineid in dedup statement and Filter updated for PBCS,PCSC,PSI,PSR,PCSI - series */
/*	2024-10-07 	|	Sarvesh Kulkarni		| Issue fixed in the counter sale incremental load script */
/*	2024-07-15 	|	Sarvesh Kulkarni		| Removed filter for KTM to get all the data related to PB BU */
/*	2024-06-24 	|	Sarvesh Kulkarni		| Filter added for PBCS,PCSC,PBSCS,PSI - series considered for overall counter sale amount */
/*	2024-06-17 	|	Sarvesh Kulkarni		| First deployment for Counter Sale INCREMENTAL SP				*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

Begin
DECLARE @MAXDATESTG DATETIME2(7)= (SELECT Dateadd(Day,-1,MAX(IMPORTEDDATE)) FROM ASM_PB_COUNTER_SALES_STG)

Insert into ASM_PB_COUNTER_SALES_STG
select 
DISTINCT
SSD.CDMSUNIQUEID as FK_Docid  --cdms unique id
,CDMSLINEID as lineid
,ssd.docdate
,cast (ssd.docname as varchar) as docname 
,cast (CUSTOMERGROUP as varchar) as Type
,CM.COMPANYID as FK_Companyid
,BM.BRANCHID as FK_Branchid
,cast (ssd.COMPANYCODE as varchar) as COMPANYCODE 
,cast (ssd.BRANCHCODE as varchar) as BRANCHCODE
,null as fk_itemid
,Qty
,Rate
,Tradediscount
,Totaltax
,Totalamount
,AMOUNT as Pretaxrevenue
,Totalamount as Posttaxrevenue
,105  as Service_Retail_TypeIdentifier
,ssd.Importeddate
,getdate() as Refresh_Date
,SSD.ITEMCODE
FROM SPARE_SALE_DATA_NEW SSD
INNER JOIN COMPANY_MASTER CM ON (CM.CODE=SSD.COMPANYCODE AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (2) )
INNER JOIN BRANCH_MASTER BM ON SSD.BRANCHCODE=BM.CODE
--LEFT JOIN ITEM_MASTER IM ON IM.CODE=SSD.ITEMCODE
where ssd.Importeddate  > @MAXDATESTG
and(ssd.docname like 'PBCS%' OR ssd.docname like 'PCSC%'  OR ssd.docname like 'PSI%' OR ssd.docname like 'PSR%' OR ssd.docname like 'PCSI%');


PRINT('DELETING DATA FOR DOCDATE GREATER THAN today')

Delete from ASM_PB_COUNTER_SALES_STG Where CAST(DOCDATE AS DATE) > Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate()))) as date);
---------------------------------------DEDUPE

;WITH CTE AS                  
(                  
  SELECT *,                  
  ROW_NUMBER() OVER(PARTITION BY FK_DOCID, lineid ORDER BY IMPORTEDDATE,refresh_date DESC)RNK                  
  FROM ASM_PB_COUNTER_SALES_STG              
)          
DELETE FROM CTE                  
WHERE RNK<>1;


PRINT('Deleting counter sale data from ASM_PB_SERVICE_FACT')
DELETE FROM ASM_PB_SERVICE_FACT WHERE SERVICE_RETAIL_TYPEIDENTIFIER=105
PRINT('Deleted counter sale data from ASM_PB_SERVICE_FACT')

Insert into ASM_PB_SERVICE_FACT(
FK_Docid
,lineid
,docdate
,docname 
,Type
,FK_Companyid
,FK_Branchid
,dealercode
,fk_itemid
,Qty
,Rate
,Tradediscount
,Totaltax
,Totalamount
,Pretaxrevenue
,Posttaxrevenue
,Service_Retail_TypeIdentifier
,Importeddate
,Refresh_Date
,Billeddatetime
,ITEMCODE
)
 
select 
FK_Docid
,lineid
,docdate
,docname 
,Type
,FK_Companyid
,FK_Branchid
,COMPANYCODE as dealercode
,fk_itemid
,Qty
,Rate
,Tradediscount
,Totaltax
,Totalamount
,Pretaxrevenue
,Posttaxrevenue
,Service_Retail_TypeIdentifier
,Importeddate
,getdate() as Refresh_Date
,docdate as Billeddatetime
,ITEMCODE
FROM ASM_PB_COUNTER_SALES_STG

END 


GO