/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			    */
/*--------------------------------------------------------------------------------------------------*/
/*	2024-09-10 	|	Ashwini Ahire		| ASM_MC_SERVICE_P3_STG                     */
/*	                                                 ASM_MC_SERVICE_P3_FACT                     */  
/*	2024-02-12 	|	Ashwini Ahire		| Added ELF Code                            */                                                       
/*	2025-02-28 	|	Dewang Makani		| Added RefreshDate and commented p3 fact            
    2025-09-18 	|	Richa     		    | Excludecode table replaced by table DM_CodeInclusionExclusion_Master   and addition of ABC table       */                                                       
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_MC_SERVICE_P3_STG_FACT_FULLOAD] AS

BEGIN

PRINT('LOADING DATA FROM BASE TABLE')
TRUNCATE TABLE ASM_MC_SERVICE_P3_STG

--------------------------For JC '2020-04-01' Till '2021-03-31'

INSERT INTO ASM_MC_SERVICE_P3_STG

SELECT BASE.*
,Pretaxrevenue+Totaltax AS Posttaxrevenue
,null as repeat_type
,null as repeated_from_lined
,null as repeated_from_docname
,null as repeated_from_docdate
,null as Part_Repeat_Count
,null as CANCELLATIONDATE
,IBM.InvoiceDate AS InvoiceDate
,IBM.ProductionDate AS ProductionDate
,getdate() AS Refreshdate
FROM
(SELECT DISTINCT 
  SL.Type
 ,SH.CONTRACTTYPEID AS [FK_Contracttypeid]
 ,SL.CONTRACTTYPEID as [FK_PartContracttypeid]
 ,SL.LINEID AS Lineid
 ,SH.HEADERID AS [FK_Docid]
 ,SH.DOCNAME
 ,CAST(SH.Docdate AS DATE) AS Docdate
 ,SH.COMPANYID AS [FK_Companyid]
 ,SH.CONTACTID AS FK_Contactid
 ,SH.Isclosed
 ,SL.ITEMID AS [FK_Itemid]
 ,SH.IBID AS [FK_Ibid]
 ,SH.BRANCHID AS [FK_Branchid]
 ,SH.MODELID AS [FK_Modelid]
 ,SH.BU
 ,CM.COMPANYTYPE
 ,SL.TOTALTAX
 ,SH.Isrevisited 
 ,0 as Isrepeated 
 ,CASE WHEN SL.QtyAllocated = 0 Then (((SL.Qty - SL.QtyCancelled) * SL.Rate)   - SL.TradeDiscount ) 
       Else (((SL.QtyAllocated - SL.QtyReturned) * SL.Rate ) - SL.TradeDiscount ) END AS Pretaxrevenue
 ,CAST(IG.Itemgrouptype AS NVARCHAR(225)) AS Itemgrouptype
 ,CASE  WHEN SH.CONTRACTTYPEID IN (2,13,41,42,177,178,179,192,193) THEN 1
        WHEN SH.CONTRACTTYPEID NOT IN (38,39,40,8,168) AND IM.CODE IN ('BMPS0001','BMSL0029','AMCBAL001','AMCBAL002','AMCBAL003','AMCBAL004','AMCBAL005','AMCBAL006','AMCBAL007'
          ,'AMCBAL008','AMCBAL009','AMCBAL010','AMCBAL011','AMCBAL012','AMCBAL013','AMCBAL014','AMCBAL015','AMCBAL016','AMCBAL017','AMCBAL018','AMCBAL019','AMCBAL020'
          ,'AMCBAL021','AMCBAL022','AMCBAL023','AMCBAL024','AMCBAL025','AMCBAL026','AMCBAL027','AMCBAL028','AMCBAL029') THEN 1
       ELSE 0 END AS 'PaidFlag'             
 ,SCM1.NAME AS ServiceType
 ,CM.CODE AS DealerCode
 ,CM.CODE AS ASD_DealerCode
 ,SH.Importeddate
 ,CAST(SH.Vehicleinvoicedatetime AS DATE) AS Vehicleinvoicedatetime
 ,CAST(SH.Billeddatetime AS DATE) AS Billeddatetime
 ,SH.TOTALAMOUNT
 ,0 AS Delete_Flag
 ,101 AS Service_Retail_TypeIdentifier
 ,SH.Usagereading
 ,CASE
	WHEN SL.Type = 'Part' AND IG.ITEMGROUPTYPE = 'BAL Parts' 
	THEN 
	CASE 
		WHEN NOT EXISTS(
			SELECT 1
			FROM DM_CodeInclusionExclusion_Master EC
			WHERE EC.Code = IM.CODE
			AND EC.TypeFlag = 'Itemcode_001'
		)
		THEN  
		CASE 
			WHEN SL.CONTRACTTYPEID = 1
			THEN 'Warranty'
			WHEN SL.CONTRACTTYPEID = 8
			THEN 'PDI'
			WHEN SL.CONTRACTTYPEID = 170
			THEN '5 Year Warranty'
			WHEN SL.CONTRACTTYPEID = 198
			THEN 'Any Time Warranty'
			WHEN SL.CONTRACTTYPEID = 3
			THEN 'Special Sanction'
			WHEN SL.CONTRACTTYPEID IN (2,4,5,7,9,13,37,39,40,41,42,43,44,45,166,167,171,192,193)
			THEN 'Paid'
		END
		ELSE 'Others'
	END 
	ELSE 'Others'
END AS PartRepairType
 ,SLE.DefectCode AS DefectCode
-- ,SH.PDIOK AS PDIOk_Flag
--,SH.PDINOTOK AS PDINotOk_Flag
-- ,SH.PDINOWOK AS PDINowOk_Flag
-- ,SL.QtyInvoiced AS QtyInvoiced
 ,CASE
	WHEN SH.ISCLOSED = 0 AND (SH.READYFORBILLDATETIME IS NULL OR SH.READYFORBILLDATETIME IS NOT NULL) AND SH.BILLEDDATETIME IS NULL 
	THEN 'Open'
	WHEN SH.ISCLOSED = 1 AND SH.READYFORBILLDATETIME IS NOT NULL AND SH.BILLEDDATETIME IS NOT NULL 
	THEN 'Delivered/Closed'
  END AS JobCardStatus
,SH.FailureDate AS DateOfFailure
--,CTO.CutOffDate AS CutOff_date
FROM SERVICE_HEADER SH
LEFT JOIN SERVICE_LINE SL ON (SL.DOCID = SH.HEADERID AND SL.IMPORTEDDATE = (SELECT MAX(SL1.IMPORTEDDATE) FROM SERVICE_LINE SL1 WHERE SL1.ITEMID = SL.ITEMID AND SL.DOCID = SL1.DOCID))
INNER JOIN Bal_JC_2021 BCD ON BCD.LINEID=SL.LINEID
INNER JOIN SERVICE_CONTRACT_MASTER SCM1 ON SCM1.SERVICECONTRACTID=SH.CONTRACTTYPEID
INNER JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON IBM.Pk_ibid = SH.Ibid AND IBM.productiondate >= '2020-01-01'
LEFT JOIN SERVICE_LINE_EXT SLE ON SLE.LINEID = SL.LINEID  
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=SL.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
LEFT JOIN ITEM_MASTER IM ON IM.ITEMID=SL.ITEMID
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (1,8))
--LEFT JOIN [dbo].[CDMS_FFR_CUTOFF_VIN_MODEL_PARTDEFECT] CTO ON (CTO.ModelID = SH.ModelID AND CTO.PartID = IM.ItemID AND CTO.DefectCode = SLE.DefectCode) -- Adding this join for cutoff date (8/28/2024)
WHERE CAST(SH.DOCDATE AS DATE) BETWEEN '2020-04-01' AND '2021-03-31'
AND CM.CODE NOT IN ('0000028428')
AND SH.IBID IS NOT NULL
--AND ibm.productiondate >= '2020-01-01'
AND SH.CANCELLATIONDATE IS NULL
AND SL.ISCLOSED<>0
AND SL.QTYALLOCATED<>0 AND SL.QTYRETURNED<SL.QTYALLOCATED)BASE
INNER JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON IBM.Pk_ibid = BASE.FK_Ibid

