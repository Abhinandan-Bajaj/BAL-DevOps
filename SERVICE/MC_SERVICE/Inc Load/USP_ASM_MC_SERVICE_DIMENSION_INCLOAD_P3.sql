--INc LOAD 
/*******************************************HISTORY***************************************************************************************************/
/*----------------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY     |CHANGE DESCRIPTION	                                                                              */
/*----------------------------------------------------------------------------------------------------------------------------------------------------*/
/* 2024-08-25 	|	Ashwini Ahire		| ASM_MC_SERVICE_SPARE_CLAIM_HEADER_DIM- New Dim Table Created                                        */
/*	                                      ASM_MC_SERVICE_COMPLAINT_MASTER_DIM- New Dim Table Created                                          */                                              
/* 2024-10-18 	|	Aniket Mahulikar    | ASM_MC_SERVICE_COMPLAINT_MASTER_DIM- Updated Contacted Within 1hr code for complaints after 6pm-9am */     
/* 2025-01-24 	|	Ashwini Ahire       | Update INC Load Script, COntacted within 1hr and Source tables  */     
/*----------------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY****************************************************************************************************/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_MC_SERVICE_DIMENSION_INCLOAD_P3] AS

BEGIN

--DECLARE @MAXDATESTG02 DATETIME2(7)= (SELECT MAX(IMPORTEDDATE) FROM ASM_MC_SERVICE_SPARE_CLAIM_HEADER_DIM)

declare @ASM_MC_SPARE_CLAIM_loaddate date;
set @ASM_MC_SPARE_CLAIM_loaddate = CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_MC_SERVICE_SPARE_CLAIM_HEADER_DIM)AS DATE);

PRINT('LOADING DATA FROM BASE TABLE')

--INC LOAD
--1. Load Spare Claim Header DIM for MC

INSERT INTO ASM_MC_SERVICE_SPARE_CLAIM_HEADER_DIM(
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
,[ASD_DealerCode]
,[FFRParentID]
)
SELECT DISTINCT SCH.HEADERID AS HeaderID
        ,SCHE.FFRAGAINSTDOCID AS FFRAGAINSTDOCID
        ,SCH.DOCNAME AS FFR_Number
        ,SCH.CREATIONDATE AS Creation_Date
        ,CASE
            WHEN SCHE.ISPARENT = '1' THEN 'PARENT'
            WHEN (SCHE.ISPARENT IS NULL OR SCHE.ISPARENT = '0') THEN 'CHILD'
         END AS FFR_Identification    
        ,SCHE.FFR_STATUS AS FFR_STATUS
        ,CASE
            WHEN FFR_Status IN ('Open') OR FFR_Status IS NULL THEN 'Open'
            WHEN FFR_Status IN ('Closed Due To System Closure', 'Closed Lapsed By Agent') THEN 'Lapsed'
            WHEN FFR_Status IN ('Submitted To ASM', 'Accepted by ASM', 'Closed', 'Closed by ASM', 'Grouped by ASM', 'Deleted by ASM', 'Reopened by ASM', 'Reverted By ASM', 'Accepted By PSG', 'Submitted To CQA', 'Submitted To PSG', 'Lapsed') THEN 'Submitted'
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
            WHEN CM.CompanyType IN (1,8) THEN 'MC'
        END AS BU
        ,SCL.IBID AS IBID
        ,SCL.ContactID AS ContactID
        ,SCH.ContractTypeID AS ContractTypeID
        ,SCL.ContractTypeID AS PartContractTypeID
    ,SCH.ImportedDate AS ImportedDate
    ,getdate() AS Refresh_Date
    ,DATEDIFF(DAY, CIHE.IR_DOCDATE, CIHE.IR_SubmissionDate) AS IR_TAT_Days 
    ,CM.CODE AS ASD_DealerCode
    ,SCHE.FFRParentID AS FFRParentID
