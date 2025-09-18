SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


alter PROC [dbo].[USP_ASM_MC_SERVICE_SPARES_BGO_DIM_FULLOAD_P3]
AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			    */
-----------------------------------------------------------------------------------------------------
/*--------------------------------------------------------------------------------------------------*/
/* 2025-03-18 	|	Dewang Makani		    | ASM_MC_SERVICE_SPARES_AND_BGO_DIM and ASM_MC_SERVICE_ASD_ORD_INV_DIM - New Dim Table Created */
/* 2025-08-06   |   Rashi Pradhan           | Upadted NDP value for order and invoice for spares in ASM_MC_SERVICE_SPARES_AND_BGO_DIM */
/* 2025-09-01   |   Lachmanna               | Order Dupicate issue changed the code  */
/* 2025-09-15  |   Lachmanna               | billing Dupicate issue changed the code  */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

PRINT('LOADING DATA FROM Source TABLE')

PRINT('INSERTING DATA INTO ASM_MC_SERVICE_SPARES_AND_BGO_DIM TABLE')

DELETE FROM ASM_MC_SERVICE_SPARES_AND_BGO_DIM WHERE Spares_BGO_Identifier = 'Spares'

INSERT INTO ASM_MC_SERVICE_SPARES_AND_BGO_DIM

SELECT DISTINCT 
OTD.ORDER_NO AS Order_No
,NULL AS BGO_lineid
,OTD.ORDER_DATE AS Order_Date
,CASE 
	WHEN OTD.ORDER_TYPE = 'ZVOR'
	THEN 'VOR'
	ELSE 'DPO'
END AS Order_Type
,OTD.ORDER_QUANTITY AS Order_Qty
,IBD.REORDERQTY AS ROL_Qty
,OTD.ORDER_REJECTION_REASON AS Spares_Order_Rejection
,IM.ITEMID AS ItemID
,OTD.GROSS_ORDER_AMOUNT AS Order_Amount  ---updated to gross amount(RP)
-- ,OTD.GROSS_ORDER_AMOUNT AS Gross_Order_Amount
,CM.CODE AS Ordered_DealerCode
,BM.BRANCHID AS BranchID
,OTD.DELIVERY_NUMBER AS Delivery_No
,OTD.DELIVERY_DATE AS Delivery_Date
-- ,OTD.DELIVERY_QUANTITY AS Delivery_Qty
-- ,OTD.DELIVERY_AMOUNT AS Delivery_Amount
-- ,OTD.GROSS_DELIVERY_AMOUNT AS Gross_Delivery_Amount
,OTD.INVOICE_NUMBER AS Invoice_No
,OTD.INVOICE_ITEM AS Invoice_item_spares
,NULL AS DispatchID_bgo
,OTD.BILLING_DATE AS Invoice_Date
,CASE 
	WHEN OTD.INVOICE_TYPE = 'ZVOR'
	THEN 'VOR'
	ELSE 'DPO'