--------------------------FOr JC '2021-04-01' Till '2022-03-31'
INSERT INTO ASM_MC_SERVICE_P3_STG

SELECT BASE.*
,Pretaxrevenue+Totaltax AS Posttaxrevenue
,null as repeat_type
,null as repeated_from_lined
,null as repeated_from_docname
,null as repeated_from_docdate
,null as Part_Repeat_Count
,null as CANCELLATIONDATE
,IBM.InvoiceDate AS InvoiceDate
,IBM.ProductionDate AS ProductionDate
,getdate() AS Refreshdate
FROM
(SELECT DISTINCT 
  SL.Type
 ,SH.CONTRACTTYPEID AS [FK_Contracttypeid]
 ,SL.CONTRACTTYPEID as [FK_PartContracttypeid]
 ,SL.LINEID AS Lineid
 ,SH.HEADERID AS [FK_Docid]
 ,SH.DOCNAME
 ,CAST(SH.Docdate AS DATE) AS Docdate
 ,SH.COMPANYID AS [FK_Companyid]
 ,SH.CONTACTID AS FK_Contactid
 ,SH.Isclosed
 ,SL.ITEMID AS [FK_Itemid]
 ,SH.IBID AS [FK_Ibid]
 ,SH.BRANCHID AS [FK_Branchid]
 ,SH.MODELID AS [FK_Modelid]
 ,SH.BU
 ,CM.COMPANYTYPE
 ,SL.TOTALTAX
 ,SH.Isrevisited 
 ,0 as Isrepeated 
 ,CASE WHEN SL.QtyAllocated = 0 Then (((SL.Qty - SL.QtyCancelled) * SL.Rate)   - SL.TradeDiscount ) 
       Else (((SL.QtyAllocated - SL.QtyReturned) * SL.Rate ) - SL.TradeDiscount ) END AS Pretaxrevenue
 ,CAST(IG.Itemgrouptype AS NVARCHAR(225)) AS Itemgrouptype
 ,CASE  WHEN SH.CONTRACTTYPEID IN (2,13,41,42,177,178,179,192,193) THEN 1
        WHEN SH.CONTRACTTYPEID NOT IN (38,39,40,8,168) AND IM.CODE IN ('BMPS0001','BMSL0029','AMCBAL001','AMCBAL002','AMCBAL003','AMCBAL004','AMCBAL005','AMCBAL006','AMCBAL007'
          ,'AMCBAL008','AMCBAL009','AMCBAL010','AMCBAL011','AMCBAL012','AMCBAL013','AMCBAL014','AMCBAL015','AMCBAL016','AMCBAL017','AMCBAL018','AMCBAL019','AMCBAL020'
          ,'AMCBAL021','AMCBAL022','AMCBAL023','AMCBAL024','AMCBAL025','AMCBAL026','AMCBAL027','AMCBAL028','AMCBAL029') THEN 1
       ELSE 0 END AS 'PaidFlag'             
 ,SCM1.NAME AS ServiceType
 ,CM.CODE AS DealerCode
 ,CM.CODE AS ASD_DealerCode
 ,SH.Importeddate
 ,CAST(SH.Vehicleinvoicedatetime AS DATE) AS Vehicleinvoicedatetime
 ,CAST(SH.Billeddatetime AS DATE) AS Billeddatetime
 ,SH.TOTALAMOUNT
 ,0 AS Delete_Flag
 ,101 AS Service_Retail_TypeIdentifier
 ,SH.Usagereading
 ,CASE
	WHEN SL.Type = 'Part' AND IG.ITEMGROUPTYPE = 'BAL Parts' 
	THEN 
	CASE 
		WHEN NOT EXISTS(
			SELECT 1
			FROM DM_CodeInclusionExclusion_Master EC
			WHERE EC.Code = IM.CODE
			AND EC.TypeFlag = 'Itemcode_001'
		)
		THEN  
		CASE 
			WHEN SL.CONTRACTTYPEID = 1
			THEN 'Warranty'
			WHEN SL.CONTRACTTYPEID = 8
			THEN 'PDI'
			WHEN SL.CONTRACTTYPEID = 170
			THEN '5 Year Warranty'
			WHEN SL.CONTRACTTYPEID = 198
			THEN 'Any Time Warranty'
			WHEN SL.CONTRACTTYPEID = 3
			THEN 'Special Sanction'
			WHEN SL.CONTRACTTYPEID IN (2,4,5,7,9,13,37,39,40,41,42,43,44,45,166,167,171,192,193)
			THEN 'Paid'
		END
		ELSE 'Others'
	END 
	ELSE 'Others'
END AS PartRepairType
 ,SLE.DefectCode AS DefectCode
--  ,SH.PDIOK AS PDIOk_Flag
--  ,SH.PDINOTOK AS PDINotOk_Flag
--  ,SH.PDINOWOK AS PDINowOk_Flag
-- ,SL.QtyInvoiced AS QtyInvoiced
 ,CASE
	WHEN SH.ISCLOSED = 0 AND (SH.READYFORBILLDATETIME IS NULL OR SH.READYFORBILLDATETIME IS NOT NULL) AND SH.BILLEDDATETIME IS NULL 
	THEN 'Open'
	WHEN SH.ISCLOSED = 1 AND SH.READYFORBILLDATETIME IS NOT NULL AND SH.BILLEDDATETIME IS NOT NULL 
	THEN 'Delivered/Closed'
  END AS JobCardStatus
,SH.FailureDate AS DateOfFailure
-- ,CTO.CutOffDate AS CutOff_date
FROM SERVICE_HEADER SH
LEFT JOIN SERVICE_LINE SL ON (SL.DOCID = SH.HEADERID AND SL.IMPORTEDDATE = (SELECT MAX(SL1.IMPORTEDDATE) FROM SERVICE_LINE SL1 WHERE SL1.ITEMID = SL.ITEMID AND SL.DOCID = SL1.DOCID))
INNER JOIN Bal_JC_2122 BCD ON BCD.LINEID=SL.LINEID
INNER JOIN SERVICE_CONTRACT_MASTER SCM1 ON SCM1.SERVICECONTRACTID=SH.CONTRACTTYPEID
INNER JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON IBM.Pk_ibid = SH.Ibid AND IBM.productiondate >= '2020-01-01'
LEFT JOIN SERVICE_LINE_EXT SLE ON SLE.LINEID = SL.LINEID 
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=SL.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
LEFT JOIN ITEM_MASTER IM ON IM.ITEMID=SL.ITEMID
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (1,8))
-- LEFT JOIN [dbo].[CDMS_FFR_CUTOFF_VIN_MODEL_PARTDEFECT] CTO ON (CTO.ModelID = SH.ModelID AND CTO.PartID = IM.ItemID AND CTO.DefectCode = SLE.DefectCode) -- Adding this join for cutoff date (8/28/2024)
WHERE CAST(SH.DOCDATE AS DATE) BETWEEN '2021-04-01' AND '2022-03-31'
AND CM.CODE NOT IN ('0000028428')
AND SH.IBID IS NOT NULL
--AND ibm.productiondate >= '2020-01-01'
AND SH.CANCELLATIONDATE IS NULL
AND SL.ISCLOSED<>0
AND SL.QTYALLOCATED<>0 AND SL.QTYRETURNED<SL.QTYALLOCATED)BASE
INNER JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON IBM.Pk_ibid = BASE.FK_Ibid