FROM [dbo].[SPARE_CLAIM_HEADER] SCH
LEFT JOIN [dbo].[SPARE_CLAIM_HEADER_EXT] SCHE ON SCH.HEADERID = SCHE.HEADERID
LEFT JOIN [dbo].[SPARE_CLAIM_LINE] SCL ON SCL.DOCID = SCH.HEADERID
LEFT JOIN [dbo].[SPARE_CLAIM_LINE_EXT] SCLE ON SCLE.HEADERID = SCL.CDMSUniqueID
LEFT JOIN [dbo].[CDMS_AFRHEADER_EXPORT] CAHE ON CAHE.FFRHeaderID = SCH.HEADERID
LEFT JOIN [dbo].[CDMS_IRHEADER_EXPORT] CIHE ON CIHE.AFRHeaderID = CAHE.CDMSUniqueID
INNER JOIN [dbo].[ASM_SERVICE_ITEM_MASTER_DIM] IM ON IM.ITEMID = SCL.ITEMID
LEFT JOIN [dbo].[COMPLAINT_MASTER] CPM ON CPM.COMPALINTID = SCLE.DEFECTCODE 
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SCH.COMPANYID AND CM.IMPORTEDDATE =
(SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID))
WHERE CM.COMPANYTYPE in (1,8) AND SCH.DOCTYPE = 452 AND SCL.PartGroup in ('BAL Parts')
and CPM.CODE is not null
--AND SCH.ImportedDate > @MAXDATESTG02 
AND CAST(SCH.ImportedDate AS DATE) >= @ASM_MC_SPARE_CLAIM_loaddate;

--------Deleting Partial Records from the Dim table---------

DELETE FROM ASM_MC_SERVICE_SPARE_CLAIM_HEADER_DIM WHERE Creation_Date > Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate()))) - 1 as date);

-----Update for ASD_dealercode Mapping---------

SELECT * INTO #ServiceDealerMapping FROM
(SELECT DISTINCT ZF_ASC ASD_DEALERCODE,DEALER_CODE DEALERCODE
FROM SAP_ZSD_ASC_DETAIL
WHERE SER_STATUS = 'OPERATIONAL')T
 
UPDATE B
SET B.Dealercode=A.DEALERCODE
FROM ASM_MC_SERVICE_SPARE_CLAIM_HEADER_DIM B
INNER JOIN #ServiceDealerMapping A ON B.ASD_DealerCode=A.ASD_DEALERCODE
drop table #ServiceDealerMapping

--------Update for Child FFR-AFR Mapping------------
 
SELECT * INTO #ChildFFRMapping FROM
(SELECT DISTINCT FFRHeaderID AS FFRHeaderID, AFR_Docname AS AFR_Number, AFR_Status AS AFR_Status, AFR_SUBMISSIONDATE AS AFR_SubmittedDate, AFR_ASMNAME AS ASM_Name
FROM CDMS_AFRHEADER_EXPORT)T
 
UPDATE SCH
SET SCH.AFR_Number = B.AFR_Number, SCH.AFR_Status = B.AFR_Status, SCH.AFR_SubmittedDate = B.AFR_SubmittedDate, SCH.ASM_Name = B.ASM_Name
from ASM_MC_SERVICE_SPARE_CLAIM_HEADER_DIM SCH
left join #ChildFFRMapping B ON B.FFRHeaderID = SCH.FFRParentID WHERE SCH.FFR_Identification = 'Child'
drop table #ChildFFRMapping

---------------------------------------DEDUP

;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY HeaderId ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_MC_SERVICE_SPARE_CLAIM_HEADER_DIM 
)          
DELETE FROM CTE                  
WHERE RNK<>1;
------------------------------------------------------------------

PRINT('ASM_MC_SERVICE_SPARE_CLAIM_HEADER_DIM TABLE LOADED')

--*****************************************************************
--3. Load Complain Master DIM for MC

--DECLARE @MAXDATESTG03 DATETIME2(7)= (SELECT MAX(IMPORTEDDATE) FROM ASM_MC_SERVICE_COMPLAINT_MASTER_DIM)

declare @ASM_MC_Complaints_loaddate date;
set @ASM_MC_Complaints_loaddate = CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_MC_SERVICE_COMPLAINT_MASTER_DIM)AS DATE);

