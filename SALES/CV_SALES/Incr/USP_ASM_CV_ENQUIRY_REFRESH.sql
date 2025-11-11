SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter PROC [dbo].[USP_ASM_CV_ENQUIRY_REFRESH] AS
BEGIN
-- =============================================
-- Author:		<Dhanraj Andhale>
-- Create date: <05.01.2023>
-- Description:	<Description,,>

-- Modified by : <Nikita Lakhimale> 
-- Date : 29.04.2023
-- Description : LSQ Integration IBU
-- =============================================

/********************************************HISTORY********************************************/
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/
/*  DATE       |  CREATED BY/MODIFIED BY |              CHANGE DESCRIPTION                     */
/*---------------------------------------------------------------------------------------------*/
/*  05/01/2023 |  Dhanraj Andhale        |              Created 							   */
/*  29/04/2023 |  Nikita Lakhimale       |             LSQ Integration IBU                     */
/*  23/04/2024 |  Robin Singh            |            LSQ  Leadtype logic change               */
/*  03/05/2024 |  Robin Singh            |   Enquiry Lost Fields addition in Dim               */
/*  19/07/2024 |  Sarvesh Kulkarni       |            UTC to IST change for schedule update 
   13/12/2024 |  Richa Mishra            |            Mapping change in Salesperson */
   /*  12/03/2025 |  Lachmanna           |   Pincode and Aare  against Retail  */
/*  25/03/2025 |  Ashwini Ahire          |   First_source_lead_type and source and Sub source  */
/*    14/08/2025 |  Richa Mishra            |        Addition of LSQ Targets  */
/*---------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------*/
/********************************************HISTORY********************************************/



/**************************************************************************************************************************************/	
/********************************** STEP 1 : LOADING ENQUIRY DIMENSION TABLE FROM CDMS AND LSQ SOURCES ********************************/
/**************************************************************************************************************************************/

/* ------------------------------------------------------------------------------------------------------------------------------------
----------------------------STEP 1.1 LOADING ASM_CV_ENQUIRY_DIM_CDMS_STG CDMS stage table----------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------*/

declare @ASM_CV_ENQUIRY_DIM_CDMS_STG_loaddate date;
set @ASM_CV_ENQUIRY_DIM_CDMS_STG_loaddate=CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_CV_ENQUIRY_DIM_CDMS_STG)AS DATE);
INSERT INTO ASM_CV_ENQUIRY_DIM_CDMS_STG
SELECT DISTINCT
	EH.HEADERID AS PK_EnquiryHeaderID,
	Cast(EH.DOCDATE As Date) As EnquiryDate,
	EH.LEADTYPE AS EnquiryMedium,
	SOURCE_OF_ENQUIRY.VALUENAME AS EnquiryLeadSource,  
	CASE WHEN EH.LEADSTATUS='Closed' THEN 'Invoiced'  when EH.LEADSTATUS='Lost' THEN 'Closed'  Else EH.LEADSTATUS END AS EnquiryStatus,
	Case when EH.TESTRIDEOFFERED='Test Ride Taken' THEN 'Yes' Else 'No' End AS IsTestRideTaken ,
    Null AS TestRideOffered,
    Case WHEN EH.CUSTOMEROWNERSHIPPROFILEID IN ('First Time Buyer', 'First Time User') THEN 'FTB'
	WHEN EH.CUSTOMEROWNERSHIPPROFILEID='Repeat Time Buyer' AND EH.PREVIOUSLYOWNEDVEHICLE='Bajaj' then 'RTB - Bajaj'
	WHEN EH.CUSTOMEROWNERSHIPPROFILEID='Repeat Time Buyer' AND EH.PREVIOUSLYOWNEDVEHICLE in ('Atul', 'Other', 'Baxy', 'Piaggio', 'TVS', 'Mahindra & Mahindra', 'Vikram', 'E-Rickshaw') then 'RTB - Competition'
	ELSE EH.CUSTOMEROWNERSHIPPROFILEID END
	AS CustomerOwnershipProfileId ,
	EH.MODEOFPURCHASE AS ModeOfPurchase,
	SM.[NAME] AS EnquirySubsource,  
	EH.LEADLOSTREASON AS LeadLostReason,
	CASE WHEN IsGoodsCarrier=1 THEN 'Cargo' WHEN IsPassengerCarrier=1 THEN 'Passenger' END  AS PrimaryUsage,
	EH.LEADCLASSIFICATIONTYPE,
	EH.LostByFinance,
	EH.LostByChannel,
	EH.LostByProduct,
	EH.LostToCompetition,
	EH.LostByOthers,
	'' as LostByCategory,
	DATEADD(mi,30,(DATEADD(hh,5,getdate()))) AS CREATEDDATETIME,
	EH.IMPORTEDDATE,
	EH.CDMS_BATCHNO,
	CASE WHEN ENQUIRY_FOLLOWUP.FollowUp IS NOT NULL THEN 'Yes' else 'No' END  AS EnquiryFollowUp,
	EH.LEADTYPE AS LeadType,
	EH.SOURCETYPE AS SourceType,
	CASE WHEN EH.LEADSTATUS='Closed' THEN 'Invoiced' 
	when EH.LEADSTATUS='Lost' THEN 'Closed' 
	Else EH.LEADSTATUS END AS LeadStatus,
	CASE
	WHEN EH.LostToCompetition = 'Yes' THEN 'Competition'
	WHEN EH.LostByOthers = 1 THEN 'Others'
	END AS Lost_To_Competition_Others,
	CASE
	WHEN EH.lostbyfinance=1 THEN 'Lost by Finance'
	WHEN EH.lostbyproduct=1 THEN 'Lost by Product'
	WHEN EH.lostbychannel=1 THEN 'Lost by Channel'
	ELSE 'Others'
	END AS Lost_Category,
	Cast('' as varchar(50)) As Lost_Primary_Reason,
	Cast('' as varchar(50)) As Lost_Secondary_Reason,
	EH.FINANCECOMPANY AS FinanceCompany,
	EH.CompetitionVehicle AS LostToOEM,
	Cast(0 as int) As RetailConversionFlag,
	EH.ISEXCHANGEAPPLICABLE AS IsExchangeApplicable,
	EH.USAGEDETAILS,
	Case When ISNULL(EH.AreaName,'') <> '' and EH.LeadStatus in ('Open','Booked','Lost','Cancelled','Closed')
	then EH.AreaName
	else ''
	end As Area,
	Cast(0 as int) As Reason_Exist,
	0 as BaseFlag,
	NULL AS IsNeedsAssessment
   ,NULL AS ISDEMO
   ,NULL AS ISVISITED 
   ,NULL AS PINCODE 
   ,CONCAT(TRIM(CN.FIRSTNAME),' ',TRIM(CN.LASTNAME)) AS SALES_PERSON 
   ,NULL AS FIRSTFOLLOWUPDATE  
   ,NULL AS FIRSTISCUSTOMERCONTACTED 
   ,'' AS FOLLOWUPSCHEDULEDATE1 
   ,NULL AS LATESTFOLLOWUPDATE 
   ,NULL AS LATESTFOLLOWUPSCHEDULEDATE  
   ,NULL AS LATESTISCUSTOMERCONTACTED
   ,'' AS FollowupBucket
   ,NULL AS LeadLostSecondaryReason  
   ,NULL AS FollowupLatestDisposition
   ,ENQUIRY_FOLLOWUP.NO_OF_FOLLOWUPS AS NO_OF_FOLLOWUPS
     ,NULL AS  ENQUIRY_STAGE,
     NULL AS OPPORTUNITY_STATUS,
     NULL AS REASON_FOR_CHOOSING_COMPETITION ,
     NULL AS IS_ANY_FOLLOWUP_OVERDUE,
     NULL AS ENQUIRY_ORIGIN,
	 NULL AS COMPETITION_BRAND,
	 NULL AS COMPETITION_MODEL
