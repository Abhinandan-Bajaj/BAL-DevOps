SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_PB_SERVICE_PARTS_FAILURE_REPORT] AS

/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION	*/
/*--------------------------------------------------------------------------------------------------*/
/*	2025-01-07 	|	Ashwini Ahire		    |ASM_PB_SERVICE_PARTS_FAILURE_REPORT*/                 
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/


BEGIN

PRINT('LOADING DATA FROM Source TABLE')

---------------------------------------------------------

TRUNCATE TABLE ASM_PB_SERVICE_PARTS_FAILURE_REPORT

INSERT INTO ASM_PB_SERVICE_PARTS_FAILURE_REPORT
SELECT DISTINCT STG.FK_Itemid AS ItemID 
		,STG.DealerCode AS DealerCode 
		,STG.Docdate AS Docdate
        ,STG.FK_Modelid AS ModelID
        ,STG.Part_Repeat_Count AS Repeat_Part_Count 
        ,STG.DefectCode AS DefectCode
        ,STG.FK_Ibid AS Ibid
        ,IBM.Chassis AS Chassis_Number
        ,STG.DOCNAME AS DOCNAME
		,IBM.ProductionDate as ProductionDate
        ,STG.Usagereading AS Usagereading 
        ,STG.PartRepairType AS PartRepairType
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
		 CASE WHEN STG.DOCDATE <= CTO.CutOffDate THEN FORMAT(CTO.CutOffDate,'yyyy-MM-dd') 
			  ELSE NULL
		 END AS PreCutOff_date 
        ,CASE WHEN STG.DOCDATE > CTO.CutOffDate THEN FORMAT(CTO.CutOffDate,'yyyy-MM-dd')
			  ELSE NULL
		 END AS PostCutOff_date  
        ,SCHD.FFR_Number AS FFR_Number
		,STG.Part_Repeat_Count
		,STG.FK_PartContracttypeid
		,CPM.Name AS DefectDescription

FROM [dbo].ASM_PB_SERVICE_STG STG
LEFT JOIN [dbo].[ASM_PB_SERVICE_SPARE_CLAIM_HEADER_DIM] SCHD ON (SCHD.FFRAGAINSTDOCID = STG.FK_DOCID AND SCHD.ItemID = STG.FK_Itemid AND SCHD.MODELID = STG.FK_Modelid AND SCHD.IBID = STG.FK_Ibid)
INNER JOIN [dbo].[ASM_SERVICE_INSTALLBASE_MASTER_DIM] IBM ON PK_Ibid = STG.FK_Ibid 
INNER JOIN [dbo].[ASM_SERVICE_ITEM_MASTER_DIM] IM ON IM.Itemid = STG.FK_Itemid 
LEFT JOIN [dbo].[ASM_SERVICE_VENDOR_MASTER_DIM] VM ON (VM.ItemCode = IM.ItemCode AND VM.CHASSIS = IBM.CHASSIS)
LEFT JOIN [dbo].[CDMS_FFR_CUTOFF_VIN_MODEL_PARTDEFECT] CTO ON (CTO.ModelID = STG.FK_Modelid and CTO.PartID = STG.FK_Itemid and CTO.DefectCode = STG.DefectCode) 
LEFT JOIN [dbo].[COMPLAINT_MASTER] CPM ON CPM.Code = STG.DefectCode
WHERE STG.Type = 'Part' 
AND STG.PartRepairType IN ('Warranty', 'PDI', '5 Year Warranty', 'Any Time Warranty', 
'Special Sanction', 'Paid')
and STG.DELETE_FLAG<>1
and STG.CANCELLATIONDATE is null

END
GO