/*******************************************HISTORY*********************************************************************************************/
/*---------------------------------------------------------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			                                                                       */
/*---------------------------------------------------------------------------------------------------------------------------------------------*/
/*	2024-09-06 	|	Ashwini Ahire		| ASM_CV_SERVICE_SPARE_CLAIM_HEADER_REPORT_DIM new report table added                                   */
/*      2024-11-28      |       Ashwini Ahire           | updated the new defectcode in where clause as well as updated logic of parent and child */
/*      2024-11-28      |        Aniket Mahulikar           | Updated logic of automated and manual ffr as shared by BU                            */
/*---------------------------------------------------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY*********************************************************************************************/


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_CV_SERVICE_FFR_AFR_REPORT_FULLOAD_P3] AS
BEGIN

PRINT('LOADING DATA FROM Source TABLE')

---------------------------------------------------------
TRUNCATE TABLE [ASM_CV_SERVICE_SPARE_CLAIM_HEADER_REPORT_DIM] 

INSERT INTO [ASM_CV_SERVICE_SPARE_CLAIM_HEADER_REPORT_DIM](
[HeaderID] 
,[FFR_ParentID]
,[FFR_Number] 
,[Creation_Date] 
,[FFR_Identification]
,[FFR_Status] 
,[Status_FFR_Derived] 
,[AFR_Number] 
,[AFR_Status]
,[Status_AFR_Derived] 
,[FFR_SubmittedDate]
,[AFR_SubmittedDate]
,[ASM_Name]
,[DefectCode]
,[DefectDescription]
,[ITEMID]
,[DealerCode]
,[BranchId]
,[ModelId]
,[BU]
,[IBID]
,[ContractTypeID]
,[PartContractTypeID]
,[DateOfSale]
,[DateOfFailure]
,[ProblemDescription]
,[Submit]
,[ReportDate]
,[EngineNo]
,[RepairDate]
,[KMReading]
,[PerformanceCode]
,[PerformanceDescription]
,[GroupCode]
,[GroupName]
,[CheckListFilled]
,[Source]
,[ParentAFRNO]
,[ParentAFRCreationDate]
,[AFR_Identification]
,[ImportedDate] 
,[Refresh_Date]
)
SELECT DISTINCT SCH.HEADERID AS HeaderID
		,SCHE.FFRParentID  AS FFR_ParentID
        ,SCH.DOCNAME AS FFR_Number
        ,SCH.CREATIONDATE AS Creation_Date
        ,CASE 
			WHEN SCHE.FFRParentID != 0 THEN 'Child'
			ELSE 'Parent'
		 END AS FFR_Identification     
        ,SCHE.FFR_STATUS AS FFR_STATUS
        ,CASE
            WHEN SCHE.FFR_Status = 'Open' OR FFR_Status IS NULL THEN 'Open'
            WHEN SCHE.FFR_Status IN ('Closed', 'Closed Due To System Closure', 'Closed Lapsed By Agent', 'Lapsed') THEN 'Lapsed'
            WHEN SCHE.FFR_Status IN ('Accepted By ASM', 'Closed By ASM', 'Deleted By ASM', 'GroupedByASM', 'Reopened By ASM', 'Reverted By ASM', 'Submitted To ASM','Submitted To PSG') THEN 'Submitted' -- As discussed with BU on 20 Aug added 'Submitted To PSG' in FFR Status grouping
            WHEN CAHE.AFR_Status IN ('AFR Closed By ASM', 'AFR Deleted By ASM') THEN 'Submitted'
        END AS Status_FFR_Derived
        ,CAHE.AFR_DOCNAME AS AFR_Number
        ,CAHE.AFR_STATUS AS AFR_Status
        ,CASE
            WHEN CAHE.AFR_Status = 'Open' THEN 'Open'
            WHEN CAHE.AFR_Status IN ('AFR Closed due to Time Lapsed', 'Closed Due To System Closure') THEN 'Lapsed'
            WHEN CAHE.AFR_Status IN ('Resent By PSG', 'Resubmitted To PSG', 'Submitted To PSG', 'Accepted By PSG', 'Closed By CQA', 'AFR Closed By PSG', 'Grouped By PSG') THEN 'Submitted'
            WHEN SCHE.FFR_Status IN ('Submitted To CQA', 'Submitted To PSG', 'Closed By CQA', 'Closed By PSG', 'Accepted By PSG', 'Reopened By PSG', 'Resubmitted To PSG') THEN 'Submitted'
        END AS Status_AFR_Derived
        ,SCHE.SUBMISSIONDATE AS FFR_SubmittedDate
        ,CAHE.AFR_SUBMISSIONDATE  AS AFR_SubmittedDate
        ,CAHE.AFR_ASMNAME AS ASM_Name
        ,CPM.CODE AS DefectCode
        ,CPM.NAME AS DefectDescription
        ,SCL.ITEMID AS ITEMID
        ,ADM.DealerCode AS DealerCode
        ,SCH.BRANCHID AS BranchId
        ,SCLE.MODELID AS ModelId
        ,CASE
            WHEN CM.CompanyType = 7 THEN 'CV'
        END AS BU
        ,SCL.IBID AS IBID
        ,SCH.ContractTypeID AS ContractTypeID
        ,SCL.ContractTypeID AS PartContractTypeID