FROM
	ENQUIRY_HEADER EH 
	LEFT JOIN ENQUIRY_HEADER_EXT EHE 
	ON EH.HEADERID = EHE.HEADERID
	
	LEFT JOIN (SELECT LEADDOCID,FollowUp, 
	ROW_NUMBER() OVER (PARTITION BY LEADDOCID ORDER BY COALESCE(ACTIVITYSTATUSDATE,DOCDATE) ASC) AS RANK_1,
    ROW_NUMBER() OVER (PARTITION BY LEADDOCID ORDER BY COALESCE(ACTIVITYSTATUSDATE,DOCDATE) DESC) AS NO_OF_FOLLOWUPS
	FROM ENQUIRY_FOLLOWUP)ENQUIRY_FOLLOWUP 
	ON EH.HEADERID=ENQUIRY_FOLLOWUP.LEADDOCID
	AND ENQUIRY_FOLLOWUP.RANK_1=1

	
	LEFT JOIN CONTACT_MASTER CN ON (EH.OWNERCONTACTID = CN.CONTACTID AND CN.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 
	WHERE CN.CONTACTID = CN1.CONTACTID))
	
	LEFT JOIN SOURCE_MASTER SM 
	ON SM.SOURCEMASTERID=EHE.SUBSOURCE
	
	LEFT OUTER JOIN SOURCE_OF_ENQUIRY 
	ON EHE.SOURCEOFENQUIRY=SOURCE_OF_ENQUIRY.VALUEID 
	
	INNER JOIN COMPANY_MASTER 
	ON EH.COMPANYID=COMPANY_MASTER.COMPANYID
	AND COMPANY_MASTER.COMPANYTYPE = 7

WHERE 	CAST(EH.IMPORTEDDATE AS DATE) >= @ASM_CV_ENQUIRY_DIM_CDMS_STG_loaddate

/* ------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------STEP 1.2 Deduplication of CDMS Data----------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------*/ 	

Delete from ASM_CV_ENQUIRY_DIM_CDMS_STG Where Cast(EnquiryDate as date)>Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate())))-1 as date); --UTC_TO_IST_Changes_needed

--Dedup Process:
  WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_EnquiryHeaderID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_CV_ENQUIRY_DIM_CDMS_STG                  
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;  

/* ------------------------------------------------------------------------------------------------------------------------------------
-----------------------------STEP 1.3 Loading Lead lost reasons for CDMS data----------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------*/ 
declare @ASM_CV_ENQUIRY_LOST_REASON_loaddate date;
set @ASM_CV_ENQUIRY_LOST_REASON_loaddate=CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_CV_ENQUIRY_LOST_REASON)AS DATE);
INSERT INTO ASM_CV_ENQUIRY_LOST_REASON
SELECT DISTINCT 
	EH.HEADERID,
	EH.DOCDATE,
	LBRP.VALUENAME AS PRIMARY_REASON,
	LBRS.VALUENAME AS SECONDARY_REASON,
	EH.IMPORTEDDATE,
	DATEADD(mi,30,(DATEADD(hh,5,getdate()))) AS CREATEDDATETIME, -- UTC_TO_IST_Changes_needed?
	ISNULL((Case When LBRS.VALUENAME IS NOT NULL AND LBRS.VALUENAME IS NOT NULL THEN 1 ELSE 0 END),0) AS Reason_Exist
FROM
	ENQUIRY_HEADER EH 
	JOIN COMPANY_MASTER CM 
	ON EH.COMPANYID=CM.COMPANYID 
	And CM.COMPANYTYPE=7
	
	JOIN LOSTBY_REASON_DATA LBRP 
	ON LBRP.VALUEID = EH.LOSTREASON1 
	AND LBRP.MASTERID =(
						CASE 
						WHEN IsNull(EH.LostByFinance,0) = 1 THEN 1030062 
						WHEN IsNull(EH.LostByProduct,0) = 1 THEN 1030063
						WHEN IsNull(EH.LostByChannel,0) = 1 THEN 1030065
						WHEN IsNull(EH.LostByOthers,0) = 1 THEN 1051369 
						END  
						)
	LEFT OUTER JOIN LOSTBY_REASON_DATA LBRS 
	ON LBRS.VALUEID = EH.LOSTREASON2 
	AND LBRS.MASTERID =(
						CASE 
						WHEN IsNull(EH.LostByFinance,0) = 1 THEN 1030062 
						WHEN IsNull(EH.LostByProduct,0) = 1 THEN 1030063
						WHEN IsNull(EH.LostByChannel,0) = 1 THEN 1030065
						WHEN IsNull(EH.LostByOthers,0) = 1 THEN 1051369
						END
						) 
	WHERE 

CAST(EH.IMPORTEDDATE AS DATE) >= @ASM_CV_ENQUIRY_LOST_REASON_loaddate  



Update ED
Set ED.Lost_Primary_Reason=EL.PRIMARY_REASON, ED.Lost_Secondary_Reason=EL.SECONDARY_REASON,
ED.Reason_Exist=EL.Reason_Exist
From ASM_CV_ENQUIRY_DIM_CDMS_STG ED JOIN ASM_CV_ENQUIRY_LOST_REASON EL  ON (ED.PK_EnquiryHeaderID=EL.HEADERID);


