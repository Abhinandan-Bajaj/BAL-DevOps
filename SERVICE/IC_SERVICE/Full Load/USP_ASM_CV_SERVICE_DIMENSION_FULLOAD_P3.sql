/*******************************************HISTORY*********************************************************************************************/
/*---------------------------------------------------------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			                                               */
/*---------------------------------------------------------------------------------------------------------------------------------------------*/
/*	2024-09-06  	|	Ashwini Ahire		| ASM_CV_SERVICE_SPARE_CLAIM_HEADER_DIM  updated code                                  */
/*      2024-09-06      |       Ashwini Ahire           | ASM_CV_SERVICE_COMPLAINT_MASTER_DIM   updated code                                   */
/*      2024-11-28      |       Aniket Mahulikar        | Updated logic of automated and manual ffr as shared by BU and Parent and child in spare dim*/
/*      2025-02-03      |       Dewang Makani           | New DIM table Created for ELF*/
/*---------------------------------------------------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY*********************************************************************************************/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_CV_SERVICE_DIMENSION_FULLOAD_P3] AS
BEGIN

PRINT('LOADING DATA FROM Source TABLE')
--*****************************************************************
--1. Load Spare Claim Header DIM for CV

TRUNCATE TABLE [ASM_CV_SERVICE_SPARE_CLAIM_HEADER_DIM] 

INSERT INTO [ASM_CV_SERVICE_SPARE_CLAIM_HEADER_DIM](
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
            WHEN SCHE.FFR_Status IN ('Accepted By ASM', 'Closed By ASM', 'Deleted By ASM', 'GroupedByASM', 'Reopened By ASM', 'Reverted By ASM', 'Submitted To ASM','Submitted To PSG') THEN 'Submitted'
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
		,CASE 
			WHEN SCHE.iscreatedbyagent = 1 THEN 'Automated' 
			ELSE 'Manual'
		 END AS Source 
		,CAHE.AFR_DOCNAME as ParentAFRNO 
		,CAHE.AFR_DOCDATE as ParentAFRCreationDate 
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
INNER JOIN [dbo].[ASM_SERVICE_ITEM_MASTER_DIM] IM ON IM.ITEMID = SCL.ITEMID 
LEFT JOIN [dbo].[COMPLAINT_MASTER] CPM ON CPM.COMPALINTID = SCLE.DEFECTCODE
LEFT JOIN [dbo].[COMPLAINT_MASTER] CPM1 ON (CPM1.COMPALINTID = SCLE.PERFORMANCEID)
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SCH.COMPANYID AND CM.IMPORTEDDATE = 
(SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID))
INNER JOIN [dbo].[ASM_SERVICE_DEALER_MASTER_DIM] ADM ON ADM.DealerCode = CM.CODE
WHERE CM.Companytype = 7 AND SCH.DOCTYPE = 452 AND SCL.PartGroup in ('BAL Parts') 
AND CPM.CODE NOT IN ('555','556') AND CPM.CODE is not null

--------Update for Child FFR-AFR Mapping---------------------------------

SELECT * INTO #ChildFFRMapping FROM
(SELECT DISTINCT FFRHeaderID AS FFRHeaderID, AFR_Docname AS AFR_Number, AFR_Status AS AFR_Status,
AFR_SUBMISSIONDATE AS AFR_SubmittedDate, AFR_ASMNAME AS ASM_Name
FROM CDMS_AFRHEADER_EXPORT)T

UPDATE SCH
SET SCH.AFR_Number = B.AFR_Number, SCH.AFR_Status = B.AFR_Status, SCH.AFR_SubmittedDate = B.AFR_SubmittedDate, 
SCH.ASM_Name = B.ASM_Name

from ASM_CV_SERVICE_SPARE_CLAIM_HEADER_DIM SCH
left join #ChildFFRMapping B ON B.FFRHeaderID = SCH.FFR_ParentID
WHERE SCH.FFR_Identification = 'Child'

drop table #ChildFFRMapping

PRINT('ASM_CV_SERVICE_SPARE_CLAIM_HEADER_DIM TABLE LOADED')

--*****************************************************************
--2. Load Complain Master DIM for CV