--------------------------For JC from '2022-04-01' Till '2023-11-07'
INSERT INTO ASM_MC_SERVICE_P3_STG

SELECT BASE.*
,Pretaxrevenue+Totaltax AS Posttaxrevenue
,null as repeat_type
,null as repeated_from_lined
,null as repeated_from_docname
,null as repeated_from_docdate
,null as Part_Repeat_Count
,null as CANCELLATIONDATE
,IBM.InvoiceDate AS InvoiceDate
,IBM.ProductionDate AS ProductionDate
,getdate() AS Refreshdate
FROM
(SELECT DISTINCT 
  SL.Type
 ,SH.CONTRACTTYPEID AS [FK_Contracttypeid]
 ,SL.CONTRACTTYPEID as [FK_PartContracttypeid]
 ,SL.LINEID AS Lineid
 ,SH.HEADERID AS [FK_Docid]
 ,SH.DOCNAME
 ,CAST(SH.Docdate AS DATE) AS Docdate
 ,SH.COMPANYID AS [FK_Companyid]
 ,SH.CONTACTID AS FK_Contactid
 ,SH.Isclosed
 ,SL.ITEMID AS [FK_Itemid]
 ,SH.IBID AS [FK_Ibid]
 ,SH.BRANCHID AS [FK_Branchid]
 ,SH.MODELID AS [FK_Modelid]
 ,SH.BU
 ,CM.COMPANYTYPE
 ,SL.TOTALTAX
 ,SH.Isrevisited 
 ,0 as Isrepeated 
 ,CASE WHEN SL.QtyAllocated = 0 Then (((SL.Qty - SL.QtyCancelled) * SL.Rate)   - SL.TradeDiscount ) 
       Else (((SL.QtyAllocated - SL.QtyReturned) * SL.Rate ) - SL.TradeDiscount ) END AS Pretaxrevenue
 ,CAST(IG.Itemgrouptype AS NVARCHAR(225)) AS Itemgrouptype
 ,CASE  WHEN SH.CONTRACTTYPEID IN (2,13,41,42,177,178,179,192,193) THEN 1
        WHEN SH.CONTRACTTYPEID NOT IN (38,39,40,8,168) AND IM.CODE IN ('BMPS0001','BMSL0029','AMCBAL001','AMCBAL002','AMCBAL003','AMCBAL004','AMCBAL005','AMCBAL006','AMCBAL007'
          ,'AMCBAL008','AMCBAL009','AMCBAL010','AMCBAL011','AMCBAL012','AMCBAL013','AMCBAL014','AMCBAL015','AMCBAL016','AMCBAL017','AMCBAL018','AMCBAL019','AMCBAL020'
          ,'AMCBAL021','AMCBAL022','AMCBAL023','AMCBAL024','AMCBAL025','AMCBAL026','AMCBAL027','AMCBAL028','AMCBAL029') THEN 1
       ELSE 0 END AS 'PaidFlag'             
 ,SCM1.NAME AS ServiceType
 ,CM.CODE AS DealerCode
 ,CM.CODE AS ASD_DealerCode
 ,SH.Importeddate
 ,CAST(SH.Vehicleinvoicedatetime AS DATE) AS Vehicleinvoicedatetime
 ,CAST(SH.Billeddatetime AS DATE) AS Billeddatetime
 ,SH.TOTALAMOUNT
 ,0 AS Delete_Flag
 ,101 AS Service_Retail_TypeIdentifier
 ,SH.Usagereading
 ,CASE
	WHEN SL.Type = 'Part' AND IG.ITEMGROUPTYPE = 'BAL Parts' 
	THEN 
	CASE 
		WHEN NOT EXISTS(
			SELECT 1
			FROM DM_CodeInclusionExclusion_Master EC  
			WHERE EC.Code = IM.CODE
			AND EC.TypeFlag = 'Itemcode_001'
		)     --7307 replacing excludecode by DM_CodeInclusionExclusion_Master
		THEN  
		CASE 
			WHEN SL.CONTRACTTYPEID = 1
			THEN 'Warranty'
			WHEN SL.CONTRACTTYPEID = 8
			THEN 'PDI'
			WHEN SL.CONTRACTTYPEID = 170
			THEN '5 Year Warranty'
			WHEN SL.CONTRACTTYPEID = 198
			THEN 'Any Time Warranty'
			WHEN SL.CONTRACTTYPEID = 3
			THEN 'Special Sanction'
			WHEN SL.CONTRACTTYPEID IN (2,4,5,7,9,13,37,39,40,41,42,43,44,45,166,167,171,192,193)
			THEN 'Paid'
		END
		ELSE 'Others'
	END 
	ELSE 'Others'
END AS PartRepairType
 ,SLE.DefectCode AS DefectCode
--  ,SH.PDIOK AS PDIOk_Flag
--  ,SH.PDINOTOK AS PDINotOk_Flag
--  ,SH.PDINOWOK AS PDINowOk_Flag
--  ,SL.QtyInvoiced AS QtyInvoiced
 ,CASE
	WHEN SH.ISCLOSED = 0 AND (SH.READYFORBILLDATETIME IS NULL OR SH.READYFORBILLDATETIME IS NOT NULL) AND SH.BILLEDDATETIME IS NULL 
	THEN 'Open'
	WHEN SH.ISCLOSED = 1 AND SH.READYFORBILLDATETIME IS NOT NULL AND SH.BILLEDDATETIME IS NOT NULL 
	THEN 'Delivered/Closed'
  END AS JobCardStatus
,SH.FailureDate AS DateOfFailure
-- ,CTO.CutOffDate AS CutOff_date
FROM SERVICE_HEADER SH
LEFT JOIN SERVICE_LINE SL ON (SL.DOCID = SH.HEADERID AND SL.IMPORTEDDATE = (SELECT MAX(SL1.IMPORTEDDATE) FROM SERVICE_LINE SL1 WHERE SL1.ITEMID = SL.ITEMID AND SL.DOCID = SL1.DOCID))
INNER JOIN BAL_Cequity_JCData_Updated BCD ON BCD.LINEID=SL.LINEID
INNER JOIN SERVICE_CONTRACT_MASTER SCM1 ON SCM1.SERVICECONTRACTID=SH.CONTRACTTYPEID
INNER JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON IBM.Pk_ibid = SH.Ibid AND  IBM.productiondate >= '2020-01-01'
LEFT JOIN SERVICE_LINE_EXT SLE ON SLE.LINEID = SL.LINEID  
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=SL.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
LEFT JOIN ITEM_MASTER IM ON IM.ITEMID=SL.ITEMID
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (1,8))
-- LEFT JOIN [dbo].[CDMS_FFR_CUTOFF_VIN_MODEL_PARTDEFECT] CTO ON (CTO.ModelID = SH.ModelID AND CTO.PartID = IM.ItemID AND CTO.DefectCode = SLE.DefectCode) -- Adding this join for cutoff date (8/28/2024)
WHERE CAST(SH.DOCDATE AS DATE) BETWEEN '2022-04-01' AND '2023-11-07'
AND CM.CODE NOT IN ('0000028428')
AND SH.IBID IS NOT NULL
--AND ibm.productiondate >= '2020-01-01'
AND SH.CANCELLATIONDATE IS NULL
AND SL.ISCLOSED<>0
AND SL.QTYALLOCATED<>0 AND SL.QTYRETURNED<SL.QTYALLOCATED)BASE
INNER JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON IBM.Pk_ibid = BASE.FK_Ibid