-- New columns added for FFR AFR Report 29/08/2024
		,SCLE.DateOFSale AS DateOfSale
		,SCLE.DateOFFailure AS DateOfFailure
		,SCLE.CustomerComplaint1 AS ProblemDescription
		,CASE
			 WHEN  SCHE.ISSUBMIT = '1' THEN 'Checked'
			 WHEN (SCHE.ISSUBMIT = '0' OR SCHE.ISSUBMIT IS NULL) THEN 'Unchecked'
		 END AS Submit
		,SCH.DOCDATE AS ReportDate
		,SCLE.ENGINENO AS EngineNo
		,SCL.SALEDOCDATE AS RepairDate
		,SCL.USAGEREADING AS KMReading
		,CPM1.CODE AS PerformanceCode
		,CPM1.NAME AS PerformanceDescription
		,SCHE.GroupCode
		,SCHE.GroupName
		,SCLE.CHECKSHEETFILLED AS CheckListFilled
		--,CASE
		--	 WHEN CAHE.ISINCLUDEAGENTFR = '1' AND FORMAT(CAHE.AFR_DOCDATE, 'yyyy-MM-dd') > '2022-09-01' THEN 'Automated'
		--	 ELSE 'Manual'
		-- END AS Source -- Old Logic changed on 22/11/24 as per new logic discussed with pawan from CDMS team
		,CASE 
			WHEN SCHE.iscreatedbyagent = 1 THEN 'Automated' 
			ELSE 'Manual'
		 END AS Source 
		,CAHE.AFR_DOCNAME as ParentAFRNO 
		,CAHE.AFR_DOCDATE as ParentAFRCreationDate -- Need to check whether this is AFR doc date or afr submission date
		,CASE 
			 WHEN (CAHE.CDMSUNIQUEID IS NOT NULL OR CAHE.CDMSUNIQUEID != '') THEN 'PARENT'
			 ELSE 'CHILD' 
		 END as AFR_Identification
		,SCH.ImportedDate AS ImportedDate
        ,getdate() AS Refresh_Date
		
FROM [dbo].[SPARE_CLAIM_HEADER] SCH
LEFT JOIN [dbo].[SPARE_CLAIM_HEADER_EXT] SCHE ON SCH.HEADERID = SCHE.HEADERID
LEFT JOIN [dbo].[SPARE_CLAIM_LINE] SCL ON SCL.DOCID = SCH.HEADERID
LEFT JOIN [dbo].[SPARE_CLAIM_LINE_EXT] SCLE ON SCLE.HEADERID = SCL.CDMSUniqueID 
LEFT JOIN [dbo].[CDMS_AFRHEADER_EXPORT] CAHE ON CAHE.FFRHeaderID = SCH.HEADERID
LEFT JOIN [dbo].[CDMS_IRHEADER_EXPORT] CIHE ON CIHE.AFRHeaderID = CAHE.CDMSUniqueID 
-- LEFT JOIN [dbo].[ASM_SERVICE_DEFECT_MASTER_DIM] ASDM ON SCLE.Defect = ASDM.DefectCODE -- As suggested by CDMS team to use SCLE.DefectCode & SCLE.DefectName
INNER JOIN [dbo].[ASM_SERVICE_ITEM_MASTER_DIM] IM ON IM.ITEMID = SCL.ITEMID 
LEFT JOIN [dbo].[COMPLAINT_MASTER] CPM ON CPM.COMPALINTID = SCLE.DEFECTCODE
LEFT JOIN [dbo].[COMPLAINT_MASTER] CPM1 ON (CPM1.COMPALINTID = SCLE.PERFORMANCEID) -- Added newly 29/08/2024 shared by CDMS team (Pawan & Aashay) to get Performance Code & Description
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SCH.COMPANYID AND CM.IMPORTEDDATE = 
(SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID))
INNER JOIN [dbo].[ASM_SERVICE_DEALER_MASTER_DIM] ADM ON ADM.DealerCode = CM.CODE
WHERE CM.Companytype = 7 AND SCH.DOCTYPE = 452 AND SCL.PartGroup in ('BAL Parts') 
AND CPM.CODE NOT IN ('555','556') AND CPM.CODE is not null


---------Update Query For Child FFR-----------------------

SELECT * INTO #ChildFFRMapping FROM
(SELECT DISTINCT FFRHeaderID AS FFRHeaderID, AFR_Docname AS AFR_Number, AFR_Status AS AFR_Status, AFR_SUBMISSIONDATE AS AFR_SubmittedDate, AFR_ASMNAME AS ASM_Name
FROM CDMS_AFRHEADER_EXPORT)T

UPDATE SCHR
SET SCHR.AFR_Number = B.AFR_Number, SCHR.AFR_Status = B.AFR_Status, SCHR.AFR_SubmittedDate = B.AFR_SubmittedDate, SCHR.ASM_Name = B.ASM_Name
from ASM_CV_SERVICE_SPARE_CLAIM_HEADER_REPORT_DIM SCHR
left join #ChildFFRMapping B ON B.FFRHeaderID = SCHR.FFR_ParentID WHERE SCHR.FFR_Identification = 'Child'
drop table #ChildFFRMapping

END
GO