/* ------------------------------------------------------------------------------------------------------------------------------------
---------------------------STEP 1.4 Loading LSQ data into LSQ stage table (Dimension)--------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------*/ 
declare @ASM_CV_ENQUIRY_DIM_LSQ_STG_loaddate date;
set @ASM_CV_ENQUIRY_DIM_LSQ_STG_loaddate=CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_CV_ENQUIRY_DIM_LSQ_STG)AS DATE);
INSERT INTO ASM_CV_ENQUIRY_DIM_LSQ_STG
SELECT DISTINCT
	LSQ_PBASE.ProspectId AS PK_EnquiryHeaderID,
	LTRIM(CAST(DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))AS DATE),10) AS EnquiryDate,
	ISNULL(LSQ_PBASE.MX_ENQUIRY_MODE, LSQ_PBASE.mx_Mode_of_Enquiry) AS EnquiryMedium,
	LSQ_PBASE.mx_Source_Of_Enquiry AS EnquiryLeadSource, 
	CASE WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('BOOKED','ALLOCATED') THEN 'Booked'
	WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('INVOICED','DELIVERED') THEN 'Invoiced'
	WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER','LOST TO CO-DEALER/CO- BRANCH') THEN 'Lost' 
	WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('VISITED' ,'CONTACTED' ,'OPEN' ,'TEST RIDE CANCELLED' ,'QUALIFIED' ,'PROSPECT' ,'TEST RIDE COMPLETED' ,'TEST RIDE BOOKED' ,'TEST RIDE RESCHEDULED') THEN 'Open'  END AS EnquiryStatus, 
	CASE WHEN LSQ_TESTRIDE.RelatedProspectID IS NOT NULL THEN 'Yes' else 'No' END AS IsTestRideTaken ,
    Null AS TestRideOffered,
	LSQ_PBASE.mx_type_of_customer AS CustomerOwnershipProfileId ,
	LSQ_PBASE.mx_payment_mode AS ModeOfPurchase,
	LSQ_PBASE.mx_Enquiry_Sub_source AS EnquirySubsource,  
	Case when UPPER(LSQ_PBASE.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER','LOST TO CO-DEALER/CO- BRANCH') then  LSQ_PBASE.ProspectStage END AS LeadLostReason, 
	LSQ_PACTEXTBASE.mx_Custom_67  AS PrimaryUsage, 
	LSQ_PBASE.mx_Enquiry_Classification AS LEADCLASSIFICATIONTYPE,
	CAST(Null AS INT) as LostByFinance, 
	CAST(Null AS INT) as LostByChannel,  
	CAST(Null AS INT) as LostByProduct, 
	Case when Upper(LSQ_PBASE.ProspectStage)='LOST TO COMPETITION' then 'Yes' END  as LostToCompetition,  
	CAST(Null AS INT) as LostByOthers,  
	'' as LostByCategory,
	DATEADD(mi,30,(DATEADD(hh,5,GETDATE()))) AS CREATEDDATETIME,
	DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.ModifiedOn))) As IMPORTEDDATE,	
	CAST(Null AS INT) as CDMS_BATCHNO, 
	CASE WHEN FIRST_FOLLOWUP.RelatedProspectID is Not null then 'Yes' Else 'No' END AS EnquiryFollowUp,
	ISNULL(LSQ_PBASE.MX_ENQUIRY_MODE, LSQ_PBASE.mx_Mode_of_Enquiry) AS LEADTYPE, 
	LSQ_PBASE.mx_Source_Of_Enquiry AS SourceType, 
	CASE WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('BOOKED','ALLOCATED') THEN 'Booked'
	WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('INVOICED','DELIVERED') THEN 'Invoiced'
	WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER') THEN 'Lost' 
	WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('VISITED' ,'CONTACTED' ,'OPEN' ,'TEST RIDE CANCELLED' ,'QUALIFIED' ,'PROSPECT' ,'TEST RIDE COMPLETED' ,'TEST RIDE BOOKED' ,'TEST RIDE RESCHEDULED') THEN 'Open' END AS LEADSTATUS, 
	LSQ_PBASE.ProspectStage AS Lost_To_Competition_Others,
	'NA' AS Lost_Category, 
	Cast('' as varchar(50)) As Lost_Primary_Reason,
	Cast('' as varchar(50)) As Lost_Secondary_Reason,
	NULL AS FinanceCompany, 
	NULL AS LostToOEM, 
	Cast(0 as int) As RetailConversionFlag, 
	LSQ_PBASE.mx_Exchange AS IsExchangeApplicable,
	LSQ_PACTEXTBASE.mx_Custom_70 AS USAGEDETAILS,
	LSQ_PBASE.mx_area AS Area,
	Cast(0 as int) As Reason_Exist, 
	1 AS BaseFlag,
	CASE WHEN LSQ_PBASE.mx_type_of_customer is Not Null  THEN 'Yes' ELSE 'No' END AS IsNeedsAssessment,
    CASE WHEN LSQ_Sales_Demo.mx_Custom_1='Yes' THEN 'Yes' ELSE 'No' END AS IsDemo,
    CASE WHEN LSQ_PEXTBASE.mx_Visited = 'Yes' THEN 'Yes' ELSE 'No' END AS IsVisited,
    LSQ_PBASE.Mx_pincode as Pincode, 
    U.FirstName as Sales_Person,	
	DATEADD(mi,30,(DATEADD(hh,5,FIRST_FOLLOWUP.FirstFollowupDate))) as FirstFollowupDate,
	Case WHEN FIRST_FOLLOWUP.FirstIsCustomerContacted In('Yes','No') Then 'Yes' Else 'No' END  AS FirstIsCustomerContacted,
	DATEADD(mi,30,(DATEADD(hh,5,FIRST_FOLLOWUP.FirstFollowupScheduleDate))) AS FirstFollowupScheduleDate,
	DATEADD(mi,30,(DATEADD(hh,5,LATEST_FOLLOWUP.LatestFollowupDate))) as LatestFollowupDate,
	DATEADD(mi,30,(DATEADD(hh,5,LATEST_FOLLOWUP.LatestFollowupScheduleDate))) as LatestFollowupScheduleDate,
    LATEST_FOLLOWUP.LatestIsCustomerContacted,
    CASE WHEN CAST( DATEDIFF(hour, LSQ_PEXTBASE.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) <3 THEN  '<3 Hrs'
    WHEN CAST( DATEDIFF(hour, LSQ_PEXTBASE.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) BETWEEN 3 AND 24 THEN '3-24 Hrs'
    WHEN CAST( DATEDIFF(hour, LSQ_PEXTBASE.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) >24 then '>24 Hrs'  End as FollowupBucket,
    NULL as LeadLostSecondaryReason ,
    COALESCE (LATEST_FOLLOWUP.mx_custom_14, LATEST_FOLLOWUP.mx_custom_15,FIRST_FOLLOWUP.mx_custom_14, FIRST_FOLLOWUP.mx_custom_15) AS  FollowupLatestDisposition,
    FIRST_FOLLOWUP.Nooffollowups AS NO_OF_FOLLOWUPS,
		 CASE WHEN LSQ_PBASE.ProspectStage IN ('Open','Qualified','Contacted','Test Ride Booked',
                           'Test Ride Cancelled','Test Ride Rescheduled' ,'Visited' ,
						   'Sales Demo','Test Ride Completed','Finance' ,'Exchange',
						   'Booking in progress','Booking failed','Booking InProgress')	THEN 'Open' 
	WHEN LSQ_PBASE.ProspectStage = 'Booked' THEN 'Booked'
	WHEN LSQ_PBASE.ProspectStage = 'Invoiced' THEN 'Invoiced'
	WHEN LSQ_PBASE.ProspectStage IN('Lost','Closed','Auto','Lost to Co-Dealer','Lost to Competition','Lost to Co-Dealer/Co- Branch','Auto - Closed') THEN 'Closed' END  ENQUIRY_STAGE,
     LSQ_PACTEXTBASE.mx_Custom_2 AS OPPORTUNITY_STATUS,
    COALESCE(LSQ_PBASE.mx_Financing, LSQ_PBASE.mx_Reason_for_Choosing_Competition) AS REASON_FOR_CHOOSING_COMPETITION ,
     LSQ_PEXT2BASE.mx_Is_any_Follow_up_overdue AS IS_ANY_FOLLOWUP_OVERDUE,
     LSQ_PBASE.Origin AS ENQUIRY_ORIGIN,
	 LSQ_PEXTBASE.mx_Competition_Brand_Followup as COMPETITION_BRAND,
	 LSQ_PEXTBASE.mx_Competition_Model_Followup as COMPETITION_MODE 
FROM
  LSQ_Prospect_Base LSQ_PBASE 
  
  LEFT  JOIN LSQ_Prospect_ExtensionBase LSQ_PEXTBASE 
  ON (LSQ_PBASE.ProspectId = LSQ_PEXTBASE.ProspectId)
 
  INNER JOIN LSQ_ProspectActivity_ExtensionBase LSQ_PACTEXTBASE 
  ON (LSQ_PBASE.ProspectId = LSQ_PACTEXTBASE.RelatedProspectID) 
  AND LSQ_PACTEXTBASE.ActivityEvent=12003 

--------------- FIRST FOLLOWUP----------------

LEFT JOIN (SELECT RelatedProspectID,FirstfollowupDate, FirstIsCustomerContacted,FirstFollowupScheduleDate,mx_custom_14,mx_custom_15, Nooffollowups FROM (
select RelatedProspectID,mx_Custom_13 FirstIsCustomerContacted,mx_custom_3 as FirstFollowupScheduleDate,
createdon FirstfollowupDate, mx_custom_14 , mx_custom_15,
ROW_NUMBER()OVER(PARTITION BY RelatedProspectID ORDER BY CREATEDON ASC) AS RNK,
ROW_NUMBER() OVER(PARTITION BY RelatedProspectID ORDER BY CREATEDON DESC) AS Nooffollowups
from LSQ_ProspectActivity_ExtensionBase 
where ActivityEvent=213
and mx_Custom_13 is not null ) A where RNK=1
) FIRST_FOLLOWUP
ON FIRST_FOLLOWUP.RelatedProspectID=LSQ_PBASE.ProspectId
--AND FIRST_FOLLOWUP.FirstFollowupDate>LSQ_PEXTBASE.mx_dealer_assignment_Date

AND DATEADD(mi,30,(DATEADD(hh,5,FIRST_FOLLOWUP.FirstFollowupDate))) > DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))
 

---------------LATEST FOLLOWUP ------------------------------------------
LEFT JOIN (SELECT RelatedProspectID,LatestFollowupDate, LatestIsCustomerContacted,LatestFollowupScheduleDate,mx_custom_14,mx_custom_15 FROM (
select RelatedProspectID,mx_Custom_13 LatestIsCustomerContacted,mx_custom_3 as LatestFollowupScheduleDate,
createdon LatestFollowupDate,mx_custom_14 , mx_custom_15,
ROW_NUMBER()OVER(PARTITION BY RelatedProspectID ORDER BY CREATEDON DESC) AS RNK 
from LSQ_ProspectActivity_ExtensionBase 
where ActivityEvent=213
and mx_Custom_13 is not null ) B where RNK=1
)LATEST_FOLLOWUP
ON LATEST_FOLLOWUP.RelatedProspectID=LSQ_PBASE.ProspectId

--AND LATEST_FOLLOWUP.LatestFollowupDate> LSQ_PEXTBASE.mx_dealer_assignment_Date       
AND DATEADD(mi,30,(DATEADD(hh,5,LATEST_FOLLOWUP.LatestFollowupDate)))> DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))


 -------TestRIDE Logic------------------------------------------------------
 LEFT JOIN (select RelatedProspectID, ROW_NUMBER() OVER (PARTITION BY RelatedProspectID ORDER BY createdon DESC) AS RANK1
  from 
  LSQ_ProspectActivity_ExtensionBase 
  where ActivityEvent =202
  and  Status='Completed'
  )LSQ_TESTRIDE
  ON LSQ_TESTRIDE.RelatedProspectID=LSQ_PBASE.ProspectId
  AND LSQ_TESTRIDE.RANK1=1
  
  -------Sales_Demo Logic------------------------------------------------------
  LEFT JOIN (select RelatedProspectID, mx_Custom_1, ROW_NUMBER() OVER (PARTITION BY RelatedProspectID ORDER BY createdon DESC) AS RANK2 
  from 
  LSQ_ProspectActivity_ExtensionBase 
  where ActivityEvent = 231
  --and mx_Custom_1='Yes'  
  )LSQ_Sales_Demo
  ON LSQ_Sales_Demo.RelatedProspectID=LSQ_PBASE.ProspectId
  AND LSQ_Sales_Demo.RANK2=1
  
 LEFT JOIN LSQ_Prospect_Extension2Base LSQ_PEXT2BASE 
 ON LSQ_PEXT2BASE.ProspectId=LSQ_PBASE.PROSPECTID
 
 LEFT JOIN LSQ_users U on LSQ_PBASE.OwnerId=U.UserID
  
