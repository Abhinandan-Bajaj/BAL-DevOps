SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Alter PROC [dbo].[USP_ASM_PB_SERVICE_DIMENSION_FULLOAD_P3]
AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			    */
/*--------------------------------------------------------------------------------------------------*/
/*	2024-10-28 	|	Lachmanna 		  | ASM_PB_SERVICE_COMPLAINT_MASTER_DIM      */              
/*	2024-12-19 	|	Lachmanna 		  | Restricated The   Mobile App Feedback and Duplicate,Invalid   */ 
/* 2024-12-30 	|	Ashwini Ahire		| ASM_PB_SERVICE_SPARE_CLAIM_HEADER_DIM- New Dim Table Created 
2025-03-26      |   Richa               | Additional columns in Compaint master Dim
2025-05-15      |   Richa               | Additional columns in Compaint master Dim for Visit and CCdays*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
PRINT('LOADING DATA FROM Source TABLE')
TRUNCATE TABLE ASM_PB_SERVICE_COMPLAINT_MASTER_DIM
INSERT INTO ASM_PB_SERVICE_COMPLAINT_MASTER_DIM(
[ISRDocid]
,[Complaint_Number]
,[Department]
,[DocType]
,[Activity]
,[Call_Date]
,[DocStatus]
,[Agent]
,[Complaints_Closed_Days]
,[Complaint_Status]
,[Query_Status]
,[Contacted_hrs]
,[Status_Date]
,[Issue_Status]
,[OpenedSince]
,[ModeofContact]
,[CustomerState]
,[CustomerCity]
,[Asc]
,[ServiceCentreVisit]
,[ProductType]
,[CcmSelectedModel]
,[VehicleNo]
,[Kms]
,[VehicleSaleDate]
,[CustomerName]
,[PhoneNo]
,[CallTag]
,[CustomerVoice]
,[CustomerRemarks]
,[CallCentreRemarks]
,[CurrentActivityStatus]
,[DealerCode]
,[BranchId]
,[ModelId]
,[BU]
,[ImportedDate]
,[Refresh_Date]
,RCAStatus
,CRAttribute
,CRAttributeReason
,CRAttributeDescription
,WithVisit
,CCTAT_Days
)
SELECT DISTINCT CR.ISRDOCID AS ISRDocid
		,CR.DOCNAME AS Complaint_Number
        ,CASE 
			WHEN CR.Department = 'Service' THEN 'Service'
			WHEN CR.Department = 'Service / Spares' THEN 'Service'
        END AS Department
        ,CR.DocType AS DocType
        ,CR.Activity AS Activity
        ,CR.CallDate AS Call_Date
        ,CR.DocStatus AS DocStatus
        ,CR.Agent AS Agent
        ,NULL AS Complaints_Closed_Days
        ,CASE
            WHEN CR.CURRENTACTIVITY in ('Second Follow Up','First Follow Up','In-Progress','Fifth Follow Up','Reopened','Contacted','Fourth Follow Up','On Hold','Not Reporting','Not Reporting or Not Responding','Reassigned','Fresh','Waiting for Parts','Third Follow Up','In Progress')
            THEN 'Open'
            WHEN CR.CURRENTACTIVITY in ('Resolved','Closed')
            THEN 'Closed'
        END AS Complaint_Status
        ,CASE
            WHEN CR.ASMDEALERSTATUS = 'Open'
            THEN 'Open'
            WHEN CR.ASMDEALERSTATUS = 'Close'
            THEN 'Closed'
        END AS Query_Status
        ,NULL AS Contacted_Hrs
        ,CR.StatusDate AS Status_Date
        ,CR.IssueStatus AS Issue_Status
        ,CR.OpenedSince AS OpenedSince
        ,CR.[ModeOfContact(CallType)] AS ModeOfContact
        ,CR.CustomerState AS CustomerState
        ,CR.CustomerCity AS CustomerCity
        ,CR.[Asc] AS [ASC]
        ,CR.CUSTOMERVISITEDDEALERSHIPORSERVICECENTRE AS ServiceCentreVisit
        ,CR.ProductType As ProductType
        ,CR.CCMSELECTEDMODEL AS CcmSelectedModel 
        ,CR.[VehicleNo(RegistrationModel)] AS VehicleNo
        ,CR.[OdometerReading(Kms)] AS Kms
        ,CR.[DateofPurchase(Vehicle)] AS VehicleSaleDate
        ,CR.CustomerName AS CustomerName 
        ,CR.PhoneNo AS PhoneNo
        ,CR.CallTag As CallTag
        ,CR.CustomerVoice AS CustomerVoice
        ,CR.CustomerRemarks AS CustomerRemarks
        ,CR.CallCentreRemarks AS CallCentreRemarks 
        ,CR.CurrentActivity AS CurrentActivityStatus
        ,CIH.DEALERCODE AS DealerCode
        ,CIH.Branchid AS BranchId
        ,CIH.MODELID AS ModelID
        ,CASE 
                WHEN CIH.Producttype  in ('KTM','Triumph','Husqvarna') THEN 'PB'
         END AS BU
	    ,CR.ImportedDate AS ImportedDate
        ,getdate() AS Refresh_Date 
		,CRCA.RCAStatus AS RCAStatus
        ,CRCA.CRAttribute AS CRAttribute
        ,CRCA.CRAttributeReason AS CRAttributeReason
        ,CRCA.CRAttributeDescription AS CRAttributeDescription
		,Null AS WithVisit
		,Null As CCTAT_Days
FROM  [dbo].[CALL_REGISTER] CR 
 Left JOIN [dbo].[CDMS_ISSUE_HEADER] CIH   ON CIH.ISSUEHEADERID = CR.ISRDOCID 
 LEFT JOIN [dbo].[CDMS_ROOT_CAUSE_ANALYSIS] CRCA ON CRCA.ISRDocid = CR.ISRDocid
WHERE 
CR.DOCTYPE IN ('Query', 'Complaint') AND 
CR.DOCNAME like 'ISR%' AND 
CR.CALLDATE >= '2020-01-01' AND
CIH.Producttype  in ('KTM','Triumph','Husqvarna') AND
CR.Department in ('Service','Service / Spares') AND
CR.CURRENTACTIVITY Not in ('Duplicate','Invalid') AND
CR.[ModeOfContact(CallType)] Not in('Mobile App Feedback','Chatbot','Chatbot Feedback')  --CR added 12/Dec/2024 

Union ALL

SELECT DISTINCT CIH.ISSUEHEADERID AS ISRDocid
		,CIH.ISSUEHEADERNAME AS Complaint_Number
        ,CASE 
			WHEN CIH.Department = 'Service' THEN 'Service'
			WHEN CIH.Department = 'Service / Spares' THEN 'Service'
        END AS Department
        ,CIH.CALLCOMPLAINTTYPE AS DocType
        ,CIR.Activity AS Activity
        ,CIH.ISSUEDOCDATE AS Call_Date
        ,CIH.DOCUMENTSTATUS AS DocStatus
        ,CIR.ACTIVITYCONTACTGROUP AS Agent
        ,NULL AS Complaints_Closed_Days
        ,CASE
            WHEN CIR.ACTIVITY in ('Second Follow Up','First Follow Up','In-Progress','Fifth Follow Up','Reopened','Contacted','Fourth Follow Up','On Hold','Not Reporting','Not Reporting or Not Responding','Reassigned','Fresh','Waiting for Parts','Third Follow Up','In Progress')
            THEN 'Open'
            WHEN CIR.ACTIVITY in ('Resolved','Closed')
            THEN 'Closed'
        END AS Complaint_Status
        --,CASE
        --    WHEN CIH.ASMDEALERSTATUS = 'Open'
        --    THEN 'Open'
        --    WHEN CIH.ASMDEALERSTATUS = 'Close'
        --    THEN 'Closed'
        --END AS Query_Status
		,NULL as  Query_Status
        ,NULL AS Contacted_Hrs
        ,CIR.StatusDate AS Status_Date
        ,CIR.ACTIVITY AS Issue_Status
        ,NUll as OpenedSince --CIH.OpenedSince AS OpenedSince
        ,CIH.MODEOFCONTACT AS ModeOfContact
        , Null as CustomerState --CIH.CustomerState AS CustomerState
        , null as CustomerCity --CIH.CustomerCity AS CustomerCity
        ,Null as [ASC] -- CIH.[Asc] AS [ASC]
        ,Case when CIH.CUSTOMERVISITED=1 then 'Yes' else 'No' end  AS ServiceCentreVisit
        ,CIH.ProductType As ProductType
        ,CIH.CCMSELECTEDMODEL AS CcmSelectedModel 
        ,CIH.REGISTRATIONNUMBER AS VehicleNo
        ,CIH.LASTSERVICEODOMETERREADING AS Kms
        ,CIH.DATEOFPURCHASE AS VehicleSaleDate
        ,CIH.CustomerName AS CustomerName 
        ,CIH.MOBILE AS PhoneNo
        ,Null as CallTag --CIH.CallTag As CallTag
        ,CIH.CustomerVoice AS CustomerVoice
        ,NUll as  CustomerRemarks-- CIH.CustomerRemarks AS CustomerRemarks
        ,CIR.REMARKS AS CallCentreRemarks 
        ,CIR.Activity as CurrentActivityStatus --CR added 12/Dec/2024
        ,CIH.DEALERCODE AS DealerCode
        ,CIH.Branchid AS BranchId
        ,CIH.MODELID AS ModelID
        ,CASE 
                WHEN CIH.Producttype  in ('KTM','Triumph','Husqvarna') THEN 'PB'
         END AS BU
	    ,CIH.ImportedDate AS ImportedDate
        ,getdate() AS Refresh_Date 
		,CRCA.RCAStatus AS RCAStatus
        ,CRCA.CRAttribute AS CRAttribute
        ,CRCA.CRAttributeReason AS CRAttributeReason
        ,CRCA.CRAttributeDescription AS CRAttributeDescription
		,Null AS WithVisit
		,Null As CCTAT_Days
FROM  [dbo].[CDMS_ISSUE_HEADER] CIH 
 Left JOIN (select  Row_number() OVER(PARTITION BY ISSUEHEADERID order BY STATUSDATE DESC) AS RNK , * from [dbo].CDMS_ISSUE_RESOLUTION ) CIR ON CIH.ISSUEHEADERID = CIR.ISSUEHEADERID  and RNK=1
 LEFT JOIN [dbo].[CDMS_ROOT_CAUSE_ANALYSIS] CRCA ON CRCA.ISRDocid = CIR.ISSUEHEADERID
WHERE 
CIH.CALLCOMPLAINTTYPE IN ('Query', 'Complaint') AND 
CIH.ISSUEHEADERNAME like 'ISR%' AND 
CIH.ISSUEDOCDATE >= '2020-01-01' AND
CIH.Producttype  in ('KTM','Triumph','Husqvarna') AND
CIH.Department in ('Service','Service / Spares') AND
CIR.ACTIVITY Not in ('Duplicate','Invalid')  AND
CIH.MODEOFCONTACT  Not in ('Mobile App Feedback','Chatbot','Chatbot Feedback') --CR added 12/Dec/2024

---------------------------------------------------------------
SELECT
    CIR.ISSUEHEADERID,
    CIR.Activity,
    CIR.StatusDate
    INTO #Contacted_hours
FROM [dbo].[ASM_PB_SERVICE_COMPLAINT_MASTER_DIM] CR
LEFT JOIN [dbo].[CDMS_ISSUE_RESOLUTION] CIR ON CR.ISRDocid = CIR.ISSUEHEADERID

SELECT
    ISSUEHEADERID,
    MIN(CASE WHEN Activity = 'Fresh' THEN StatusDate END) AS FreshDate,
    MIN(CASE WHEN Activity = 'Contacted' THEN StatusDate END) AS ContactedDate,
DATEDIFF(SECOND,
MIN(CASE WHEN Activity = 'Fresh' THEN StatusDate END),
MIN(CASE WHEN Activity = 'Contacted' THEN StatusDate END)) AS DifferenceInSeconds,
CAST(ROUND(DATEDIFF(SECOND,
MIN(CASE WHEN Activity = 'Fresh' THEN StatusDate END),
MIN(CASE WHEN Activity = 'Contacted' THEN StatusDate END)) / 3600.00, 2) AS VARCHAR(20)) AS Contacted_Time_Hrs
INTO #Contacted_hrs_final
FROM #Contacted_hours
WHERE Activity IN ('Fresh', 'Contacted')
GROUP BY ISSUEHEADERID;

UPDATE ACM
SET ACM.Contacted_Hrs = RDF.Contacted_Time_Hrs
FROM ASM_PB_SERVICE_COMPLAINT_MASTER_DIM ACM
JOIN #Contacted_hrs_final RDF ON ACM.IsrDocid = RDF.ISSUEHEADERID

DROP TABLE #Contacted_hours;
DROP TABLE #Contacted_hrs_final;

------------------------------------------------------------------------------
SELECT
    CIR.ISSUEHEADERID,
	CIR.Activity,
	CIR.StatusDate
INTO #Closed_days
FROM [dbo].[ASM_PB_SERVICE_COMPLAINT_MASTER_DIM] CR
LEFT JOIN [dbo].[CDMS_ISSUE_RESOLUTION] CIR ON CR.ISRDocid = CIR.ISSUEHEADERID

SELECT 
    ISSUEHEADERID,
    MIN(CASE WHEN Activity = 'Fresh' THEN StatusDate END) AS FreshDate,
    MIN(CASE WHEN Activity = 'Resolved' THEN StatusDate END) AS ClosedDate,
    DATEDIFF(DAY, 
             MIN(CASE WHEN Activity = 'Fresh' THEN StatusDate END),
             MIN(CASE WHEN Activity = 'Resolved' THEN StatusDate END)) AS Closed_days
INTO #Closed_days_final
FROM #Closed_days
WHERE Activity IN ('Fresh', 'Resolved')
GROUP BY ISSUEHEADERID;

UPDATE ACM
SET ACM.Complaints_Closed_Days = RHF.Closed_days
FROM ASM_PB_SERVICE_COMPLAINT_MASTER_DIM ACM
JOIN  #Closed_days_final RHF ON ACM.IsrDocid = RHF.ISSUEHEADERID;

----------------------------------With/Without Visit-------------------------------------------------------


WITH BaseData AS (
   SELECT    CR.ISRDOCID , CIH.IBID, CR.CALLDATE, SE.DOCDate, CF.ClosedDate, SE.Billeddatetime
FROM [dbo].[CALL_REGISTER] CR 
LEFT JOIN [dbo].[CDMS_ISSUE_HEADER] CIH ON CIH.ISSUEHEADERID = CR.ISRDOCID
LEFT JOIN [dbo].[CDMS_ROOT_CAUSE_ANALYSIS] CRCA ON CRCA.ISRDocid = CR.ISRDocid
LEFT JOIN CDMS_ISSUE_RESOLUTION IR ON CR.ISRDocid = IR.ISSUEHEADERID
LEFT JOIN #Closed_days_final CF ON CF.ISSUEHEADERID = CR.ISRDocid
inner JOIN ASM_PB_SERVICE_STG SE ON SE.fk_ibid = CIH.IBID
AND (
        (SE.DOCDate BETWEEN CR.CALLDATE AND CF.ClosedDate
         AND SE.Billeddatetime BETWEEN CR.CALLDATE AND CF.ClosedDate)
        OR 
        (SE.DOCDate < CR.CALLDATE AND SE.Billeddatetime > CF.ClosedDate)
    ) 

),
RankedData AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY IBID ORDER BY CALLDATE desc) AS rn
    FROM BaseData
)

SELECT *
INTO #VisitTempdata
FROM RankedData
WHERE rn = 1;


UPDATE CCRPF
SET WithVisit = CASE 
    WHEN CT.ibid IS NOT NULL THEN 1
    ELSE 0
END
, CCTAT_Days = CASE 
    WHEN CT.ibid IS NOT NULL THEN DATEDIFF(DAY,  CT.Docdate , CT.closeddate )
    ELSE 0 end
FROM ASM_PB_SERVICE_COMPLAINT_MASTER_DIM CCRPF
LEFT JOIN #VisitTempdata CT
    ON CCRPF.ISRDOCID = CT.ISRDOCID;


drop table #Closed_days
drop table #Closed_days_final
drop table #VisitTempdata

---------------------------------------DEDUP

DELETE FROM DBO.ASM_PB_SERVICE_COMPLAINT_MASTER_DIM WHERE  Activity IN ('Duplicate','Invalid') OR CurrentActivityStatus IN ('Duplicate','Invalid');  --CR added 12/Dec/2024

;WITH CTE AS                  
(                  
  SELECT *,                  
   Row_number() OVER(PARTITION BY IsrDocid ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM DBO.ASM_PB_SERVICE_COMPLAINT_MASTER_DIM
) delete FROM CTE WHERE RNK<>1;


PRINT('ASM_PB_SERVICE_COMPLAINT_MASTER_DIM TABLE LOADED')

---------------------------------SPARE CLAIM HEADER - FFR/AFR Screen----------------------------

TRUNCATE TABLE ASM_PB_SERVICE_SPARE_CLAIM_HEADER_DIM
 
INSERT INTO ASM_PB_SERVICE_SPARE_CLAIM_HEADER_DIM(
[HeaderID]
,[FFRAGAINSTDOCID]
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
,[IR_DocName]  
,[IR_DocDate]  
,[IR_Status]  
,[IR_SubmittedDate]
,[DefectCode]
,[DefectDescription]
,[ModelID]
,[DealerCode]
,[BranchId]
,[ITEMID]
,[BU]
,[IBID]
,[ContactID]
,[ContractTypeID]
,[PartContractTypeID]
,[ImportedDate]
,[Refresh_Date]
,[IR_TAT_Days]
,[FFRParentID]
,[ReportDate]
,[ProductCode]
,[PLANT]
,[DATEOFSALE]
,[DATEOFFAILURE]
,[REPAIRDATE]
,[KM_READING]
,[CUSTOMERVOICE]
,[GroupCode]
,[VendorName]
)
SELECT DISTINCT SCH.HEADERID AS HeaderID
        ,SCHE.FFRAGAINSTDOCID AS FFRAGAINSTDOCID
        ,SCH.DOCNAME AS FFR_Number
        ,SCH.CREATIONDATE AS Creation_Date
       ,CASE 
	    WHEN SCHE.FFRParentID != 0 THEN 'Child'
	    ELSE 'Parent'
         END AS FFR_Identification    
        ,SCHE.FFR_STATUS AS FFR_STATUS
        ,CASE
            WHEN FFR_Status IN ('Open') OR FFR_Status IS NULL THEN 'Open'
            WHEN FFR_Status IN ('Closed Due To System Closure', 'Closed Lapsed By Agent') THEN 'Lapsed'
            WHEN FFR_Status IN ('Submitted To ASM', 'Accepted by ASM', 'Closed', 'Closed by ASM', 'GroupedByASM', 'Deleted by ASM', 'Reopened by ASM', 'Reverted By ASM', 'Accepted By PSG', 'Submitted To CQA', 'Submitted To PSG', 'Lapsed') THEN 'Submitted'
        END AS Status_FFR_Derived
        ,CAHE.AFR_DocName AS AFR_Number
        ,CAHE.AFR_STATUS AS AFR_Status
        ,CASE
            WHEN CAHE.AFR_Status IN ('Open','Reopened By PSG', 'AFR Deleted By ASM') THEN 'Open'
            WHEN CAHE.AFR_Status IN ('AFR Closed due to Time Lapsed', 'Closed Due To System Closure') THEN 'Lapsed'
            WHEN CAHE.AFR_Status IN ('Resent By PSG', 'Resubmitted To PSG', 'Submitted To PSG', 'Accepted By PSG', 'Closed By CQA', 'AFR Closed By PSG', 'AFR Closed By ASM', 'Grouped By PSG') THEN 'Submitted'
            WHEN FFR_Status IN ('Submitted To CQA', 'Submitted To PSG', 'Closed By CQA', 'Closed By PSG', 'Accepted By PSG', 'Reopened By PSG', 'Resubmitted To PSG') THEN 'Submitted'
        END AS Status_AFR_Derived
        ,SCHE.SUBMISSIONDATE AS FFR_SubmittedDate
        ,CAHE.AFR_SUBMISSIONDATE AS AFR_SubmittedDate
        ,CAHE.AFR_ASMNAME AS ASM_Name
        ,CIHE.IR_DocName AS IR_DocName        
        ,CIHE.IR_DocDate AS IR_DocDate        
        ,CIHE.IR_Status AS IR_Status          
        ,CIHE.IR_SubmissionDate AS IR_SubmittedDate
        ,CPM.CODE AS DefectCode
        ,CPM.NAME AS DefectDescription
        ,SCLE.MODELID AS ModelID
        ,CM.CODE AS DealerCode
        ,SCH.BRANCHID AS BranchId
        ,SCL.ITEMID AS ITEMID
        ,CASE
            WHEN CM.CompanyType IN (2) THEN 'PB'
        END AS BU
        ,SCL.IBID AS IBID
        ,SCL.ContactID AS ContactID
        ,SCH.ContractTypeID AS ContractTypeID
        ,SCL.ContractTypeID AS PartContractTypeID
    ,SCH.ImportedDate AS ImportedDate
    ,getdate() AS Refresh_Date
    ,DATEDIFF(DAY, CIHE.IR_DOCDATE, CIHE.IR_SubmissionDate) AS IR_TAT_Days
    ,SCHE.FFRParentID AS FFRParentID
    ,SCLE.ReportDate as ReportDate
    ,SCLE.ProductCode as ProductCode
    ,CASE 
			WHEN substring(SCL.SerialNo,11,1) = 'C' then 'Chakan'
			WHEN substring(SCL.SerialNo,11,1) = 'P' then 'Pant Nagar Plant 1'
			WHEN substring(SCL.SerialNo,11,1) = 'R' then 'Pant Nagar Plant 2'
			WHEN substring(SCL.SerialNo,11,1) = 'W' then 'Waluj'
			ELSE NULL
		  END AS PLANT
    ,SCLE.DATEOFSALE AS DATEOFSALE
    ,SCLE.DATEOFFAILURE AS DATEOFFAILURE
    ,SCLE.REPAIRDATE AS REPAIRDATE
    ,SCL.USAGEREADING AS KM_READING
    ,SCLE.CUSTOMERVOICE AS CUSTOMERVOICE
    ,SCHE.GroupCode as GroupCode
    ,VM.VendorName as VendorName


FROM [dbo].[SPARE_CLAIM_HEADER] SCH
LEFT JOIN [dbo].[SPARE_CLAIM_HEADER_EXT] SCHE ON SCH.HEADERID = SCHE.HEADERID
LEFT JOIN [dbo].[SPARE_CLAIM_LINE] SCL ON SCL.DOCID = SCH.HEADERID
LEFT JOIN [dbo].[SPARE_CLAIM_LINE_EXT] SCLE ON SCLE.HEADERID = SCL.CDMSUniqueID
LEFT JOIN [dbo].[CDMS_AFRHEADER_EXPORT] CAHE ON CAHE.FFRHeaderID = SCH.HEADERID
LEFT JOIN [dbo].[CDMS_IRHEADER_EXPORT] CIHE ON CIHE.AFRHeaderID = CAHE.CDMSUniqueID
INNER JOIN [dbo].[ASM_SERVICE_ITEM_MASTER_DIM] IM ON IM.ITEMID = SCL.ITEMID
LEFT JOIN [dbo].[ASM_SERVICE_VENDOR_MASTER_DIM] VM ON (VM.ItemCode = IM.ItemCode AND VM.CHASSIS = SCL.SerialNo)
LEFT JOIN [dbo].[COMPLAINT_MASTER] CPM ON CPM.COMPALINTID = SCLE.DEFECTCODE 
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SCH.COMPANYID AND CM.IMPORTEDDATE =
(SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID))
WHERE CM.COMPANYTYPE in (2) AND SCH.DOCTYPE = 452 AND SCL.PartGroup in ('BAL Parts')
and CPM.CODE is not null


--------Update for Child FFR-AFR Mapping
 
SELECT * INTO #ChildFFRMapping FROM
(SELECT DISTINCT FFRHeaderID AS FFRHeaderID, AFR_Docname AS AFR_Number, AFR_Status AS AFR_Status, AFR_SUBMISSIONDATE AS AFR_SubmittedDate, AFR_ASMNAME AS ASM_Name
FROM CDMS_AFRHEADER_EXPORT)T
 
UPDATE SCH
SET SCH.AFR_Number = B.AFR_Number, SCH.AFR_Status = B.AFR_Status, SCH.AFR_SubmittedDate = B.AFR_SubmittedDate, SCH.ASM_Name = B.ASM_Name
from ASM_PB_SERVICE_SPARE_CLAIM_HEADER_DIM SCH
left join #ChildFFRMapping B ON B.FFRHeaderID = SCH.FFRParentID WHERE SCH.FFR_Identification = 'Child'
drop table #ChildFFRMapping

PRINT('ASM_PB_SERVICE_SPARE_CLAIM_HEADER_DIM TABLE LOADED')

END
GO