--For JC after 7th Nov
INSERT INTO ASM_MC_SERVICE_P3_STG

SELECT BASE.*
,Pretaxrevenue+Totaltax AS Posttaxrevenue
,null as repeat_type
,null as repeated_from_lined
,null as repeated_from_docname
,null as repeated_from_docdate
,null as Part_Repeat_Count
,null as CANCELLATIONDATE
,IBM.InvoiceDate AS InvoiceDate
,IBM.ProductionDate AS ProductionDate
,getdate() AS Refreshdate
FROM
(SELECT DISTINCT 
  SL.Type
 ,SH.CONTRACTTYPEID AS [FK_Contracttypeid]
 ,SL.CONTRACTTYPEID as [FK_PartContracttypeid]
 ,SL.LINEID AS Lineid
 ,SH.HEADERID AS [FK_Docid]
 ,SH.DOCNAME
 ,CAST(SH.Docdate AS DATE) AS Docdate
 ,SH.COMPANYID AS [FK_Companyid]
 ,SH.CONTACTID AS FK_Contactid
 ,SH.Isclosed
 ,SL.ITEMID AS [FK_Itemid]
 ,SH.IBID AS [FK_Ibid]
 ,SH.BRANCHID AS [FK_Branchid]
 ,SH.MODELID AS [FK_Modelid]
 ,SH.BU
 ,CM.COMPANYTYPE
 ,SL.TOTALTAX
 ,SH.Isrevisited 
 ,0 as Isrepeated 
 ,CASE WHEN SL.QtyAllocated = 0 Then (((SL.Qty - SL.QtyCancelled) * SL.Rate)   - SL.TradeDiscount ) 
       Else (((SL.QtyAllocated - SL.QtyReturned) * SL.Rate ) - SL.TradeDiscount ) END AS Pretaxrevenue
 ,CAST(IG.Itemgrouptype AS NVARCHAR(225)) AS Itemgrouptype
 ,CASE  WHEN SH.CONTRACTTYPEID IN (2,13,41,42,177,178,179,192,193) THEN 1
        WHEN SH.CONTRACTTYPEID NOT IN (38,39,40,8,168) AND IM.CODE IN ('BMPS0001','BMSL0029','AMCBAL001','AMCBAL002','AMCBAL003','AMCBAL004','AMCBAL005','AMCBAL006','AMCBAL007'
          ,'AMCBAL008','AMCBAL009','AMCBAL010','AMCBAL011','AMCBAL012','AMCBAL013','AMCBAL014','AMCBAL015','AMCBAL016','AMCBAL017','AMCBAL018','AMCBAL019','AMCBAL020'
          ,'AMCBAL021','AMCBAL022','AMCBAL023','AMCBAL024','AMCBAL025','AMCBAL026','AMCBAL027','AMCBAL028','AMCBAL029') THEN 1
       ELSE 0 END AS 'PaidFlag'             
 ,SCM1.NAME AS ServiceType
 ,CM.CODE AS DealerCode
 ,CM.CODE AS ASD_DealerCode
 ,SH.Importeddate
 ,CAST(SH.Vehicleinvoicedatetime AS DATE) AS Vehicleinvoicedatetime
 ,CAST(SH.Billeddatetime AS DATE) AS Billeddatetime
 ,SH.TOTALAMOUNT
 ,0 AS Delete_Flag
 ,101 AS Service_Retail_TypeIdentifier
 ,SH.Usagereading
 ,CASE
	WHEN SL.Type = 'Part' AND IG.ITEMGROUPTYPE = 'BAL Parts' 
	THEN 
	CASE 
		WHEN NOT EXISTS(
			SELECT 1
			FROM DM_CodeInclusionExclusion_Master EC
			WHERE EC.Code = IM.CODE
			AND EC.TypeFlag = 'Itemcode_001'
		)
		THEN  
		CASE 
			WHEN SL.CONTRACTTYPEID = 1
			THEN 'Warranty'
			WHEN SL.CONTRACTTYPEID = 8
			THEN 'PDI'
			WHEN SL.CONTRACTTYPEID = 170
			THEN '5 Year Warranty'
			WHEN SL.CONTRACTTYPEID = 198
			THEN 'Any Time Warranty'
			WHEN SL.CONTRACTTYPEID = 3
			THEN 'Special Sanction'
			WHEN SL.CONTRACTTYPEID IN (2,4,5,7,9,13,37,39,40,41,42,43,44,45,166,167,171,192,193)
			THEN 'Paid'
		END
		ELSE 'Others'
	END 
	ELSE 'Others'
END AS PartRepairType
 ,SLE.Defectcode AS DefectCode
--  ,SH.PDIOK AS PDIOk_Flag
--  ,SH.PDINOTOK AS PDINotOk_Flag
--  ,SH.PDINOWOK AS PDINowOk_Flag
--  ,SL.QtyInvoiced AS QtyInvoiced
 ,CASE
	WHEN SH.ISCLOSED = 0 AND (SH.READYFORBILLDATETIME IS NULL OR SH.READYFORBILLDATETIME IS NOT NULL) AND SH.BILLEDDATETIME IS NULL 
	THEN 'Open'
	WHEN SH.ISCLOSED = 1 AND SH.READYFORBILLDATETIME IS NOT NULL AND SH.BILLEDDATETIME IS NOT NULL 
	THEN 'Delivered/Closed'
  END AS JobCardStatus
,SH.FailureDate AS DateOfFailure
-- ,CTO.CutOffDate AS CutOff_date
FROM SERVICE_HEADER SH
LEFT JOIN SERVICE_LINE SL ON (SL.DOCID = SH.HEADERID AND SL.IMPORTEDDATE = (SELECT MAX(SL1.IMPORTEDDATE) FROM SERVICE_LINE SL1 WHERE SL1.ITEMID = SL.ITEMID AND SL.DOCID = SL1.DOCID))
INNER JOIN SERVICE_CONTRACT_MASTER SCM1 ON SCM1.SERVICECONTRACTID=SH.CONTRACTTYPEID
INNER JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON IBM.Pk_ibid = SH.Ibid AND IBM.productiondate >= '2020-01-01'
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=SL.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
LEFT JOIN ITEM_MASTER IM ON IM.ITEMID=SL.ITEMID
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (1,8))
LEFT JOIN SERVICE_LINE_EXT SLE ON SLE.LINEID = SL.LINEID  
-- LEFT JOIN [dbo].[CDMS_FFR_CUTOFF_VIN_MODEL_PARTDEFECT] CTO ON (CTO.ModelID = SH.ModelID AND CTO.PartID = IM.ItemID AND CTO.DefectCode = SLE.DefectCode) -- Adding this join for cutoff date (8/28/2024)
WHERE CAST(SH.DOCDATE AS DATE) > '2023-11-07'
AND CM.CODE NOT IN ('0000028428')
AND SH.IBID IS NOT NULL
-- AND ibm.productiondate >= '2020-01-01'
AND SH.CANCELLATIONDATE IS NULL
AND SL.ISCLOSED<>0
AND SL.QTYALLOCATED<>0 AND SL.QTYRETURNED<SL.QTYALLOCATED)BASE
INNER JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON IBM.Pk_ibid = BASE.FK_Ibid