INSERT INTO ASM_MC_SERVICE_COMPLAINT_MASTER_DIM (
    [ISRDocid],
    [Complaint_Number],
    [Department],
    [DocType],
    [Activity],
    [Call_Date],
    [DocStatus],
    [Agent],
    [Complaints_Closed_Days],
    [Query_Status],
    [Contacted_hrs],
    [Status_Date],
    [Issue_Status],
    [OpenedSince],
    [ModeofContact],
    [CustomerState],
    [CustomerCity],
    [Asc],
    [ServiceCentreVisit],
    [ProductType],
    [CcmSelectedModel],
    [VehicleNo],
    [Kms],
    [VehicleSaleDate],
    [CustomerName],
    [PhoneNo],
    [CallTag],
    [CustomerVoice],
    [CustomerRemarks],
    [CallCentreRemarks],
    [CurrentActivityStatus],
    [DealerCode],
    [BranchId],
    [ModelId],
    [BU],
    [ImportedDate],
    [Refresh_Date]
)
SELECT DISTINCT 
    CIH.ISSUEHEADERID AS ISRDocid,
    CIH.ISSUEHEADERNAME AS Complaint_Number,
    CASE 
        WHEN CIH.DEPARTMENT = 'Service' THEN 'Service'
        WHEN CIH.DEPARTMENT = 'Service / Spares' THEN 'Service'
    END AS Department,
    CIH.CALLCOMPLAINTTYPE AS DocType,
    CR.Activity AS Activity,
    CIH.ISSUEDOCDATE AS Call_Date,
    CR.DocStatus AS DocStatus,
    CR.Agent AS Agent,
    NULL AS Complaints_Closed_Days,
    CASE
        WHEN CCR.ASM_DEALER_STATUS = 'Open' THEN 'Open'
        WHEN CCR.ASM_DEALER_STATUS = 'Close' THEN 'Closed'
    END AS Query_Status,
    NULL AS Contacted_Hrs,
    CR.StatusDate AS Status_Date,
    CR.IssueStatus AS Issue_Status,
    CR.OpenedSince AS OpenedSince,
    CR.[ModeOfContact(CallType)] AS ModeOfContact,
    CR.CustomerState AS CustomerState,
    CR.CustomerCity AS CustomerCity,
    CR.[Asc] AS [ASC],
    CR.CUSTOMERVISITEDDEALERSHIPORSERVICECENTRE AS ServiceCentreVisit,
    CR.ProductType AS ProductType,
    CR.CCMSELECTEDMODEL AS CcmSelectedModel,
    CR.[VehicleNo(RegistrationModel)] AS VehicleNo,
    CR.[OdometerReading(Kms)] AS Kms,
    CR.[DateofPurchase(Vehicle)] AS VehicleSaleDate,
    CR.CustomerName AS CustomerName,
    CR.PhoneNo AS PhoneNo,
    CR.CallTag AS CallTag,
    CR.CustomerVoice AS CustomerVoice,
    CR.CustomerRemarks AS CustomerRemarks,
    CR.CallCentreRemarks AS CallCentreRemarks,
    (SELECT TOP 1 CIR1.Activity 
     FROM [dbo].[CDMS_ISSUE_RESOLUTION] CIR1 
     WHERE CIR1.IssueHeaderID = CIH.IssueHeaderID 
     ORDER BY CIR1.StatusDate DESC) AS CurrentActivityStatus,
    CIH.DEALERCODE AS DealerCode,
    CIH.Branchid AS BranchId,
    CIH.MODELID AS ModelID,
    CASE 
        WHEN CIH.ProductType IN ('Motorcycle') THEN 'MC'
    END AS BU,
    CIH.IMPORTEDDATE AS ImportedDate,
    GETDATE() AS Refresh_Date