WHERE LSQ_PEXTBASE.mx_Dealer_Assignment_Date is not null
AND CAST(DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.ModifiedOn))) AS DATE) >= @ASM_CV_ENQUIRY_DIM_LSQ_STG_loaddate
   
-- Delete from ASM_CV_ENQUIRY_DIM_LSQ_STG Where Cast(EnquiryDate as date)>Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate()))) - 1 as date) --- UTC_TO_IST_Changes_needed? -- extra line present in the MC SP added it here. Need confirmation


--Dedup Process:
  ;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_EnquiryHeaderID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_CV_ENQUIRY_DIM_LSQ_STG                  
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1; 

/* ------------------------------------------------------------------------------------------------------------------------------------
---------------STEP 1.5 UNION of CMDS Stage and LSQ Stage tables and load into ASM_CV_ENQUIRY_DIM--------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------*/ 

--Truncate table ASM_CV_ENQUIRY_DIM
INSERT INTO ASM_CV_ENQUIRY_DIM
	    
	SELECT DISTINCT
	[PK_EnquiryHeaderID] ,
	[EnquiryDate] ,
	[EnquiryMedium] ,
	[EnquiryLeadSource] ,
	[EnquiryStatus] ,
	[IsTestRideTaken] ,
	[TestRideOffered] ,
	[CustomerOwnershipProfileId] ,
	[ModeOfPurchase] ,
	[EnquirySubsource] ,
	[LeadLostReason] ,
	[PrimaryUsage] ,
	[LEADCLASSIFICATIONTYPE] ,
	[LostByFinance] ,
	[LostByChannel] ,
	[LostByProduct] ,
	[LostToCompetition] ,
	[LostByOthers] ,
	[LostByCategory] ,
	[CREATEDDATETIME] ,
	[IMPORTEDDATE] ,
	[CDMS_BATCHNO] ,
	[EnquiryFollowUp] ,
	[LeadType] ,
	[SourceType] ,
	[LeadStatus] ,
	[Lost_To_Competition_Others] ,
	[Lost_Category] ,
	[Lost_Primary_Reason] ,
	[Lost_Secondary_Reason] ,
	[FinanceCompany] ,
	[LostToOEM] ,
	[RetailConversionFlag] ,
	[IsExchangeApplicable],
	[USAGEDETAILS] ,
	[Area] ,
	[Reason_Exist] ,
	[BaseFlag]
	,[ISNEEDSASSESSMENT]
	,[ISDEMO]
	,[ISVISITED]
	,[PINCODE] 
	,[SALES_PERSON] 
	,[FIRSTFOLLOWUPDATE]  
	,[FIRSTISCUSTOMERCONTACTED] 
	,[FOLLOWUPSCHEDULEDATE1] 
	,[LATESTFOLLOWUPDATE] 
	,[LATESTFOLLOWUPSCHEDULEDATE]
	,[LATESTISCUSTOMERCONTACTED]
	,[FollowupBucket]
  ,[LeadLostSecondaryReason],
  [FollowupLatestDisposition],
  [NO_OF_FOLLOWUPS],
    [ENQUIRY_STAGE],
	[OPPORTUNITY_STATUS],
	[REASON_FOR_CHOOSING_COMPETITION] ,
	[IS_ANY_FOLLOWUP_OVERDUE],
  	[ENQUIRY_ORIGIN],
	[COMPETITION_BRAND],
    [COMPETITION_MODEL]
    FROM ASM_CV_ENQUIRY_DIM_CDMS_STG
	
	UNION
	
	SELECT DISTINCT
	[PK_EnquiryHeaderID] ,
	[EnquiryDate] ,
	[EnquiryMedium] ,
	[EnquiryLeadSource] ,
	[EnquiryStatus] ,
	[IsTestRideTaken] ,
	[TestRideOffered] ,
	[CustomerOwnershipProfileId] ,
	[ModeOfPurchase] ,
	[EnquirySubsource] ,
	[LeadLostReason] ,
	[PrimaryUsage] ,
	[LEADCLASSIFICATIONTYPE] ,
	[LostByFinance] ,
	[LostByChannel] ,
	[LostByProduct] ,
	[LostToCompetition] ,
	[LostByOthers] ,
	[LostByCategory] ,
	[CREATEDDATETIME] ,
	[IMPORTEDDATE] ,
	[CDMS_BATCHNO] ,
	[EnquiryFollowUp] ,
	[LeadType] ,
	[SourceType] ,
	[LeadStatus] ,
	[Lost_To_Competition_Others] ,
	[Lost_Category] ,
	[Lost_Primary_Reason] ,
	[Lost_Secondary_Reason] ,
	[FinanceCompany] ,
	[LostToOEM] ,
	[RetailConversionFlag] ,
	[IsExchangeApplicable],
	[USAGEDETAILS] ,
	[Area] ,
	[Reason_Exist] ,
	[BaseFlag] 
	,[ISNEEDSASSESSMENT]
	,[ISDEMO]
	,[ISVISITED]
	,[PINCODE] 
	,[SALES_PERSON] 
	,[FIRSTFOLLOWUPDATE]  
	,[FIRSTISCUSTOMERCONTACTED] 
	,[FOLLOWUPSCHEDULEDATE1] 
	,[LATESTFOLLOWUPDATE] 
	,[LATESTFOLLOWUPSCHEDULEDATE]
	,[LATESTISCUSTOMERCONTACTED]
	,[FollowupBucket]
    ,[LeadLostSecondaryReason],
     [FollowupLatestDisposition],
     [NO_OF_FOLLOWUPS],
	 [ENQUIRY_STAGE],
	[OPPORTUNITY_STATUS],
	[REASON_FOR_CHOOSING_COMPETITION] ,
	[IS_ANY_FOLLOWUP_OVERDUE],
  	[ENQUIRY_ORIGIN],
	[COMPETITION_BRAND],
    [COMPETITION_MODEL]
    FROM ASM_CV_ENQUIRY_DIM_LSQ_STG
	

	--Dedup Process:
  ;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_EnquiryHeaderID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_CV_ENQUIRY_DIM                  
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1; 

/*TEST select count(*) from ASM_CV_ENQUIRY_DIM_CDMS_STG; --7956185
select count(*) from ASM_CV_ENQUIRY_DIM_LSQ_STG; --6776
select count(*) from ASM_CV_ENQUIRY_DIM; --0*/--7962961
/**************************************************************************************************************************************/	
/********************************** STEP 2: LOADING ENQUIRY FACT (ENQUIRY TRANSACTIONS) DATA ******************************************/
/**************************************************************************************************************************************/

/* ------------------------------------------------------------------------------------------------------------------------------------
---------------------------STEP 2.1 LOAD CDMS Data into Enquiry Fact (Copy from main script)-------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------*/
declare @ASM_CV_ENQUIRY_STG_loaddate date;
set @ASM_CV_ENQUIRY_STG_loaddate=CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_CV_ENQUIRY_STG)AS DATE);
INSERT INTO ASM_CV_ENQUIRY_STG
SELECT DEALERCODE, 
SKU,
FK_DEALERCODE, 
FK_SKU,  
FK_TYPE_ID,
DATE,
ENQUIRYLINEID,
FK_ENQUIRYDOCID,
COMPANYTYPE,
BRANCHID,
TEHSILID,
SALES_PERSON,
Isnull(Count(HEADERID),0) as ACTUALQUANTITY ,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
CDMS_BATCHNO ,
TARGETQUANTITY,
PERIODNAME
,COLOUR_CODE, 
MODELCODE, 
FK_MODEL,FLAG, 
BaseFlag,
LeadType,
NULL AS Campaign_Code	
 from (	   
 SELECT 
   DISTINCT
   CM.CODE AS DEALERCODE, 
   IM.CODE+IV.CODE As SKU, 
   Cast(0 as int) as FK_DEALERCODE, 
   Cast(0 as int) as FK_SKU,  
   10001 As FK_TYPE_ID, 
   Cast(EH.DOCDATE As Date) As DATE, 
   EL.LINEID as ENQUIRYLINEID, 
   EL.DOCID as FK_ENQUIRYDOCID,  
   CM.COMPANYTYPE AS COMPANYTYPE, 
   EH.BRANCHID,
   EH.ADTEHSILID AS TEHSILID,
   CONCAT(TRIM(CN.FIRSTNAME),' ',TRIM(CN.LASTNAME)) AS SALES_PERSON,
   EH.HEADERID , 
   DATEADD(mi,30,(DATEADD(hh,5,getdate()))) as LASTUPDATEDDATETIME, --UTC_TO_IST_Changes_needed?
   EH.IMPORTEDDATE, 
   EH.CDMS_BATCHNO, 
   Cast(0 as decimal(19,0)) As TARGETQUANTITY, 
   (LEFT(DATENAME( MONTH,EH.DOCDATE),3)+'-'+Cast(Year(EH.DOCDATE) as varchar(4))) As PERIODNAME, 
   IV.CODE As COLOUR_CODE, 
   IM.CODE As MODELCODE,
   Cast(0 as int) as FK_MODEL, 
   100011 As FLAG,
   0 as BaseFlag,
   ISNULL(EH.LEADTYPE,'KAM') AS LeadType  
				   
   
FROM 
   ENQUIRY_HEADER EH INNER JOIN COMPANY_MASTER CM ON (EH.COMPANYID=CM.COMPANYID AND CM.COMPANYTYPE = 7)
   LEFT JOIN CONTACT_MASTER CN ON (EH.OWNERCONTACTID = CN.CONTACTID AND CN.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CN.CONTACTID = CN1.CONTACTID))
   INNER JOIN ENQUIRY_LINE EL ON (EH.HEADERID=EL.DOCID)
   JOIN ITEM_MASTER IM ON (IM.ItemId=EL.ItemID) 
   LEFT JOIN ITEMVARMATRIX_MASTER IV ON (EL.VARMATRIXID=IV.ITEMVARMATRIXID) 
   
