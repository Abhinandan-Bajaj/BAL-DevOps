/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			    */
/*--------------------------------------------------------------------------------------------------*/
/*	2024-09-10 	|	Ashwini Ahire		| ASM_MC_SERVICE_PARTS_FAILURE_REPORT        */
/*	                                                                                            */                                                         
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_MC_SERVICE_PARTS_FAILURE_REPORT] AS
BEGIN

PRINT('LOADING DATA FROM Source TABLE')

---------------------------------------------------------
TRUNCATE TABLE ASM_MC_SERVICE_PARTS_FAILURE_REPORT

INSERT INTO ASM_MC_SERVICE_PARTS_FAILURE_REPORT
SELECT DISTINCT FCT.FK_Itemid AS ItemID 
		,FCT.DealerCode AS DealerCode 
		,FCT.Docdate AS Docdate
        ,FCT.FK_Modelid AS ModelID
        ,FCT.Part_Repeat_Count AS Repeat_Part_Count 
        ,FCT.DefectCode AS DefectCode
        ,FCT.FK_Ibid AS Ibid
        ,IBM.Chassis AS Chassis_Number
        ,FCT.DOCNAME AS DOCNAME
		,IBM.ProductionDate as ProductionDate
        ,FCT.Usagereading AS Usagereading 
        ,FCT.PartRepairType AS PartRepairType
        ,CASE 
			WHEN substring(IBM.Chassis,11,1) = 'C' then 'Chakan'
			WHEN substring(IBM.Chassis,11,1) = 'P' then 'Pant Nagar Plant 1'
			WHEN substring(IBM.Chassis,11,1) = 'R' then 'Pant Nagar Plant 2'
			WHEN substring(IBM.Chassis,11,1) = 'W' then 'Waluj'
			ELSE NULL
		END AS PLANT
        ,IBM.InvoiceDate as DATEOFSALE
        ,VM.VendorName As VendorName
        ,FORMAT(CTO.CutOffDate,'yyyy-MM-dd') AS CutOff_Date,
		 CASE WHEN FCT.DOCDATE <= CTO.CutOffDate THEN FORMAT(CTO.CutOffDate,'yyyy-MM-dd') 
			  ELSE NULL
		 END AS PreCutOff_date 
        ,CASE WHEN FCT.DOCDATE > CTO.CutOffDate THEN FORMAT(CTO.CutOffDate,'yyyy-MM-dd')
			  ELSE NULL
		 END AS PostCutOff_date  
        ,SCHD.FFR_Number AS FFR_Number
		,FCT.Part_Repeat_Count
		,FCT.FK_PartContracttypeid
		,CPM.Name AS DefectDescription

FROM [dbo].[ASM_MC_SERVICE_P3_FACT] FCT
LEFT JOIN [dbo].[ASM_MC_SERVICE_SPARE_CLAIM_HEADER_DIM] SCHD ON (SCHD.FFRAGAINSTDOCID = FCT.FK_DOCID AND SCHD.ItemID = FCT.FK_Itemid AND SCHD.MODELID = FCT.FK_Modelid AND SCHD.IBID = FCT.FK_Ibid)
INNER JOIN [dbo].[ASM_SERVICE_INSTALLBASE_MASTER_DIM] IBM ON PK_Ibid = fct.FK_Ibid -- NEED TO CHECK THIS JOINING CONDITION
INNER JOIN [dbo].[ASM_SERVICE_ITEM_MASTER_DIM] IM ON IM.Itemid = fct.FK_Itemid -- NEED TO CHECK THIS JOINING CONDITION
LEFT JOIN [dbo].[ASM_SERVICE_VENDOR_MASTER_DIM] VM ON (VM.ItemCode = IM.ItemCode AND VM.CHASSIS = IBM.CHASSIS)
LEFT JOIN [dbo].[CDMS_FFR_CUTOFF_VIN_MODEL_PARTDEFECT] CTO ON (CTO.ModelID = FCT.FK_Modelid and CTO.PartID = FCT.FK_Itemid and CTO.DefectCode = FCT.DefectCode) --ADDED NEWLY ON 26/0824 FOR PARTS FAILURE MC DETAILED REPORT
LEFT JOIN [dbo].[COMPLAINT_MASTER] CPM ON CPM.Code = FCT.DefectCode
WHERE FCT.Type = 'Part' 
AND FCT.PartRepairType IN ('Warranty', 'PDI', '5 Year Warranty', 'Any Time Warranty', 
'Special Sanction', 'Paid')

END
GO