SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USP_ASM_PB_SERVICE_SPARES_REFRESH]  AS 
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/							
/*	28-01-2025  |  Richa M		|	Initial SP creation					*/				
/*	01-07-2025  |  Rashi P 		|	Added filter for KIT LEG Gaurd part from Plant CK02 */	
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

BEGIN


PRINT('LOADING DATA FROM BASE TABLE INTO ODI STAGING TABLE');

TRUNCATE TABLE [dbo].[ASM_PB_SPARES_ODI_STG];

INSERT INTO [dbo].[ASM_PB_SPARES_ODI_STG]
SELECT 
spd.ORDER_NO as order_id,	
spd.ORDER_MATERIAL as material_desc,	
spd.ITEM as item,	
spd.ORDER_SHORT_DESC as item_desc,	
spd.ORDER_QUANTITY AS order_quantity,
spd.ORDER_CONFIRMED_QUANTITY as order_item_quantity,	
spd.GROSS_ORDER_AMOUNT  as order_item_value,
spd.ORDER_AMOUNT as order_item_value_wth_tax,	  
spd.ORDER_STORAGE_LOACTION as storage_location,	
spd.ORDER_PLANT as order_plant,	
spd.ORDER_DATE as order_item_date,	
spd.SALES_ORGANIZATION as sales_org,	
spd.DISTRIBUTION_CHANNEL as DISTRIBUTION_CHANNEL,	
spd.SOLD_TO_DEALER_OR_DISTRIBUTOR as dealer_code,	
spd.ORDER_TYPE as sales_order_type,	
spd.ORDER_ITEM_CATEGORY as item_category,	
spd.ORDER_DIVISION AS order_division,
spd.ORDER_REJECTION_REASON as reason_for_rejection,	
spd.DELIVERY_QUANTITY as delivery_item_quantity,	
spd.ORDER_MATERIAL_GROUP as material_group,	
spd.DELIVERY_DATE as delivery_item_date,	
COALESCE(spd.DELIVERY_DATE,spd.ORDER_DATE) AS backorder_item_date,
spd.DELIVERY_SHIPPING_POINT as delivery_shipping_point,
spd.DELIVERY_TYPE as delivery_type,
spd.CUSTOMER_NUMBER as customer_number,
spd.SHIP_TO_PARTY as ship_to_party,
spd.RETURN_INDICATOR as return_indicator,
spd.GROSS_DELIVERY_AMOUNT as delivery_item_value,
spd.DELIVERY_AMOUNT as delivery_item_value_wth_tax,
spd.DELIVERY_STATUS as delivery_status,
spd.OVERALL_STATUS AS overall_status,
spd.DELIVERY_NUMBER as delivery_id,
spd.DELIVERY_ITEM as delivery_item,	
spd.DELIVER_MATERIAL as delivery_material_desc,	
spd.DELIVERY_MATERIAL_GROUP AS delivery_material_group,
spd.DELIVERY_STORAGE_LOACTION as delivery_storage_location,
spd.DELIVERY_PLANT as delivery_plant,
spd.DELIVERY_ORDER_NUMBER as delivery_order_number,
spd.DELIVERY_ORDER_ITEM as delivery_order_item,	
spd.DELIVERY_ERNAM as delivery_ernam,
spd.INVOICE_NUMBER as invoice_no,	
spd.INVOICE_CATEGORY as invoice_category,
spd.INVOICE_TYPE as invoice_type,
spd.INVOICE_SALES_ORGANIZATION AS invoice_sales_organization,
spd.INVOICE_DISTRIBUTION_CHANNEL AS invoice_distribution_channel,
spd.INVOICE_DIVISION AS invoice_division,
spd.INVOICE_AMOUNT AS billing_item_value_wth_tax,
spd.GROSS_INVOICE_AMOUNT AS billing_item_value,
spd.DOCUMENT_CONDITION_NUMBER AS document_condition_number,
spd.INVOICE_SOLD_TO_PARTY AS invoice_sold_to_party,
spd.INVOICE_ERNAM AS invoice_ernam,
spd.INVOICE_PLANT AS INVOICE_PLANT,
spd.INVOICE_ITEM as billing_item,	
spd.INVOICE_MATERIAL as invoice_material_desc,	
spd.INVOICE_STORAGE_LOACTION AS invoice_storage_location,
spd.ACTUAL_BILLED_QTY as billing_item_quantity,	
spd.INVOICE_DELIVERY_NUMBER AS invoice_delivery_number,
spd.INVOICE_DELIVERY_item AS invoice_delivery_item,
spd.INVOICE_ORDER_NUMBER AS invoice_order_number,
spd.INVOICE_order_item AS invoice_order_item,
spd.BILLING_TYPE_ANALYTICS AS billing_type_analytics,
spd.BILLING_DATE as invoice_date,		
spd.INVOICE_SALES_ORGANIZATION as invoice_sales_org,		
spd.BILLING_DATE as billing_date,	
GETDATE() AS createdatetime,
'SAP' AS source_system
FROM dbo.VW_SPARES_ICMC_ODI_DATA spd
INNER JOIN dbo.SAP_ZSD_DEALER_REPOS dr on spd.SOLD_TO_DEALER_OR_DISTRIBUTOR = dr.kunnr and TRIM(UPPER(dr.KATR6)) in ( 'PB' ,'TRM')
WHERE spd.DISTRIBUTION_CHANNEL IN ('10') 
AND TRIM(UPPER(spd.ORDER_DIVISION))='B1' 
AND TRIM(UPPER(spd.SALES_ORGANIZATION))='ZDOM' 
--AND TRIM(UPPER(spd.ORDER_PLANT)) = 'WA02' 
AND TRIM(UPPER(SPD.ORDER_TYPE)) IN('ZSTD','ZSCH','ZVOR','ZPSD','ZPSH','ZPVR','ZSPD')
AND (TRIM(UPPER(spd.ORDER_PLANT)) = 'WA02'  OR ((TRIM(UPPER(spd.ORDER_PLANT)) = 'CK02' AND SPD.ORDER_MATERIAL IN ('36JG0185','36JP0199','36JP0198', '36TA0188'))))