WHERE  
CAST(EH.IMPORTEDDATE AS DATE) >= @ASM_CV_ENQUIRY_STG_loaddate
   ) base
GROUP BY 
DEALERCODE, SKU,FK_DEALERCODE, FK_SKU,  FK_TYPE_ID,DATE,ENQUIRYLINEID,
 FK_ENQUIRYDOCID,COMPANYTYPE,BRANCHID,TEHSILID,SALES_PERSON,LASTUPDATEDDATETIME,IMPORTEDDATE,CDMS_BATCHNO ,TARGETQUANTITY,PERIODNAME
,COLOUR_CODE, MODELCODE, FK_MODEL,FLAG, BaseFlag,LeadType;

--

Delete from ASM_CV_ENQUIRY_STG Where DATE>Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate())))-1 as date)---UTC_TO_IST_Changes_needed

--Dedup Process:
  ;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_ENQUIRYDOCID,ENQUIRYLINEID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_CV_ENQUIRY_STG                 
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;  


  --*****************************************************
  --*******************************************************
  --Step 2:
--Product Master and Dealer Master FK update: ASM_CV_ENQUIRY_STG
update B set B.FK_SKU=C.PK_SKU from ASM_CV_ENQUIRY_STG B INNER JOIN ASM_CV_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_CV_ENQUIRY_STG B INNER JOIN ASM_CV_PRODUCT_DIM C on (B.MODELCODE=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].[ASM_CV_ENQUIRY_STG] B INNER JOIN ASM_CV_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)

--********************************************************************
--Step 3:
TRUNCATE TABLE ASM_CV_ENQUIRY_TARGET
INSERT INTO ASM_CV_ENQUIRY_TARGET
(DEALERCODE, SKU, FK_DEALERCODE, FK_SKU, FK_TYPE_ID, DATE, ENQUIRYLINEID, FK_ENQUIRYDOCID, COMPANYTYPE, BRANCHID, TEHSILID, SALES_PERSON,
ACTUALQUANTITY, LASTUPDATEDDATETIME, IMPORTEDDATE, CDMS_BATCHNO, TARGETQUANTITY, PERIODNAME, COLOUR_CODE, MODELCODE, FK_MODEL, FLAG, BaseFlag,
LEADTYPE, Campaign_Code)
SELECT DISTINCT
DEALERCODE
,Cast('' as varchar(50)) As SKU
,Cast('' as int) as FK_DEALERCODE
,Cast('' as int) as FK_SKU
,10001 As FK_TYPE_ID
--,Cast(null As Date) As DATE
,Cast(convert(datetime, replace(PERIODNAME, '-', ' ')) as date) As DATE
,Cast(null as decimal(19,0)) As ENQUIRYLINEID
,Cast(null as decimal(19,0)) As FK_ENQUIRYDOCID
,Cast(null as decimal(19,0)) As COMPANYTYPE
,Cast(null as decimal(19,0)) As BRANCHID
,Cast(null as decimal(19,0)) As TEHSILID
,Cast('' as varchar(50)) As SALES_PERSON
,Cast(null as decimal(10,0)) As ACTUALQUANTITY
,DATEADD(mi,30,(DATEADD(hh,5,getdate()))) as LASTUPDATEDDATETIME -- UTC_TO_IST_Changes_needed?
,IMPORTEDDATE
,CDMS_BATCHNO
,Round(Sum(ENQUIRYTARGET),0) As TARGETQUANTITY
,PERIODNAME
,Cast('' as varchar(25)) As COLOUR_CODE
,MODELCODE
,Cast(null as int) As FK_MODEL
,100012 As FLAG
,0 AS BaseFlag
,'KAM' as LEADTYPE 
,NULL AS Campaign_Code								   
--INTO ASM_CV_ENQUIRY_TARGET
FROM
TARGET_SALES_3W	Where Cast(convert(datetime, replace(PERIODNAME, '-', ' ')) as date)<Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate()))) As date)-- UTC_TO_IST_Changes_needed?
GROUP BY
DEALERCODE,
IMPORTEDDATE,
CDMS_BATCHNO,
PERIODNAME,
MODELCODE


-----------------LSQ---------------------------


SELECT CAST(userID AS VARCHAR(36)) AS userID,CAST(TemplateId AS VARCHAR(36)) AS TemplateId , CAST(RecurrenceId AS VARCHAR(36)) as RecurrenceId, CAST(RecurrenceStartDate AS DATE) as RecurrenceStartDate,
    CAST(RecurrenceEndDate AS DATE) as RecurrenceEndDate , CAST(RecurrenceStatus AS VARCHAR(36)) as RecurrenceStatus, 
	CAST(dealer_code AS VARCHAR(36)) as dealer_code, 
	CAST(branch AS VARCHAR(36))  as branch, 
	CAST(Firstname AS VARCHAR(36))  as Firstname, 
	CAST(PhoneMobile AS VARCHAR(36))  as PhoneMobile,
	CAST(Designation AS VARCHAR(36))  as Designation, 
	ISNULL(SUM(TRY_CAST(Target AS DECIMAL(10,2))), 0) AS Target, CAST(TeamTarget AS VARCHAR(36)) as TeamTarget,
	CAST(SubGoalCondition AS VARCHAR(36))  as SubGoalCondition, CAST(Subgoal AS VARCHAR(36)) as Subgoal
INTO #LSQTargetENQ --LSQTargettemp 
FROM 
(SELECT TR.*, Designation, mx_Custom_2 AS branch, mx_Custom_5 AS BU, mx_Custom_10 AS dealer_code, Firstname,PhoneMobile FROM (SELECT TemplateId, RecurrenceId, userID, SubGoalCondition, SUM(TRY_CAST(Target AS DECIMAL(10,2))) AS Target,TeamTarget,
RecurrenceStartDate, RecurrenceEndDate, RecurrenceStatus, Subgoal FROM LSQ_TARGET_DISTRIBUTION_DATA
 WHERE TemplateId = '5d01a5fc-0023-4e68-b85e-c6dc794454b7' 
 /*and RecurrenceId in ('15f1f5e8-faea-4018-9dcb-1b8d2245b996', 'e06542f6-1229-4fcf-8753-0bb1947b66f7', 'a0b1489f-51d9-4dc9-9a34-7750b3ab022d', '457041f5-ebd6-4750-ac47-63dd9e798711', 'eefdb943-dfce-47c1-88e7-1f501d0e4b7d', '9d180dc3-5440-47d5-9854-11ffba54b7c5', '08253de6-7a2e-4f30-98ec-58f521493009', '95d357ae-3f27-4882-83a1-34cede0792ef', '40514481-ff52-4c49-805d-84490d5ecc5e', '974450b2-457a-4a0c-86f3-199f5e8c8101', '262cf96d-81c6-4c40-82ea-1279c9a3f083'
)*/
 GROUP BY TemplateId, RecurrenceId, userID, RecurrenceStartDate, RecurrenceEndDate, RecurrenceStatus, TeamTarget,
 SubGoalCondition, Subgoal) TR 
 JOIN LSQ_Users LS ON LS.userID = TR.userID 
 WHERE mx_Custom_5 = 'CV' --AND Designation IN ('DSE', 'Sales Manager', 'M', 'GM')
 ) a 
 GROUP BY TemplateId, RecurrenceId, RecurrenceStartDate, RecurrenceEndDate, RecurrenceStatus, dealer_code, branch, Designation, userID, TeamTarget,
 Firstname, PhoneMobile, SubGoalCondition, Subgoal;
 
 