TRUNCATE TABLE ASM_CV_SERVICE_COMPLAINT_MASTER_DIM
INSERT INTO ASM_CV_SERVICE_COMPLAINT_MASTER_DIM(
[ISRDocid]
,[Complaint_Number]
,[DocType]
,[DocStatus]
,[Agent]
,[Activity]
,[Call_Date]
,[CallType]
,[Inbound_Outbound_Complaints]
,[Complaints_Closed_Days]
,[Response_Time_Hrs]
,[Status_Date]
,[Department]
,[RCA_Status]
,[DealerCode]
,[BranchId]
,[ModelID]
,[BU]
,[ImportedDate]
,[Refresh_Date]
,[IBID]
,[ContactID]
,[Opened_Since]
,[Vehicle_Number]
,[DocumentStatus]
)
SELECT DISTINCT CR.ISRDOCID AS ISRDocid
        ,CR.DOCNAME AS Complaint_Number
        ,CR.DocType AS DocType
        ,CR.DocStatus AS DocStatus
        ,CR.Agent AS Agent
        ,CR.Activity AS Activity
        ,CR.CallDate as Call_Date
        ,CR.[ModeOfContact(CallType)] AS CallType,
        CASE
            WHEN CR.CallDate >= '2023-06-01'
            THEN 
                CASE 
                    WHEN CR.[ModeOfContact(CallType)] NOT LIKE '%Service Feedback%' THEN 'Inbound' -- check distinct call types present in cr 
                    ELSE 'Outbound'
                END 
            ELSE 
                CASE 
                    WHEN CR.Agent LIKE '%bali2%' THEN 'Inbound'
                    ELSE 'Outbound'
                END
        END AS Inbound_Outbound_Complaints
		,NULL AS Complaints_Closed_Days 
        ,NULL AS Response_Time_Hrs 
        ,CR.StatusDate AS Status_Date
        ,CASE 
            
            WHEN CR.Department = 'Sales' THEN 'Sales'
            ELSE 'Service / Spares'
        END AS Department
		,CRCA.RCAStatus AS RCA_Status
        ,CIH.DEALERCODE AS DealerCode
        ,CIH.Branchid AS BranchId
        ,CIH.MODELID AS ModelID
        ,CASE 
                WHEN CIH.ProductType IN ('Commercial Vehicle') THEN 'IC'
        END AS BU
	,CR.ImportedDate As ImportedDate
        ,getdate() AS Refresh_Date
	,CIH.IBID AS IBID
	,CIH.CUSTOMERID AS ContactID
	,CR.OPENEDSINCE AS Opened_Since
	,CIH.REGISTRATIONNUMBER AS Vehicle_Number
	,CIH.DocumentStatus AS DocumentStatus
FROM [dbo].[CALL_REGISTER] CR
LEFT JOIN [dbo].[CDMS_ISSUE_HEADER] CIH ON CIH.ISSUEHEADERID = CR.ISRDOCID 
LEFT JOIN [dbo].[CDMS_ROOT_CAUSE_ANALYSIS] CRCA ON CRCA.ISRDocid = CR.ISRDocid
WHERE CR.DOCTYPE = 'Complaint' AND CR.CALLDATE >= '2020-01-01' AND CIH.Producttype = 'Commercial Vehicle'



----------------------Update Response Time in Hrs ------------------------------
SELECT
    CIR.ISSUEHEADERID,
    CIR.Activity,
    CIR.STATUSDate
INTO #Responded_hours
FROM [dbo].[ASM_CV_SERVICE_COMPLAINT_MASTER_DIM] CR
LEFT JOIN [dbo].[CDMS_ISSUE_RESOLUTION] CIR ON CR.ISRDocid = CIR.ISSUEHEADERID

SELECT
    ISSUEHEADERID,
    MIN(CASE WHEN Activity = 'Fresh' THEN STATUSDATE END) AS FreshDate,
    MIN(CASE WHEN Activity = 'Contacted' THEN STATUSDATE END) AS ContactedDate,
    DATEDIFF(SECOND,
             MIN(CASE WHEN Activity = 'Fresh' THEN STATUSDATE END),
             MIN(CASE WHEN Activity = 'Contacted' THEN STATUSDATE END)) AS DifferenceInSeconds,
    CAST(ROUND(DATEDIFF(SECOND,
             MIN(CASE WHEN Activity = 'Fresh' THEN STATUSDATE END),
             MIN(CASE WHEN Activity = 'Contacted' THEN STATUSDATE END)) / 3600.00, 2) AS VARCHAR(20)) AS Response_Time_Hrs
INTO #Responded_hrs_final
FROM #Responded_hours
WHERE Activity IN ('Fresh', 'Contacted')
GROUP BY ISSUEHEADERID;

UPDATE ACM
SET ACM.Response_Time_Hrs = RDF.Response_Time_Hrs
FROM ASM_CV_SERVICE_COMPLAINT_MASTER_DIM ACM
JOIN #Responded_hrs_final RDF ON ACM.IsrDocid = RDF.ISSUEHEADERID;

DROP TABLE #Responded_hours;
DROP TABLE #Responded_hrs_final;

--------------------------------Update the Opened-Since for Open and Closed complaints in days---------------