END AS Invoice_Type
,OTD.ACTUAL_BILLED_QTY AS Invoice_Qty
,OTD.GROSS_INVOICE_AMOUNT AS Invoice_Amount   ---updated to gross amount(RP)
-- ,OTD.GROSS_INVOICE_AMOUNT AS Gross_Invoice_Amount
,SPH.DOCNAME AS GRN_Document_Name
,CAST(SPH.DOCDATE AS DATE) AS GRN_DocDate
,OTD.ORDER_VBAK_DATALOADTIME AS ORDER_VBAK_DATALOADTIME
-- ,OTD.ORDER_VBAP_DATALOADTIME AS ORDER_VBAP_DATALOADTIME
-- ,OTD.DELIVERY_LIKP_DATALOADTIME AS DELIVERY_LIKP_DATALOADTIME
-- ,OTD.DELIVERY_LIPS_DATALOADTIME AS DELIVERY_LIPS_DATALOADTIME
-- ,OTD.INVOICE_VBRK_DATALOADTIME AS INVOICE_VBRK_DATALOADTIME
-- ,OTD.INVOICE_VBRP_DATALOADTIME AS INVOICE_VBRP_DATALOADTIME
-- ,NULL AS BGO_Importeddate
,getdate() as RefreshDate
,'Spares' AS Spares_BGO_Identifier
,ROW_NUMBER() OVER (PARTITION BY OTD.order_no, IM.itemid, OTD.ORDER_QUANTITY ORDER BY OTD.ORDER_VBAK_DATALOADTIME desc)  AS RepeatOrderCount_spares 
,ROW_NUMBER() OVER (PARTITION BY OTD.INVOICE_NUMBER, IM.itemid, OTD.ACTUAL_BILLED_QTY, OTD.BILLING_DATE, OTD.INVOICE_ITEM ORDER BY ORDER_VBAK_DATALOADTIME desc) AS   RepeatInvoiceCount_spares
,NULL AS RepeatOrderCount_bgo
,NULL AS RepeatInvoiceCount_bgo
FROM [dbo].[VW_SPARES_ICMC_ODI_DATA] OTD
INNER JOIN [dbo].[ITEM_MASTER] IM ON IM.CODE = OTD.ORDER_MATERIAL
INNER JOIN ITEM_GROUP_DETAIL_NEW IGD ON IGD.ITEMID = IM.ITEMID
INNER JOIN COMPANY_MASTER CM ON OTD.SOLD_TO_DEALER_OR_DISTRIBUTOR = CM.CODE AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID 
AND CM1.COMPANYTYPE IN (1,8))
LEFT JOIN BRANCH_MASTER BM ON OTD.SOLD_TO_DEALER_OR_DISTRIBUTOR = BM.CODE
LEFT JOIN CDMS_ITEM_BRANCH_DATA IBD ON IBD.BRANCHID = BM.BRANCHID AND IBD.ITEMID = IM.ITEMID 
AND IBD.IMPORTEDDATE = (SELECT MAX(IMPORTEDDATE) FROM CDMS_ITEM_BRANCH_DATA IBD1 WHERE IBD1.ID = IBD.ID)
LEFT JOIN SPARE_PURCHASE_HEADER SPH ON SPH.SUPPLIERINVOICENO = OTD.INVOICE_NUMBER
WHERE OTD.SALES_ORGANIZATION = 'ZDOM'
AND OTD.DISTRIBUTION_CHANNEL = '10'
AND OTD.ORDER_TYPE IN ('ZSTD', 'ZSCH', 'ZPSD', 'ZPSH', 'ZSPD', 'ZVOR')
AND OTD.ORDER_DIVISION = 'B1'
AND (OTD.DELIVERY_TYPE IN ('ZSTD', 'ZSCH', 'ZPSD', 'ZPSH', 'ZSPD', 'ZVOR') OR OTD.DELIVERY_TYPE IS NULL)
AND (OTD.INVOICE_TYPE IN ('ZSTD', 'ZSCH', 'ZPSD', 'ZPSH', 'ZSPD', 'ZVOR') OR OTD.INVOICE_TYPE IS NULL)
AND (OTD.INVOICE_SALES_ORGANIZATION = 'ZDOM' OR OTD.INVOICE_SALES_ORGANIZATION IS NULL)
AND (OTD.INVOICE_DISTRIBUTION_CHANNEL = '10' OR OTD.INVOICE_DISTRIBUTION_CHANNEL IS NULL)
AND (OTD.INVOICE_DIVISION = 'B1' OR OTD.INVOICE_DIVISION IS NULL)
AND OTD.ORDER_DATE > '2022-04-01'
-- AND OTD.ORDER_REJECTION_REASON = ''
AND IGD.Itemgrouptype IN ('BAL Parts','OILS') and (( OTD.ORDER_REJECTION_REASON = '') or (OTD.ORDER_REJECTION_REASON <> '' and otd.INVOICE_NUMBER is not null)) 