INSERT INTO ASM_CV_ENQUIRY_TARGET
SELECT  
DEALERCODE,
SKU,
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
DATE,
ENQUIRYLINEID,
FK_ENQUIRYDOCID,
COMPANYTYPE,
BRANCHID,
TEHSILID,
SALES_PERSON,
ACTUALQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
CDMS_BATCHNO,
TARGETQUANTITY,
PERIODNAME,
COLOUR_CODE,
MODELCODE,
FK_MODEL,
FLAG,
BaseFlag,
Leadtype,
Campaign_Code,
Salesperson_id,
Designation,
recurrence_id,
Subgoal,
PhoneMobile, Model, TeamTarget
from(
SELECT 
dealer_code as  DEALERCODE
,CAST('' AS VARCHAR(50)) AS SKU
,CAST('' AS INT) AS FK_DEALERCODE
,CAST('' AS INT) AS FK_SKU
,10001 AS FK_TYPE_ID
,RecurrenceStartDate AS DATE  ----------Convert
,TemplateId  AS ENQUIRYLINEID  --null  AS RETAILLINEID  --TemplateId
,Null AS FK_ENQUIRYDOCID   --null  AS FK_RETAILDOCID   --RecurrenceId
,CAST(NULL AS DECIMAL(19,0)) AS COMPANYTYPE
,BM.Branchid AS BRANCHID
,CAST(NULL AS DECIMAL(19,0)) AS TEHSILID
,Firstname AS SALES_PERSON
,CAST(NULL AS DECIMAL(10,0)) AS ACTUALQUANTITY
,GETDATE() AS LASTUPDATEDDATETIME
,null as IMPORTEDDATE
,null as CDMS_BATCHNO
,ISNULL(TRY_CAST(Target AS DECIMAL(10,2)), 0) AS TARGETQUANTITY
,null as PERIODNAME
,CAST('' AS VARCHAR(25)) AS COLOUR_CODE
,P.MODELCODE
,CAST(NULL AS INT) AS FK_MODEL
,100013 As FLAG
,0 AS BaseFlag
,'KAM' as LEADTYPE 
,NULL AS Campaign_Code 
,userID as Salesperson_id
,Designation as Designation
,RecurrenceId as recurrence_id,
Subgoal as Subgoal,
PhoneMobile as PhoneMobile,
LTRIM(RTRIM(REPLACE(LT.Subgoalcondition, 'Brand = ', ''))) as Model, 
TeamTarget
FROM
#LSQTargetENQ LT
left JOIN BRANCH_MASTER BM ON LT.BRANCH=BM.CODE
left JOIN (
    SELECT Model, Modelcode,
    
           ROW_NUMBER() OVER (PARTITION BY finance_category order by Brand ) AS rn
    FROM ASM_CV_PRODUCT_DIM P
) P ON LTRIM(RTRIM(REPLACE(LT.Subgoalcondition, 'Brand = ', ''))) = P.Model

)B


------------------------TESTRIDE TARGET -------------------------------------------

SELECT CAST(userID AS VARCHAR(36)) AS userID,CAST(TemplateId AS VARCHAR(36)) AS TemplateId , CAST(RecurrenceId AS VARCHAR(36)) as RecurrenceId, CAST(RecurrenceStartDate AS DATE) as RecurrenceStartDate,
    CAST(RecurrenceEndDate AS DATE) as RecurrenceEndDate , CAST(RecurrenceStatus AS VARCHAR(36)) as RecurrenceStatus, 
	CAST(dealer_code AS VARCHAR(36)) as dealer_code, 
	CAST(branch AS VARCHAR(36))  as branch, 
	CAST(Firstname AS VARCHAR(36))  as Firstname, 
	CAST(PhoneMobile AS VARCHAR(36))  as PhoneMobile,
	CAST(Designation AS VARCHAR(36))  as Designation, 
	ISNULL(SUM(TRY_CAST(Target AS DECIMAL(10,2))), 0) AS Target, CAST(TeamTarget AS VARCHAR(36)) as TeamTarget,
	CAST(SubGoalCondition AS VARCHAR(36))  as SubGoalCondition, CAST(Subgoal AS VARCHAR(36)) as Subgoal
INTO #LSQTargetTestRide --LSQTargettemp 
FROM 
(SELECT TR.*, Designation, mx_Custom_2 AS branch, mx_Custom_5 AS BU, mx_Custom_10 AS dealer_code, Firstname,PhoneMobile FROM (SELECT TemplateId, RecurrenceId, userID, SubGoalCondition, SUM(TRY_CAST(Target AS DECIMAL(10,2))) AS Target,TeamTarget,
RecurrenceStartDate, RecurrenceEndDate, RecurrenceStatus, Subgoal FROM LSQ_TARGET_DISTRIBUTION_DATA
 WHERE TemplateId = '6281ca46-98cc-4521-9d45-2f1bdfd0e7b4' 

 GROUP BY TemplateId, RecurrenceId, userID, RecurrenceStartDate, RecurrenceEndDate, RecurrenceStatus, TeamTarget,
 SubGoalCondition, Subgoal) TR 
 JOIN LSQ_Users LS ON LS.userID = TR.userID 
 WHERE mx_Custom_5 = 'CV' --AND Designation IN ('DSE', 'Sales Manager', 'M', 'GM')
 ) a 
 GROUP BY TemplateId, RecurrenceId, RecurrenceStartDate, RecurrenceEndDate, RecurrenceStatus, dealer_code, branch, Designation, userID, TeamTarget,
 Firstname,PhoneMobile, SubGoalCondition, Subgoal;
 
 
 
INSERT INTO ASM_CV_ENQUIRY_TARGET
SELECT  
DEALERCODE,
SKU,
FK_DEALERCODE,
FK_SKU,
FK_TYPE_ID,
DATE,
ENQUIRYLINEID,
FK_ENQUIRYDOCID,
COMPANYTYPE,
BRANCHID,
TEHSILID,
SALES_PERSON,
ACTUALQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
CDMS_BATCHNO,
TARGETQUANTITY,
PERIODNAME,
COLOUR_CODE,
MODELCODE,
FK_MODEL,
FLAG,
BaseFlag,
Leadtype,
Campaign_Code,
Salesperson_id,
Designation,
recurrence_id,
Subgoal,
PhoneMobile, Model, TeamTarget
from(
SELECT 
dealer_code as  DEALERCODE
,CAST('' AS VARCHAR(50)) AS SKU
,CAST('' AS INT) AS FK_DEALERCODE
,CAST('' AS INT) AS FK_SKU
,10010 AS FK_TYPE_ID
,RecurrenceStartDate AS DATE  ----------Convert
,TemplateId  AS ENQUIRYLINEID  --null  AS RETAILLINEID  --TemplateId
,Null AS FK_ENQUIRYDOCID   --null  AS FK_RETAILDOCID   --RecurrenceId
,CAST(NULL AS DECIMAL(19,0)) AS COMPANYTYPE
,BM.Branchid AS BRANCHID
,CAST(NULL AS DECIMAL(19,0)) AS TEHSILID
,Firstname AS SALES_PERSON
,CAST(NULL AS DECIMAL(10,0)) AS ACTUALQUANTITY
,GETDATE() AS LASTUPDATEDDATETIME
,null as IMPORTEDDATE
,null as CDMS_BATCHNO
,ISNULL(TRY_CAST(Target AS DECIMAL(10,2)), 0) AS TARGETQUANTITY
,null as PERIODNAME
,CAST('' AS VARCHAR(25)) AS COLOUR_CODE
,P.MODELCODE
,CAST(NULL AS INT) AS FK_MODEL
,100012 As FLAG
,0 AS BaseFlag
,'KAM' as LEADTYPE 
,NULL AS Campaign_Code 
,userID as Salesperson_id
,Designation as Designation
,RecurrenceId as recurrence_id,
Subgoal as Subgoal,
PhoneMobile as PhoneMobile,
LTRIM(RTRIM(REPLACE(LT.Subgoalcondition, 'Brand = ', ''))) as Model,
TeamTarget
FROM
#LSQTargetTestRide LT
left JOIN BRANCH_MASTER BM ON LT.BRANCH=BM.CODE
left JOIN (
    SELECT Model, Modelcode,
    
           ROW_NUMBER() OVER (PARTITION BY finance_category order by Brand ) AS rn
    FROM ASM_CV_PRODUCT_DIM P
) P ON LTRIM(RTRIM(REPLACE(LT.Subgoalcondition, 'Brand = ', ''))) = P.Model

)B