-- Step 1: Create a temporary table with detailed calculations
SELECT 
    CR.ISRDocid,
    CR.Docname AS [Complaint_Number],
    CIH.DocumentStatus,
    CASE 
        WHEN CIH.DocumentStatus = 'Closed' 
          THEN DATEDIFF(DAY, CIH.IssueDocDate,(SELECT MAX(CIR.StatusDate) 
                FROM [dbo].[CDMS_ISSUE_RESOLUTION] CIR 
                WHERE CIR.ISSUEHEADERID = CIH.ISSUEHEADERID))  -- Ensure correct date order
        ELSE DATEDIFF(DAY, CIH.IssueDocDate, GETDATE())  -- This is correct
    END AS Opened_Since
INTO #TEMP
FROM [dbo].CALL_REGISTER CR
LEFT JOIN [dbo].CDMS_ISSUE_HEADER CIH ON CIH.ISSUEHEADERID = CR.ISRDOCID 
LEFT JOIN [dbo].[CDMS_ISSUE_RESOLUTION] CIR ON CIH.ISSUEHEADERID = CIR.ISSUEHEADERID 
WHERE CR.DOCTYPE = 'Complaint' 
    AND CR.CALLDATE >= '2020-01-01' 
    AND CIH.Producttype = 'Commercial Vehicle';

-- Step 2: Update the main table
UPDATE TT
SET TT.Opened_Since = TM.Opened_Since
FROM ASM_CV_SERVICE_COMPLAINT_MASTER_DIM TT
JOIN #TEMP TM ON TT.IsrDocid = TM.IsrDocid AND TT.Complaint_Number = TM.Complaint_Number;

-- Clean up temporary table
DROP TABLE #TEMP;

--------------------------------Update the Resolved complaints in days---------------

SELECT
    CIR.ISSUEHEADERID,
	CIR.Activity,
	CIR.STATUSDATE
INTO #Resolved_days
FROM [dbo].[ASM_CV_SERVICE_COMPLAINT_MASTER_DIM] CR
LEFT JOIN [dbo].[CDMS_ISSUE_RESOLUTION] CIR ON CR.ISRDocid = CIR.ISSUEHEADERID

SELECT 
    ISSUEHEADERID,
    MIN(CASE WHEN Activity = 'Fresh' THEN STATUSDATE END) AS FreshDate,
    MIN(CASE WHEN Activity = 'Resolved' THEN STATUSDATE END) AS ResolvedDate,
    DATEDIFF(DAY, 
             MIN(CASE WHEN Activity = 'Fresh' THEN STATUSDATE END),
             MIN(CASE WHEN Activity = 'Resolved' THEN STATUSDATE END)) AS Resolved_Days
INTO #Resolved_days_final
FROM #Resolved_days
WHERE Activity IN ('Fresh', 'Resolved')
GROUP BY ISSUEHEADERID;

UPDATE ACM
SET ACM.Complaints_Closed_Days = RHF.Resolved_Days
FROM ASM_CV_SERVICE_COMPLAINT_MASTER_DIM ACM
JOIN  #Resolved_days_final RHF ON ACM.IsrDocid = RHF.ISSUEHEADERID;

drop table #Resolved_days
drop table #Resolved_days_final

PRINT('ASM_CV_SERVICE_COMPLAINT_MASTER_DIMTABLE LOADED')

--*****************************************************************
--2. Load ELF AGGR DIM for CV for ELF Screen

TRUNCATE TABLE [ASM_CV_SERVICE_ELF_AGGR_DIM]
 
INSERT INTO [ASM_CV_SERVICE_ELF_AGGR_DIM] (
 
	 [DateOfFailure]
	,[IBID]
	,[ChassisNo]
	,[ModelID]
	,[ItemID]
	,[KMReading]
	,[ProductionDate]
	--,[BU]
	,[Refresh_Date]
)
 
SELECT DISTINCT
FCT.Docdate AS DateOfFailure
,FCT.FK_ibid
,VO.Chassis AS ChassisNo
,FCT.FK_modelid as ModelID
,FCT.FK_itemid as ItemID
,FCT.UsageReading AS KMReading
,format(cast(VO.vodate as date),'yyyy-MM-dd') AS ProductionDate
--,IBM.BU
,GETDATE() AS Refresh_Date
 
FROM ASM_CV_SERVICE_FACT FCT
INNER JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON IBM.PK_IBID = FCT.FK_IBID
INNER JOIN SAP_YMFGT_CHASSIS_VODATE VO ON IBM.Chassis = VO.Chassis
WHERE FCT.ITEMGROUPTYPE = 'BAL Parts' --AND IBM.BU = 'CV' 
AND FCT.PARTREPAIRTYPE = 'WARRANTY' AND FK_Contracttypeid != '8'

PRINT('ASM_CV_SERVICE_ELF_AGGR_DIM LOADED')

END
GO