----------Update for Repeated Order lines----------

--;WITH RepeatedOrderLine_Spares AS (
--    SELECT 
--        order_no, 
--        itemid, 
--        order_qty,
--       ROW_NUMBER() OVER (PARTITION BY order_no, itemid, order_qty ORDER BY (SELECT order_no)) AS row_seq,
--	   ORDER_VBAK_DATALOADTIME,
--	   Delivery_No
--    FROM ASM_MC_SERVICE_SPARES_AND_BGO_DIM WHERE Spares_BGO_Identifier = 'Spares'
--)
--UPDATE ASM_MC_SERVICE_SPARES_AND_BGO_DIM 
--SET RepeatOrderCount_spares = RepeatedOrderLine_Spares.row_seq 
--FROM ASM_MC_SERVICE_SPARES_AND_BGO_DIM Spares_dim
--JOIN RepeatedOrderLine_Spares
--ON 
--	Spares_dim.order_no = RepeatedOrderLine_Spares.order_no and 
--	Spares_dim.itemid = RepeatedOrderLine_Spares.itemid and 
--	Spares_dim.order_qty = RepeatedOrderLine_Spares.order_qty and
--	COALESCE(Spares_dim.ORDER_VBAK_DATALOADTIME, '1900-01-01') = COALESCE(RepeatedOrderLine_Spares.ORDER_VBAK_DATALOADTIME, '1900-01-01') and
--	COALESCE(Spares_dim.Delivery_No, '') = COALESCE(RepeatedOrderLine_Spares.Delivery_No, '')
--WHERE Spares_dim.Spares_BGO_Identifier = 'Spares';


---------------Update for Repeated Invoice lines-----------

/*;WITH RepeatedInvoiceLine_Spares AS (
    SELECT 
        Invoice_no, 
        itemid,
		invoice_qty,
		invoice_date,
		Invoice_item_spares,
       ROW_NUMBER() OVER (PARTITION BY Invoice_no, itemid, invoice_qty, invoice_date, Invoice_item_spares ORDER BY (SELECT Invoice_no)) AS row_seq,
	   ORDER_VBAK_DATALOADTIME
	   --order_no
    FROM ASM_MC_SERVICE_SPARES_AND_BGO_DIM WHERE Spares_BGO_Identifier = 'Spares'
)
UPDATE ASM_MC_SERVICE_SPARES_AND_BGO_DIM 
SET RepeatInvoiceCount_spares = RepeatedInvoiceLine_Spares.row_seq 
FROM ASM_MC_SERVICE_SPARES_AND_BGO_DIM Spares_dim
JOIN RepeatedInvoiceLine_Spares
ON 
	Spares_dim.Invoice_no = RepeatedInvoiceLine_Spares.Invoice_no and 
	Spares_dim.itemid = RepeatedInvoiceLine_Spares.itemid and 
	Spares_dim.invoice_qty = RepeatedInvoiceLine_Spares.invoice_qty and
	Spares_dim.invoice_date = RepeatedInvoiceLine_Spares.invoice_date and 
	Spares_dim.Invoice_item_spares = RepeatedInvoiceLine_Spares.Invoice_item_spares and
	COALESCE(Spares_dim.ORDER_VBAK_DATALOADTIME, '1900-01-01') = COALESCE(RepeatedInvoiceLine_Spares.ORDER_VBAK_DATALOADTIME, '1900-01-01')
	--Spares_dim.order_no = RepeatedInvoiceLine_Spares.order_no
WHERE Spares_dim.Spares_BGO_Identifier = 'Spares'; */


-------------BGO Insertion--------

DELETE FROM ASM_MC_SERVICE_SPARES_AND_BGO_DIM WHERE Spares_BGO_Identifier = 'BGO'

INSERT INTO ASM_MC_SERVICE_SPARES_AND_BGO_DIM