--************************************************************
--Product Master and Dealer Master FK update: ASM_CV_ENQUIRY_TARGET
--Step 4:
update B set B.FK_MODEL=C.PK_Model_Code from ASM_CV_ENQUIRY_TARGET B INNER JOIN ASM_CV_PRODUCT_DIM C on (B.MODELCODE=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from ASM_CV_ENQUIRY_TARGET B INNER JOIN ASM_CV_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)



/* ------------------------------------------------------------------------------------------------------------------------------------
---------------------------STEP 2.2 LOAD LSQ Data into Enquiry Fact LSQ transactions Data----------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------- */
declare @ASM_CV_ENQUIRY_FACT_LSQ_STG_loaddate date;
set @ASM_CV_ENQUIRY_FACT_LSQ_STG_loaddate=CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_CV_ENQUIRY_FACT_LSQ_STG)AS DATE);
INSERT INTO ASM_CV_ENQUIRY_FACT_LSQ_STG

SELECT DEALERCODE, 
SKU,
FK_DEALERCODE, 
FK_SKU,  
FK_TYPE_ID,
DATE,
ENQUIRYLINEID,
FK_ENQUIRYDOCID,
COMPANYTYPE,
BRANCHID,
TEHSILID,
REPLACE(SALES_PERSON,CHAR(160),'') SALES_PERSON,
Isnull(Count(ProspectID),0) as ACTUALQUANTITY ,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
CDMS_BATCHNO ,
TARGETQUANTITY,
PERIODNAME
,COLOUR_CODE, 
MODELCODE, 
FK_MODEL,
FLAG, 
BaseFlag,
LeadType,
Campaign_Code,
PINCODE, 
AREA,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource,
Salesperson_id, PhoneMobile	 
 FROM 
(SELECT
	DISTINCT
	CM.CODE AS DEALERCODE,
	CASE WHEN LSQ_PACTEXTBASE.mx_custom_18 IS NULL THEN COALESCE (LSQ_PACTEXTBASE.mx_Custom_12,(CASE WHEN LSQ_PACTEXTBASE.MX_CUSTOM_25 LIKE '%00%' THEN
    SUBSTRING (LSQ_PACTEXTBASE.MX_CUSTOM_25,1,6)END))  ELSE IM.CODE END +CASE WHEN LSQ_PACTEXTBASE.mx_custom_26 IS NULL AND LSQ_PACTEXTBASE.MX_CUSTOM_25 LIKE '%00%'  THEN SUBSTRING (LSQ_PACTEXTBASE.MX_CUSTOM_25,7,2) ELSE IV.CODE 
	END SKU, 
	Cast(0 as int) as FK_DEALERCODE,
	Cast(0 as int) as FK_SKU,
	10001 As FK_TYPE_ID,
	--Cast(LSQ_PEXTBASE.mx_Dealer_Assignment_Date As Date) As DATE,
	
	DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date))) AS DATE,
	
	LSQ_PACTEXTBASE.ProspectActivityExtensionId as ENQUIRYLINEID,
	LSQ_PBASE.ProspectID as FK_ENQUIRYDOCID,
	7 AS COMPANYTYPE,
	BM.BRANCHID,
	Cast(null as decimal(19,0)) As TEHSILID,
	REPLACE(REPLACE(REPLACE(U.FirstName,' ',' |'),'| ',''),' |',' ') As SALES_PERSON,	
    Isnull((LSQ_PBASE.ProspectID),0) as ProspectID,
	--getdate() as LASTUPDATEDDATETIME,
	DATEADD(mi,30,(DATEADD(hh,5,Getdate()))) AS LASTUPDATEDDATETIME,
	
	--LSQ_PBASE.Modifiedon AS IMPORTEDDATE,
	DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.Modifiedon ))) AS IMPORTEDDATE,
	
	null as CDMS_BATCHNO,
	Cast(0 as decimal(19,0)) As TARGETQUANTITY,
	--(LEFT(DATENAME( MONTH,LSQ_PEXTBASE.mx_Dealer_Assignment_Date),3)+'-'+Cast(Year(LSQ_PEXTBASE.mx_Dealer_Assignment_Date) as varchar(4))) As   	   PERIODNAME,
	 (LEFT(DATENAME( MONTH,DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))),3)+'-'+Cast(Year(DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))) as varchar(4))) As PERIODNAME,
	
	CASE WHEN LSQ_PACTEXTBASE.mx_custom_26 IS NULL AND LSQ_PACTEXTBASE.MX_CUSTOM_25 LIKE '%00%'  THEN SUBSTRING (LSQ_PACTEXTBASE.MX_CUSTOM_25,7,2) ELSE IV.CODE 
	END AS COLOUR_CODE, -- No Mapping
    CASE WHEN LSQ_PACTEXTBASE.mx_custom_18 IS NULL THEN COALESCE (LSQ_PACTEXTBASE.mx_Custom_12,(CASE WHEN LSQ_PACTEXTBASE.MX_CUSTOM_25 LIKE '%00%' THEN
    SUBSTRING (LSQ_PACTEXTBASE.MX_CUSTOM_25,1,6)END))  ELSE IM.CODE END AS ModelCode,
	Cast(0 as int) as FK_MODEL,
	100011 As FLAG,
	1 As BaseFlag
	,ISNULL(LSQ_PBASE.MX_ENQUIRY_MODE, LSQ_PBASE.mx_Mode_of_Enquiry) AS LEADTYPE 
	,LSQ_PEXTBASE.mx_CV_Campaign_Code as Campaign_Code,
	 LSQ_PBASE.MX_PINCODE AS PINCODE, 
     LSQ_PBASE.MX_AREA AS AREA,
    CASE WHEN CAST(LSQ_PEXTBASE.mx_Dealer_Assignment_Date AS DATE)>='2024-12-01' THEN COALESCE(PE.mx_Qualified_First_Source, LSQ_PBASE.mx_Enquiry_Mode,LSQ_PBASE.MX_MODE_OF_ENQUIRY,'Not Available')
    ELSE COALESCE(LSQ_PBASE.mx_Enquiry_Mode, LSQ_PBASE.MX_MODE_OF_ENQUIRY,'KAM') END  AS First_Source_Lead_Type,
    ISNULL(PE.mx_Qualified_Source_of_Enquiry,'Not Available') AS First_Mode_Source,
    ISNULL(PE.mx_Qualified_Sub_Source,'Not Available') AS First_Mode_SubSource,
	  U.Userid AS Salesperson_id,
   U.PhoneMobile as PhoneMobile
															 
			   
FROM
	LSQ_Prospect_Base LSQ_PBASE
	
	INNER JOIN DBO.BRANCH_MASTER BM ON LSQ_PBASE.mx_Branch_Code=BM.CODE
	
	INNER JOIN DBO.COMPANY_MASTER CM ON CM.COMPANYID=BM.COMPANYID
	
	LEFT JOIN LSQ_Prospect_ExtensionBase LSQ_PEXTBASE
	ON (LSQ_PBASE.ProspectId = LSQ_PEXTBASE.ProspectId) 
	
    LEFT JOIN LSQ_Prospect_Extension2Base PE
    ON (LSQ_PBASE.ProspectId = PE.ProspectId) 
	
	INNER JOIN LSQ_ProspectActivity_ExtensionBase LSQ_PACTEXTBASE
	ON (LSQ_PBASE.ProspectId = LSQ_PACTEXTBASE.RelatedProspectID) 

	
	LEFT JOIN ITEM_MASTER IM
	ON cast(IM.ITEMID as VARCHAR(50))=LSQ_PACTEXTBASE.mx_custom_18
	
	LEFT JOIN ITEMVARMATRIX_MASTER IV
	ON cast(IV.ITEMVARMATRIXID as VARCHAR(50))=LSQ_PACTEXTBASE.mx_custom_26
	
	LEFT JOIN LSQ_users U on LSQ_PBASE.OwnerId=U.UserID
	
	WHERE LSQ_PACTEXTBASE.ActivityEvent=12003
	AND LSQ_PEXTBASE.mx_Dealer_Assignment_Date is not null
	
	
	
AND DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.ModifiedOn))) >= @ASM_CV_ENQUIRY_FACT_LSQ_STG_loaddate
	) TMP
	GROUP BY 