PRINT('DATA LOADED INTO ODI STAGING TABLE');


---------------------------------------------------------------------------------------------------------------


/*-----------STOCK DATA STAGING TABLE  

PRINT('LOADING DATA FROM BASE TABLE INTO STOCK STAGING TABLE');

DECLARE @MAXDATESTG02 DATETIME2(7)= (SELECT MAX(IMPORTEDDATE) FROM ASM_PB_SPARES_STOCK_STG)


IF OBJECT_ID('tempdb..#SPtemp') IS NOT NULL 
DROP TABLE #SPtemp;

SELECT DISTINCT
    cast(pv.CompanyCode as varchar) as CompanyCode,
    cast(pv.PartCode as varchar) as PartCode,
    pv.NetStock,
    pv.NetValue,
    pv.ToDate,
    CASE
        WHEN pv.netstock < pv.previous_netstock OR pv.previous_netstock IS NULL THEN pv.todate
        ELSE NULL
    END AS last_movement_date,
    MIN(pv.todate) OVER (PARTITION BY pv.companycode, pv.partcode) AS earliest_todate,
	pv.importeddate,
		ROW_NUMBER() OVER ( PARTITION BY pv.CompanyCode, pv.PartCode ORDER BY pv.ToDate DESC ) AS rn
INTO #SPtemp  
FROM (
    SELECT DISTINCT 
        sd.CompanyCode,
        sd.PartCode,
        sd.NetStock,
        sd.NetValue,
        CAST(sd.ToDate AS DATE) AS todate, 
        LAG(sd.netstock) OVER ( PARTITION BY sd.companycode, sd.partcode ORDER BY sd.todate ) AS previous_netstock,
		sd.importeddate
    FROM SPARE_STOCK_DATA_NEW sd 
    JOIN COMPANY_MASTER cm  ON sd.companycode = cm.code  AND cm.companytype = 2
	where sd.IMPORTEDDATE  > @MAXDATESTG02 
    --WHERE sd.PartCode = 'GF161168' 
) pv;

INSERT INTO [dbo].[ASM_PB_SPARES_STOCK_STG]
SELECT DISTINCT
cd.companycode,
cd.partcode,
MAX(CASE WHEN cd.rn = 1 THEN cd.netstock END) AS netstock,
MAX(CASE WHEN cd.rn = 1 THEN cd.NetValue END) AS netvalue,
COALESCE(MAX(cd.last_movement_date), MIN(cd.earliest_todate)) AS last_movement_date,
GETDATE() AS createdatetime,
'CDMS' AS source_system,
MAX(cd.importeddate) As Importeddate
from #SPtemp cd
GROUP BY cd.companycode,cd.partcode



PRINT('DATA LOADED INTO STOCK STAGING TABLE');

*/
-------------------INTO FACT---------------------------------------------------------



PRINT('LOADING DATA FROM BASE TABLE INTO FACT TABLE');

TRUNCATE TABLE [dbo].[ASM_PB_SPARES_FACT];

INSERT INTO [dbo].[ASM_PB_SPARES_FACT]
SELECT DISTINCT
spd.order_id AS order_id,	
spd.material_desc AS material_desc,	
spd.item AS item,	
spd.item_desc AS item_desc,	
spd.order_quantity AS order_quantity,
spd.order_item_quantity AS order_item_quantity,	
spd.order_item_value AS order_item_value,	  
spd.order_item_value_wth_tax AS order_item_value_wth_tax,
spd.storage_location AS storage_location,	
spd.order_plant AS order_plant,	
spd.order_item_date AS order_item_date,	
spd.sales_org AS sales_org,	
case 
    when TRIM(UPPER(spd.sales_order_type)) in ('ZSTD','ZSCH') then 'DPO'
    when TRIM(UPPER(spd.sales_order_type)) = 'ZVOR' then 'VOR'
    else 'OTHERS'