SELECT DISTINCT 
HPCL_ORD.ORDER_NO AS Order_No
,HPCL_ORD.LINE_NO AS BGO_lineid
,TRY_CAST(HPCL_ORD.ORDER_DATE AS DATE) AS Order_Date
,NULL AS Order_Type
,HPCL_ORD.KWMENG AS Order_Qty
,NULL AS ROL_Qty
,NULL AS Spares_Order_Rejection
,IM.ITEMID AS ItemID
,HPCL_ORD.TOTAL_PRICE AS Order_Amount
-- ,NULL AS Gross_Order_Amount
,CM.CODE AS Ordered_DealerCode
,BM.BRANCHID AS BranchID
,NULL AS Delivery_No
,NULL AS Delivery_Date
-- ,NULL AS Delivery_Qty
-- ,NULL AS Delivery_Amount
-- ,NULL AS Gross_Delivery_Amount
,HPCL_DISP.ORDER_NO AS Invoice_No
,NULL AS Invoice_item_spares
,HPCL_DISP.DISPATCH_ID AS DispatchID_bgo
,TRY_CAST(HPCL_DISP.DISPATCH_DATE AS DATE) AS Invoice_Date
,NULL AS Invoice_Type
,HPCL_DISP.DISPATCH_QTY AS Invoice_Qty
,HPCL_DISP.BASE_AMOUNT AS Invoice_Amount
-- ,NULL AS Gross_Invoice_Amount
,SPH.DOCNAME AS GRN_Document_Name
,CAST(SPH.DOCDATE AS DATE) AS GRN_DocDate
,NULL AS ORDER_VBAK_DATALOADTIME
-- ,NULL AS ORDER_VBAP_DATALOADTIME
-- ,NULL AS DELIVERY_LIKP_DATALOADTIME
-- ,NULL AS DELIVERY_LIPS_DATALOADTIME
-- ,NULL AS INVOICE_VBRK_DATALOADTIME
-- ,NULL AS INVOICE_VBRP_DATALOADTIME
-- ,TRY_CAST(HPCL_ORD.ORDER_DATE AS DATE) AS BGO_Importeddate
,getdate() as RefreshDate
,'BGO' AS Spares_BGO_Identifier
,NULL AS RepeatOrderCount_spares
,NULL AS RepeatInvoiceCount_spares
,NULL AS RepeatOrderCount_bgo
,NULL AS RepeatInvoiceCount_bgo
FROM SAP_ZHPCL_ORDER HPCL_ORD
LEFT JOIN SAP_ZHPCL_DISPATCH HPCL_DISP ON (HPCL_DISP.ORDER_NO = HPCL_ORD.ORDER_NO AND HPCL_DISP.MATNR = HPCL_ORD.MATNR)
INNER JOIN COMPANY_MASTER CM ON HPCL_ORD.KUNNR = CM.CODE AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID 
AND CM1.COMPANYTYPE IN (1,8))
INNER JOIN ITEM_MASTER IM ON IM.CODE = HPCL_ORD.MATNR
INNER JOIN ITEM_GROUP_DETAIL_NEW IGD ON IGD.ITEMID = IM.ITEMID 
LEFT JOIN BRANCH_MASTER BM ON BM.CODE = HPCL_ORD.KUNNR
LEFT JOIN SPARE_PURCHASE_HEADER SPH ON SPH.EXTERNALCODE = HPCL_DISP.ORDER_NO
WHERE TRY_CAST(HPCL_ORD.ORDER_DATE AS DATE)>'2022-04-01' AND HPCL_ORD.ORDER_STATUS NOT IN ('300', '301') AND IGD.ItemGroupType IN ('BAL Parts','OILS')
AND IM.CODE NOT IN ('83020565','83010499','83020574','83020524','83020566','83020515',
'83020332','83020573','OILCRGJG','OILCRGJU','83020591','83020338','36JF0145','83020473','83020331', 'LUBHPGOIL90', 'EOIL',
'83020340','83020651','83020602','83010498','83020408','83020598','83020333','83020463', '36001058', 'MOTUL - 20W50 (3100)')