------------------------------UPDATE DELETED LINEITEMS

SELECT DISTINCT SLD.LineID
INTO #DeletedLineID
FROM SERVICE_LINE_DELETED SLD
JOIN ASM_MC_SERVICE_P3_STG ASF ON ASF.LINEID=SLD.LINEID

UPDATE ASF
SET ASF.Delete_Flag=1
FROM ASM_MC_SERVICE_P3_STG ASF 
JOIN #DeletedLineID DLI ON DLI.LINEID=ASF.LINEID
drop table #DeletedLineID


----------------------------UPDATE ASD DEALERCODE MAPPING

SELECT * INTO #ServiceDealerMapping FROM
(SELECT DISTINCT ZF_ASC ASD_DEALERCODE,DEALER_CODE DEALERCODE
FROM SAP_ZSD_ASC_DETAIL
WHERE SER_STATUS = 'OPERATIONAL')T

UPDATE B
SET B.Dealercode=A.DEALERCODE
FROM ASM_MC_SERVICE_P3_STG B
INNER JOIN #ServiceDealerMapping A ON B.ASD_DealerCode=A.ASD_DEALERCODE;
drop table #ServiceDealerMapping;

------------------------------------------------------------------------------------------
--MC STG Repeat--

WITH PartitionedData AS (
   SELECT 
       STG.FK_Ibid,
       STG.FK_Itemid,
       STG.PartRepairType,
       STG.FK_docid,
       ROW_NUMBER() OVER (PARTITION BY STG.FK_Ibid, STG.FK_Itemid, STG.PartRepairType ORDER BY STG.FK_docid) AS RowNum
   FROM 
       ASM_MC_SERVICE_P3_STG STG
LEFT JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON IBM.PK_Ibid = STG.FK_Ibid
WHERE DATEDIFF(YEAR, STG.DOCDATE, IBM.ProductionDate) <= 5 AND STG.TYPE = 'Part'
)
 