END AS sales_order_category,
spd.DISTRIBUTION_CHANNEL AS DISTRIBUTION_CHANNEL,	
spd.dealer_code AS dealer_code,	
spd.sales_order_type AS sales_order_type,	
spd.item_category AS item_category,	
spd.order_division AS order_division,
spd.reason_for_rejection AS reason_for_rejection,	
spd.delivery_item_quantity AS delivery_item_quantity,	
spd.material_group AS material_group,	
spd.delivery_item_date AS delivery_item_date,	
spd.delivery_shipping_point AS delivery_shipping_point,
spd.delivery_type AS delivery_type,
spd.customer_number AS customer_number,
spd.ship_to_party AS ship_to_party,
spd.return_indicator AS return_indicator,
spd.delivery_item_value AS delivery_item_value,
spd.delivery_item_value_wth_tax AS delivery_item_value_wth_tax,
spd.delivery_status AS delivery_status,
spd.overall_status AS overall_status,
spd.delivery_id AS delivery_id,
spd.delivery_item AS delivery_item,	
spd.delivery_material_desc AS delivery_material_desc,	
spd.delivery_material_group AS delivery_material_group,
spd.delivery_storage_location AS delivery_storage_location,
spd.delivery_plant AS delivery_plant,
spd.delivery_order_number AS delivery_order_number,
spd.delivery_order_item AS delivery_order_item,	
spd.delivery_ernam AS delivery_ernam,
spd.backorder_item_date as backorder_item_date,
case 
    when spd.delivery_item is null then spd.order_quantity
    when spd.order_quantity - sum(spd.delivery_item_quantity) over (partition by spd.order_id,spd.item,spd.material_desc order by spd.delivery_item_date) >= 0
    then spd.order_quantity - sum(spd.delivery_item_quantity) over (partition by spd.order_id,spd.item,spd.material_desc order by spd.delivery_item_date)
    else 0
end as backorder_quantity,
case 
    when spd.delivery_item is null then spd.order_item_value
    when spd.order_quantity - sum(spd.delivery_item_quantity) over (partition by spd.order_id,spd.item,spd.material_desc order by spd.delivery_item_date) >= 0
    then (spd.order_quantity - sum(spd.delivery_item_quantity) over (partition by spd.order_id,spd.item,spd.material_desc order by spd.delivery_item_date))*(spd.order_item_value/NULLIF(spd.order_quantity,0)) 
    else 0
end as backorder_item_value,
spd.invoice_no AS invoice_no,	
spd.invoice_category AS invoice_category,
spd.invoice_type AS invoice_type,
spd.invoice_sales_organization AS invoice_sales_organization,
spd.invoice_distribution_channel AS invoice_distribution_channel,
spd.invoice_division AS invoice_division,
spd.billing_item_value_wth_tax AS billing_item_value_wth_tax,
spd.billing_item_value AS billing_item_value,
spd.document_condition_number AS document_condition_number,
spd.invoice_sold_to_party AS invoice_sold_to_party,
spd.invoice_ernam AS invoice_ernam,
spd.INVOICE_PLANT AS INVOICE_PLANT,
spd.billing_item AS billing_item,	
spd.invoice_material_desc AS invoice_material_desc,	
spd.invoice_storage_location AS invoice_storage_location,
spd.billing_item_quantity AS billing_item_quantity,	
spd.invoice_delivery_number AS invoice_delivery_number,
spd.invoice_delivery_item AS invoice_delivery_item,
spd.invoice_order_number AS invoice_order_number,
spd.invoice_order_item AS invoice_order_item,
spd.billing_type_analytics AS billing_type_analytics,
spd.invoice_date AS invoice_date,		
spd.invoice_sales_org AS invoice_sales_org,		
spd.billing_date AS billing_date,	
SPH.DOCDATE as grn_date,
bm.Code AS Branch_code,
bm.branchid AS Branch_id,
IM.ITEMID AS MODEL_ID,
null as netstock,
null as netvalue,
null as last_movement_date,
getdate() as createdatetime,
'STAGING' as source_system,
null as PartCode,
IM.Code AS Itemcode
from dbo.ASM_PB_SPARES_ODI_STG spd
--left join dbo.ASM_UB_SPARES_DEALER_DIM dm on trim(upper(spd.dealer_code)) = trim(upper(dm.dealer_code)) --and spd.distr_chnl = dm.distr_chnl
left join COMPANY_MASTER CM ON spd.dealer_code=CM.CODE  AND CM.COMPANYTYPE = 2 AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
LEFT JOIN BRANCH_MASTER bm ON CM.CODE = BM.CODE 
LEFT JOIN SPARE_PURCHASE_HEADER SPH ON SPH.CompanyID=CM.COMPANYID AND CM.COMPANYTYPE=2 AND  spd.delivery_id = SPH.EXTERNALCODE

--left join dbo.ASM_PB_SPARES_STOCK_STG st
--on spd.dealer_code = st.dealer_code and spd.material_desc = st.partcode
left JOIN [dbo].[ITEM_MASTER] IM ON IM.CODE = spd.material_desc

PRINT('DATA LOADED INTO FACT TABLE');


----------DEDUP------------------
/*
;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY order_id, ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_MC_PM_PARTS_REPORT              
)          
DELETE FROM CTE                  
WHERE RNK<>1;

*/



END
GO