--------------Update for Repeated Order Lines----------

;WITH RepeatOrderLine AS (
    SELECT 
        order_no, 
        itemid, 
        order_qty,
		BGO_lineid,
        ROW_NUMBER() OVER (PARTITION BY order_no, itemid, order_qty, BGO_lineid ORDER BY (SELECT order_no)) AS row_seq,
        DispatchID_bgo,
		invoice_qty,
        invoice_date,
        invoice_amount,
        grn_document_name
    FROM ASM_MC_SERVICE_SPARES_AND_BGO_DIM
    WHERE Spares_BGO_Identifier = 'BGO'
)
UPDATE ASM_MC_SERVICE_SPARES_AND_BGO_DIM
SET RepeatOrderCount_bgo = RepeatOrderLine.row_seq
FROM ASM_MC_SERVICE_SPARES_AND_BGO_DIM Spares_dim
JOIN RepeatOrderLine
    ON Spares_dim.order_no = RepeatOrderLine.order_no
    AND Spares_dim.itemid = RepeatOrderLine.itemid
    AND Spares_dim.order_qty = RepeatOrderLine.order_qty
    AND Spares_dim.BGO_lineid = RepeatOrderLine.BGO_lineid
    AND COALESCE(Spares_dim.DispatchID_bgo, '') = COALESCE(RepeatOrderLine.DispatchID_bgo, '')
    AND COALESCE(Spares_dim.invoice_qty, 0) = COALESCE(RepeatOrderLine.invoice_qty, 0)
    AND COALESCE(Spares_dim.invoice_date, '1900-01-01') = COALESCE(RepeatOrderLine.invoice_date, '1900-01-01')
    AND COALESCE(Spares_dim.invoice_amount, 0) = COALESCE(RepeatOrderLine.invoice_amount, 0)
    AND COALESCE(Spares_dim.grn_document_name, '') = COALESCE(RepeatOrderLine.grn_document_name, '')
WHERE Spares_dim.Spares_BGO_Identifier = 'BGO';

---------Update for Repeated Inovice lines---------

;WITH RepeatedInvoiceLine AS (
    SELECT 
        order_no, 
        itemid, 
        order_qty,
		invoice_date,
		DispatchID_bgo,
       ROW_NUMBER() OVER (PARTITION BY order_no, itemid, order_qty, invoice_date, DispatchID_bgo ORDER BY (SELECT order_no)) AS row_seq,
	   grn_document_name
    FROM ASM_MC_SERVICE_SPARES_AND_BGO_DIM WHERE Spares_BGO_Identifier = 'BGO'
)
UPDATE ASM_MC_SERVICE_SPARES_AND_BGO_DIM 
SET RepeatInvoiceCount_bgo = RepeatedInvoiceLine.row_seq 
FROM ASM_MC_SERVICE_SPARES_AND_BGO_DIM Spares_dim
JOIN RepeatedInvoiceLine
ON 
	Spares_dim.order_no = RepeatedInvoiceLine.order_no and 
	Spares_dim.itemid = RepeatedInvoiceLine.itemid and 
	Spares_dim.order_qty = RepeatedInvoiceLine.order_qty and
	Spares_dim.invoice_date = RepeatedInvoiceLine.invoice_date and
	Spares_dim.DispatchID_bgo = RepeatedInvoiceLine.DispatchID_bgo and
	COALESCE(Spares_dim.grn_document_name, '') = COALESCE(RepeatedInvoiceLine.grn_document_name, '')
WHERE Spares_dim.Spares_BGO_Identifier = 'BGO';

PRINT('ASM_MC_SERVICE_SPARES_AND_BGO_DIM TABLE LOADED')

--------- ASD Spares BGO DML ---------

-------ASD Orders 