FROM [dbo].[CDMS_ISSUE_HEADER] CIH
LEFT JOIN [dbo].[CDMS_ISSUE_RESOLUTION] CIR ON CIR.ISSUEHEADERID = CIH.ISSUEHEADERID
LEFT JOIN [dbo].[CALL_REGISTER] CR ON CIH.ISSUEHEADERID = CR.ISRDOCID
LEFT JOIN [dbo].[CDMS_COMPLAINT_REMARKS] CCR on CCR.ISSUEHEADERID = CIH.ISSUEHEADERID
WHERE 
    CIH.CALLCOMPLAINTTYPE IN ('Query', 'Complaint') 
    AND CIH.ISSUEHEADERNAME LIKE 'ISR%' 
    AND CAST(CIH.ISSUEDOCDATE AS DATE) >= '2020-01-01'
    AND CIH.ProductType IN ('Motorcycle') 
    AND CIH.Department IN ('Service', 'Service / Spares')
    AND NOT EXISTS (
        SELECT 1
        FROM [dbo].[CDMS_ISSUE_RESOLUTION] CIR1
        WHERE CIR1.ISSUEHEADERID = CIH.ISSUEHEADERID
          AND CIR1.StatusDate = (
              SELECT MAX(CIR2.StatusDate)
              FROM [dbo].[CDMS_ISSUE_RESOLUTION] CIR2
              WHERE CIR2.ISSUEHEADERID = CIH.ISSUEHEADERID
          )
          AND CIR1.Activity IN ('Duplicate', 'Invalid')
    )
    --AND CR.ImportedDate > @MAXDATESTG03
    AND CAST(CIH.ImportedDate AS DATE) >= @ASM_MC_Complaints_loaddate;

--------Deleting Partial Records from the Dim table---------

DELETE FROM ASM_MC_SERVICE_COMPLAINT_MASTER_DIM WHERE Call_Date > Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate()))) - 1 as date);

 
---------------------------------------------------------------
SELECT
    CIR.ISSUEHEADERID,
    CIR.Activity,
    CIR.StatusDate
    INTO #Contacted_hours
FROM [dbo].[ASM_MC_SERVICE_COMPLAINT_MASTER_DIM] CR
LEFT JOIN [dbo].[CDMS_ISSUE_RESOLUTION] CIR 
    ON CR.ISRDocid = CIR.ISSUEHEADERID;
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
-- Update the complaints that meet the condition of FreshDate after 6:00 PM and ContactedDate before 9:00 AM next day
UPDATE ACM
SET ACM.Contacted_Hrs = CASE 
        WHEN DATEPART(HOUR, RDF.FreshDate) >= 18 
             AND (
                 (DATEPART(DAY, RDF.ContactedDate) = DATEPART(DAY, DATEADD(DAY, 1, RDF.FreshDate)) 
                  AND DATEPART(HOUR, RDF.ContactedDate) < 9)  -- Check ContactedDate is before 9 AM next day
                 OR 
                 (DATEPART(DAY, RDF.FreshDate) = DATEPART(DAY, RDF.ContactedDate)) -- same day
             )
        THEN '1'  -- Set to 1 hour if the condition is met
        ELSE RDF.Contacted_Time_Hrs
    END
FROM ASM_MC_SERVICE_COMPLAINT_MASTER_DIM ACM
JOIN #Contacted_hrs_final RDF 
    ON ACM.IsrDocid = RDF.ISSUEHEADERID;
DROP TABLE #Contacted_hours;
DROP TABLE #Contacted_hrs_final;

------------------------------------------------------------------------------
SELECT
    CIR.ISSUEHEADERID,
	CIR.Activity,
	CIR.StatusDate
INTO #Closed_days
FROM [dbo].[ASM_MC_SERVICE_COMPLAINT_MASTER_DIM] CR
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
FROM ASM_MC_SERVICE_COMPLAINT_MASTER_DIM ACM
JOIN  #Closed_days_final RHF ON ACM.IsrDocid = RHF.ISSUEHEADERID;

drop table #Closed_days
drop table #Closed_days_final

---------------------------------------DEDUP

;WITH CTE AS                  
(                  
  SELECT *,                  
    ROW_NUMBER()OVER(PARTITION BY IsrDocid ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_MC_SERVICE_COMPLAINT_MASTER_DIM
)          
DELETE FROM CTE                  
WHERE RNK<>1;

PRINT('ASM_MC_SERVICE_COMPLAINT_MASTER_DIMTABLE LOADED')

END
GO