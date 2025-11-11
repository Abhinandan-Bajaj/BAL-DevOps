SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_PB_SERVICE_COUNTERSALE_FULLLOAD] AS 
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*  2025-06-25   |   Rashi Pradhan           | updated filter for PBCS,PCSC,PSI,PSR,PCSI -series considered for overall counter sale amount*/
/*	2024-10-04 	|	Sarvesh Kulkarni		| Bug fix in the incremetal & FULL load */
/*	2024-07-15 	|	Sarvesh Kulkarni		| Removed filter for KTM to get all the data related to PB BU */
/*	2024-06-24 	|	Sarvesh Kulkarni		| Filter added for PBCS,PCSC,PBSCS,PSI - series considered for overall counter sale amount */
/*	2024-06-17 	|	Sarvesh Kulkarni		| First deployment for Counter Sale SP*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

Begin
PRINT('Truncating table ASM_PB_COUNTER_SALES_STG')
TRUNCATE table ASM_PB_COUNTER_SALES_STG;
PRINT('Table ASM_PB_COUNTER_SALES_STG Truncated')

Insert into ASM_PB_COUNTER_SALES_STG
select 
distinct
SSD.CDMSUNIQUEID as FK_Docid
,CDMSLINEID as lineid
,cast (ssd.docdate as date) docdate
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
where ssd.docdate > '2018-04-01'
and(ssd.docname like 'PBCS%' OR ssd.docname like 'PCSC%'  OR ssd.docname like 'PSI%' OR ssd.docname like 'PSR%' OR ssd.docname like 'PCSI%');


PRINT('Truncating table ASM_PB_SERVICE_FACT')
DELETE FROM ASM_PB_SERVICE_FACT WHERE SERVICE_RETAIL_TYPEIDENTIFIER=105
PRINT('Table ASM_PB_SERVICE_FACT Truncated')

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