DEALERCODE, SKU,FK_DEALERCODE, FK_SKU,  FK_TYPE_ID,DATE,ENQUIRYLINEID,
 FK_ENQUIRYDOCID,COMPANYTYPE,BRANCHID,TEHSILID,SALES_PERSON,LASTUPDATEDDATETIME,IMPORTEDDATE,CDMS_BATCHNO ,TARGETQUANTITY,PERIODNAME
,COLOUR_CODE, MODELCODE, FK_MODEL,FLAG, BaseFlag,LeadType,Campaign_Code, PINCODE, AREA, First_Source_Lead_Type,First_Mode_Source,First_Mode_SubSource,Salesperson_id,
PhoneMobile;





Delete from ASM_CV_ENQUIRY_FACT_LSQ_STG Where DATE>Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate())))-1 as date)  ; -- UTC_TO_IST_Changes_needed?
--Dedup Process:
WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_ENQUIRYDOCID,ENQUIRYLINEID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_CV_ENQUIRY_FACT_LSQ_STG                 
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;  

  --*****************************************************
  --*******************************************************
  --Step 2:
--Product Master and Dealer Master FK update: ASM_CV_ENQUIRY_STG
update B set B.FK_SKU=C.PK_SKU from ASM_CV_ENQUIRY_FACT_LSQ_STG B INNER JOIN ASM_CV_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_CV_ENQUIRY_FACT_LSQ_STG B INNER JOIN ASM_CV_PRODUCT_DIM C on (B.MODELCODE=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].[ASM_CV_ENQUIRY_FACT_LSQ_STG] B INNER JOIN ASM_CV_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)



/* ------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------STEP 2.3  UNION of CDMS and LSQ Data---------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------- */

Truncate table ASM_CV_ENQUIRY_FACT

INSERT INTO ASM_CV_ENQUIRY_FACT( DEALERCODE, SKU, FK_DEALERCODE, FK_SKU, FK_TYPE_ID, DATE, ENQUIRYLINEID, FK_ENQUIRYDOCID, COMPANYTYPE, BRANCHID, TEHSILID, SALES_PERSON, ACTUALQUANTITY, LASTUPDATEDDATETIME, IMPORTEDDATE, CDMS_BATCHNO, TARGETQUANTITY, PERIODNAME, COLOUR_CODE, MODELCODE, FK_MODEL, FLAG, BaseFlag, LEADTYPE, Campaign_Code, Pincode, Area, First_Source_Lead_Type, First_Mode_Source, First_Mode_SubSource, Salesperson_id, Designation, recurrence_id, Subgoal,PhoneMobile, Model,TeamTarget)
SELECT *,Null As Pincode,Null As Area, Null As First_Source_Lead_Type,Null As First_Mode_Source,Null As First_Mode_SubSource, Null As Salesperson_id, Null As Designation, null as Recurrence_id, null as Subgoal, null as PhoneMobile, null as Model, null as TeamTarget FROM ASM_CV_ENQUIRY_STG
UNION
SELECT DEALERCODE, SKU, FK_DEALERCODE, FK_SKU, FK_TYPE_ID, DATE, ENQUIRYLINEID, FK_ENQUIRYDOCID, COMPANYTYPE, BRANCHID, TEHSILID, SALES_PERSON, ACTUALQUANTITY, LASTUPDATEDDATETIME, IMPORTEDDATE, CDMS_BATCHNO, TARGETQUANTITY, PERIODNAME, COLOUR_CODE, MODELCODE, FK_MODEL, FLAG, BaseFlag, LEADTYPE, Campaign_Code, Null as Pincode, Null as  Area,Null as First_Source_Lead_Type,Null as First_Mode_Source, Null as First_Mode_SubSource, Salesperson_id, Designation, recurrence_id, Subgoal,PhoneMobile, Model, TeamTarget
FROM ASM_CV_ENQUIRY_TARGET
UNION						   	 
SELECT DEALERCODE, SKU, FK_DEALERCODE, FK_SKU, FK_TYPE_ID, DATE, ENQUIRYLINEID, FK_ENQUIRYDOCID, COMPANYTYPE, BRANCHID,
    TEHSILID, SALES_PERSON, ACTUALQUANTITY, LASTUPDATEDDATETIME, IMPORTEDDATE, CDMS_BATCHNO, TARGETQUANTITY,
    PERIODNAME, COLOUR_CODE, MODELCODE, FK_MODEL, FLAG, BaseFlag, LEADTYPE, Campaign_Code,
    PINCODE, AREA, First_Source_Lead_Type, First_Mode_Source, First_Mode_SubSource, Salesperson_id
, Null As Designation, null as Recurrence_id,  null as Subgoal,  PhoneMobile, null as Model, null as TeamTarget  FROM ASM_CV_ENQUIRY_FACT_LSQ_STG


/* ------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------STEP 2.4  Update RetailConversionFlag for CDMS-----------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------- */

Update ED
Set ED.RetailConversionFlag=1
FROM ASM_CV_ENQUIRY_DIM ED 
JOIN ENQUIRY_LINE EL ON (ED.PK_EnquiryHeaderID=EL.DOCID)
INNER JOIN BOOKING_LINE BL ON (EL.LINEID=BL.ENQUIRYDATALINEID)
INNER JOIN RETAIL_LINE RL ON (BL.LINEID=RL.BOOKINGDATALINEID) 
WHERE ED.BaseFlag=0 

--- Retail conversion flag update for LSQ ----
Update ED
Set ED.RetailConversionFlag=1
FROM ASM_CV_ENQUIRY_DIM ED 
JOIN  LSQ_Prospect_Base LSQ_PBASE ON (LSQ_PBASE.ProspectId=ED.PK_EnquiryHeaderID)
JOIN  LSQ_ProspectActivity_ExtensionBase PAE ON (LSQ_PBASE.ProspectID=PAE.RelatedProspectId and PAE.ActivityEvent=12003)-- and PAE.mx_Custom_48 IS NULL)--note:commenting this condition because the count of e2r seemed less by this condition
JOIN BOOKING_HEADER_EXT BHE ON (Cast(LSQ_PBASE.ProspectID+','+PAE.ProspectActivityExtensionId as varchar(8000))=BHE.LMSBOOKINGID)
JOIN BOOKING_HEADER BH ON (BH.HEADERID = BHE.HEADERID)
INNER JOIN BOOKING_LINE BL ON (BL.HEADERID=BH.HEADERID)
INNER JOIN RETAIL_LINE RL ON (BL.LINEID=RL.BOOKINGDATALINEID)
WHERE ED.BaseFlag=1
AND LMSBOOKINGID IS NOT NULL;

--- Retail conversion flag update for CDMS ----
Update ED
Set ED.RetailConversionFlag=1
FROM ASM_CV_ENQUIRY_DIM ED JOIN ENQUIRY_LINE EL ON (ED.PK_EnquiryHeaderID=EL.DOCID)
INNER JOIN BOOKING_LINE BL ON (EL.LINEID=BL.ENQUIRYDATALINEID)
INNER JOIN ALLOCATION_LINE AL ON (BL.LINEID=AL.BOOKINGDATALINEID)
INNER JOIN RETAIL_LINE RL ON (AL.LINEID=RL.ALLOCATIONDATALINEID)
WHERE ED.BaseFlag=0

--- Retail conversion flag update for LSQ ----
Update ED
Set ED.RetailConversionFlag=1
FROM ASM_CV_ENQUIRY_DIM ED 
JOIN  LSQ_Prospect_Base LSQ_PBASE ON (LSQ_PBASE.ProspectId=ED.PK_EnquiryHeaderID)
JOIN  LSQ_ProspectActivity_ExtensionBase PAE ON (LSQ_PBASE.ProspectID=PAE.RelatedProspectId and PAE.ActivityEvent=12003 )--and PAE.mx_Custom_48 IS NULL)--note:commenting this condition because the count of e2r seemed less by this condition
JOIN BOOKING_HEADER_EXT BHE ON (Cast(LSQ_PBASE.ProspectID+','+PAE.ProspectActivityExtensionId as varchar(8000))=BHE.LMSBOOKINGID)
JOIN BOOKING_HEADER BH ON (BH.HEADERID = BHE.HEADERID)
INNER JOIN BOOKING_LINE BL ON (BL.HEADERID=BH.HEADERID)
INNER JOIN ALLOCATION_LINE AL ON (BL.LINEID=AL.BOOKINGDATALINEID)
INNER JOIN RETAIL_LINE RL ON (AL.LINEID=RL.ALLOCATIONDATALINEID)
WHERE ED.BaseFlag=1
AND LMSBOOKINGID IS NOT NULL;




END
GO