PRINT('INSERTING DATA INTO ASM_MC_SERVICE_ASD_ORD_INV_DIM TABLE')

DELETE FROM ASM_MC_SERVICE_ASD_ORD_INV_DIM WHERE Ord_Inv_Identifier = 'ASD_Orders'

INSERT INTO ASM_MC_SERVICE_ASD_ORD_INV_DIM

SELECT DISTINCT PH.DOCNAME AS Docname
,CAST(PH.DOCDATE AS DATE) AS Docdate
,CM.CODE AS DealerCode
,CM.CODE AS ASD_Dealercode
,PH.BranchID AS BranchID
,PP.ITEMID AS ItemID
,CAST(IG.Itemgrouptype AS VARCHAR(100))  AS ItemgroupType
,PP.QTY AS Qty
,PP.RATE AS Rate
,'MC' AS BU
,'ASD_Orders' AS Ord_Inv_Identifier
,PH.IMPORTEDDATE AS Importeddate
,getdate() AS RefreshDate

FROM [dbo].[PURCHASE_HEADER] PH 
LEFT JOIN [dbo].[PURCHASE_POSTING] PP ON PP.CDMSDOCID = PH.CDMSUNIQUEID
LEFT JOIN [dbo].[ITEM_MASTER] IM ON IM.ITEMID = PP.ITEMID
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=PP.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=PH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (1,8))
WHERE (CM.CODE LIKE '000002%' OR CM.CODE LIKE '000006%')
AND CAST(PH.DOCDATE AS DATE) > '2022-04-01' AND IG.itemgrouptype IN ('BAL Parts','OILS') 


----- ASD Invoices

DELETE FROM ASM_MC_SERVICE_ASD_ORD_INV_DIM WHERE Ord_Inv_Identifier = 'ASD_Invoice'

INSERT INTO ASM_MC_SERVICE_ASD_ORD_INV_DIM

SELECT DISTINCT SPH.DOCNAME AS Docname
,CAST(SPH.DOCDATE AS DATE) AS Docdate
,CM.CODE AS DealerCode
,CM.CODE AS ASD_Dealercode
,SPH.BRANCHID AS BranchID
,SPL.ITEMID AS ItemID
,CAST(IG.Itemgrouptype AS VARCHAR(100))  AS ItemgroupType
,SPL.QTY AS Qty
,SPL.RATE AS Rate
,'MC' AS BU
,'ASD_Invoice' AS Ord_Inv_Identifier
,SPH.IMPORTEDDATE AS Importeddate
,getdate() AS RefreshDate

FROM [dbo].[SPARE_PURCHASE_HEADER] SPH 
LEFT JOIN [dbo].[SPARE_PURCHASE_LINE] SPL ON SPL.CDMSDOCID = SPH.CDMSUNIQUEID
LEFT JOIN [dbo].[ITEM_MASTER] IM ON IM.ITEMID = SPL.ITEMID
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=SPL.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SPH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (1,8))
WHERE (CM.CODE LIKE '000002%' OR CM.CODE LIKE '000006%')
AND CAST(SPH.DOCDATE AS DATE) > '2022-04-01' AND IG.itemgrouptype IN ('BAL Parts','OILS') 


----------------------Update for ASD Dealer Mapping ---------
SELECT * INTO #ASDDealerMapping FROM
(SELECT DISTINCT ZF_ASC ASD_DEALERCODE,DEALER_CODE DEALERCODE
FROM SAP_ZSD_ASC_DETAIL
WHERE SER_STATUS = 'OPERATIONAL')T

UPDATE B
SET B.Dealercode=A.DEALERCODE
FROM ASM_MC_SERVICE_ASD_ORD_INV_DIM B
INNER JOIN #ASDDealerMapping A on B.ASD_Dealercode = A.ASD_DEALERCODE

PRINT('ASM_MC_SERVICE_ASD_ORD_INV_DIM TABLE LOADED')

END
GO