UPDATE OriginalData
SET Part_Repeat_Count = CASE
   WHEN PartitionedData.RowNum = 1 THEN 0
   ELSE 1
END
FROM 
   ASM_MC_SERVICE_P3_STG AS OriginalData
JOIN 
   PartitionedData
ON 
   OriginalData.FK_docid = PartitionedData.FK_docid and
OriginalData.FK_ibid = PartitionedData.FK_ibid and
OriginalData.FK_itemid = PartitionedData.FK_itemid;


PRINT('STG DATA LOADED')

----------------------FACT DML---------------------------------

/*
PRINT('LOADING DATA FROM SOURCE TABLE')

DELETE FROM ASM_MC_SERVICE_P3_FACT WHERE Service_Retail_TypeIdentifier = 101
INSERT INTO ASM_MC_SERVICE_P3_FACT(Type,
FK_Contracttypeid,
FK_PartContracttypeid,
Lineid,
FK_Docid,
DOCNAME,
Docdate,
FK_Companyid,
FK_Contactid,
FK_Itemid,
FK_Ibid,
FK_Branchid,
FK_Modelid,
COMPANYTYPE,
Isrepeated,
Pretaxrevenue,
Itemgrouptype,
ServiceType,
DealerCode,
ASD_DealerCode,
Importeddate,
Billeddatetime,
Service_Retail_TypeIdentifier,
Usagereading,
PartRepairType,
DefectCode,
-- PDIOk_Flag,
-- PDINotOk_Flag,
-- PDINowOk_Flag,
-- QtyInvoiced,
JobCardStatus,
DateOfFailure,
Posttaxrevenue,
Refresh_Date,
Part_Repeat_Count,
-- CutOff_Date,
InvoiceDate,
ProductionDate
)

SELECT Type,
FK_Contracttypeid,
FK_PartContracttypeid,
Lineid,
FK_Docid,
DOCNAME,
Docdate,
FK_Companyid,
FK_Contactid,
FK_Itemid,
FK_Ibid,
FK_Branchid,
FK_Modelid,
COMPANYTYPE,
Isrepeated,
Pretaxrevenue,
Itemgrouptype,
ServiceType,
DealerCode,
ASD_DealerCode,
Importeddate,
Billeddatetime,
Service_Retail_TypeIdentifier,
Usagereading,
PartRepairType,
DefectCode,
-- PDIOk_Flag,
-- PDINotOk_Flag,
-- PDINowOk_Flag,
-- QtyInvoiced,
JobCardStatus,
DateOfFailure,
Posttaxrevenue,
GETDATE() AS Refresh_Date,
Part_Repeat_Count,
-- CutOff_Date,
InvoiceDate,
ProductionDate

FROM ASM_MC_SERVICE_P3_STG ARS
WHERE ARS.DELETE_FLAG<>1

PRINT('FACT DATA FROM BASE TABLE')
*/
END
GO