SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Alter PROC [dbo].[USP_Full_Load_ASM_PB_HKT_ENQUIRY_REFRESH] AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-09-30 	|	Nikita L		| First Source Lead Type column addition                    			*/
/*	2024-10-22 	|	Nikita L		| LSQ-MX_First_Source Addition                    			*/
/*   2024-12-27 	|	Nikita	| MX_QUALIFIED_FIRST_SOURCE Changes 
    2025-03-19	|	Lachmanna		 | First Mode : Source   and subsource   added fact table        */ 
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
--1. Enquiry Dim & Fact:

TRUNCATE TABLE ASM_PB_HK_ENQUIRY_DIM_CDMS_STG
TRUNCATE TABLE ASM_PB_HK_ENQUIRY_DIM_LSQ_STG
TRUNCATE TABLE ASM_PB_HK_ENQUIRY_DIM
TRUNCATE TABLE ASM_PB_HK_ENQUIRY_STG
TRUNCATE TABLE ASM_PB_HK_ENQUIRY_FACT_LSQ_STG
TRUNCATE TABLE ASM_PB_HK_ENQUIRY_FACT
TRUNCATE TABLE ASM_PB_HK_ENQTORET_CONVERSION

/**************************************************************************************************************************************/	
/********************************** STEP 1 : LOADING ENQUIRY DIMENSION TABLE FROM CDMS AND LSQ SOURCES ********************************/
/**************************************************************************************************************************************/

/* ------------------------------------------------------------------------------------------------------------------------------------
----------------------------STEP 1.1 LOADING ASM_PB_ENQUIRY_DIM_CDMS_STG CDMS stage table----------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------*/
--Select top 10 * from ASM_PB_ENQUIRY_DIM_CDMS_STG
--Truncate table ASM_PB_ENQUIRY_DIM_CDMS_STG
INSERT INTO ASM_PB_HK_ENQUIRY_DIM_CDMS_STG
SELECT DISTINCT 
ENQUIRY_HEADER.HEADERID AS PK_EnquiryHeaderID,
Cast(ENQUIRY_HEADER.DOCDATE As Date) As EnquiryDate,
'' AS EnquiryDaysBucket	,
ENQUIRY_HEADER.LEADTYPE AS EnquiryMedium,
ENQUIRY_FOLLOWUP.FollowUp AS EnquiryFollowUp,
SOURCE_OF_ENQUIRY.VALUENAME AS EnquiryLeadSource,  -- Added on 03.11.2022 after discussion had with PBI team.
CASE WHEN ENQUIRY_HEADER.LEADSTATUS='Closed' THEN 'Invoiced' 
when ENQUIRY_HEADER.LEADSTATUS='Lost' THEN 'Closed' 
Else ENQUIRY_HEADER.LEADSTATUS END AS EnquiryStatus,
--ENQUIRY_HEADER.LEADSTATUS AS EnquiryStatus,
case when ENQUIRY_HEADER.TESTRIDEOFFERED='Test Ride Taken' THEN 'Yes' Else 'No' End AS IsTestRideTaken ,
NULL AS TestRideOffered, 
ENQUIRY_HEADER.CUSTOMEROWNERSHIPPROFILEID AS CustomerOwnershipProfileId ,
ENQUIRY_HEADER.MODEOFPURCHASE AS ModeOfPurchase,
ENQUIRY_HEADER.LEADTYPE AS LeadType,
ENQUIRY_HEADER.SOURCETYPE AS SourceType,
SM.[NAME] AS SubSourceOfEnquiry, 
CASE WHEN ENQUIRY_HEADER.LEADSTATUS='Closed' THEN 'Invoiced' 
when ENQUIRY_HEADER.LEADSTATUS='Lost' THEN 'Closed' 
Else ENQUIRY_HEADER.LEADSTATUS END AS LeadStatus,
--ENQUIRY_HEADER.LEADSTATUS AS LeadStatus,
ENQUIRY_HEADER.LEADLOSTREASON AS LeadLostReason,
'' as LostByCategory,
CASE 
   WHEN IsGoodsCarrier=1 THEN 'Cargo' 
   WHEN IsPassengerCarrier=1 THEN 'Passenger' 
END  AS PrimaryUsage,
ENQUIRY_HEADER.LEADCLASSIFICATIONTYPE,
ENQUIRY_HEADER.LostByFinance,
ENQUIRY_HEADER.LostByChannel,
ENQUIRY_HEADER.LostByProduct,
ENQUIRY_HEADER.LostToCompetition,
ENQUIRY_HEADER.LostByOthers,
GETDATE() AS CREATEDDATETIME,
ENQUIRY_HEADER.IMPORTEDDATE,
ENQUIRY_HEADER.CDMS_BATCHNO,
Cast(0 as int) As RetailConversionFlag,
ENQUIRY_HEADER.ISEXCHANGEAPPLICABLE AS IsExchangeApplicable,
ENQUIRY_HEADER.FINANCECOMPANY,  
0 as BaseFlag,
NULL AS IsNeedsAssessment
,NULL AS ISDEMO
,NULL AS ISVISITED 
,NULL AS AREA 
,NULL AS PINCODE 
,NULL AS SALESPERSON 
,NULL AS FIRSTFOLLOWUPDATE  
,NULL AS FIRSTISCUSTOMERCONTACTED 
,'' AS FOLLOWUPSCHEDULEDATE1 
,NULL AS LATESTFOLLOWUPDATE 
,NULL AS LATESTFOLLOWUPSCHEDULEDATE  
,NULL AS LATESTISCUSTOMERCONTACTED
,'' AS FollowupBucket
,NULL AS LeadLostSecondaryReason  
,NULL AS FollowupLatestDisposition 
,Null As ENQUIRY_STAGE
,NULL As OPPORTUNITY_STATUS
,NULL As REASON_FOR_CHOOSING_COMPETITION
,NULL As IS_ANY_FOLLOWUP_OVERDUE
,NULL As ENQUIRY_ORIGIN
,NULL As COMPETITION_BRAND
,NULL As COMPETITION_MODEL
,NULL As Follow_up_Dispositions
FROM
  ENQUIRY_HEADER 
  LEFT JOIN ENQUIRY_HEADER_EXT EHE ON (ENQUIRY_HEADER.HEADERID = EHE.HEADERID)
  LEFT JOIN ENQUIRY_FOLLOWUP ON (ENQUIRY_HEADER.HEADERID=ENQUIRY_FOLLOWUP.LEADDOCID) 
  LEFT JOIN SOURCE_MASTER SM ON (SM.SOURCEMASTERID=EHE.SUBSOURCE)
  LEFT OUTER JOIN SOURCE_OF_ENQUIRY ON (EHE.SOURCEOFENQUIRY=SOURCE_OF_ENQUIRY.VALUEID)
  INNER JOIN COMPANY_MASTER ON (ENQUIRY_HEADER.COMPANYID=COMPANY_MASTER.COMPANYID AND (COMPANY_MASTER.COMPANYTYPE = 2))-- AND COMPANY_MASTER.COMPANYSUBTYPE is null))
  INNER JOIN ENQUIRY_LINE EL ON (ENQUIRY_HEADER.HEADERID=EL.DOCID)
  Inner JOIN ITEM_MASTER IM ON (IM.ItemId=EL.ItemID)
  INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND <>'TRIUMPH' and rnk = 1
  
WHERE CAST(ENQUIRY_HEADER.DOCDATE AS DATE) BETWEEN '2023-04-01' AND Cast(Getdate()-1 as date)
--CAST(ENQUIRY_HEADER.DOCDATE AS DATE) BETWEEN '2023-03-09' AND '2023-03-12'  AND 
--ENQUIRY_HEADER.IMPORTEDDATE>(SELECT MAX(IMPORTEDDATE) FROM ASM_PB_ENQUIRY_DIM_CDMS_STG)


/* ------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------STEP 1.2 Deduplication of CDMS Data----------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------*/ 	
--- Question : -- As we are creating INTERMEDIATE stage tables for Union purpose
--this Deduplication should always be performed on Delta (data for that day) or Full data ?

  Delete from ASM_PB_HK_ENQUIRY_DIM_CDMS_STG Where Cast(EnquiryDate as date)>Cast(Getdate()-1 as date)

--Dedup Process:
  ;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_EnquiryHeaderID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_HK_ENQUIRY_DIM_CDMS_STG                  
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;  
 
 Update ASM_PB_HK_ENQUIRY_DIM_CDMS_STG SET EnquiryFollowUp='Yes' where EnquiryFollowUp is not null and BaseFlag=0;
 
/* ------------------------------------------------------------------------------------------------------------------------------------
---------------------------STEP 1.4 Loading LSQ data into LSQ stage table (Dimension)--------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------*/ 
 --Truncate table ASM_PB_ENQUIRY_DIM_LSQ_STG
INSERT INTO ASM_PB_HK_ENQUIRY_DIM_LSQ_STG
SELECT DISTINCT
	LSQ_PBASE.ProspectId AS PK_EnquiryHeaderID,
	LTRIM (Cast(DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date))) As DATE),10) As EnquiryDate,
	'' AS EnquiryDaysBucket,
	LSQ_PBASE.mx_Enquiry_Mode AS EnquiryMedium,
	CASE WHEN FIRST_FOLLOWUP.RelatedProspectID is Not null then 'Yes' Else 'No' END AS EnquiryFollowUp, 
	/*SOURCE_OF_ENQUIRY.NAME*/LSQ_PBASE.mx_Source_Of_Enquiry AS EnquiryLeadSource,  
	--LSQ_PBASE.ProspectStage AS EnquiryStatus, 

  CASE WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('BOOKED','ALLOCATED') THEN 'Booked'
    WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('INVOICED','DELIVERED') THEN 'Invoiced'
    WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER','LOST TO CO-DEALER/CO- BRANCH') THEN 'Closed' 
    WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('OPEN', 'CONTACTED', 'QUALIFIED', 'TEST RIDE BOOKED', 'TEST RIDE CANCELLED', 'TEST RIDE RESCHEDULED', 'VISITED', 'SALES DEMO', 'TEST RIDE COMPLETED', 'FINANCE', 'EXCHANGE', 'BOOKING IN PROGRESS ', 'BOOKING FAILED') THEN 'Open' END AS EnquiryStatus,

  
CASE WHEN LSQ_TESTRIDE.RelatedProspectID IS NOT NULL THEN 'Yes' else 'No' END AS IsTestRideTaken,
  Null AS TestRideOffered,
	LSQ_PBASE.mx_type_of_customer AS CustomerOwnershipProfileId ,
	LSQ_PBASE.mx_payment_mode AS ModeOfPurchase,
	LSQ_PBASE.mx_Enquiry_Mode AS LeadType,
	LSQ_PBASE.mx_Source_Of_Enquiry AS SourceType, 
	LSQ_PBASE.mx_Enquiry_Sub_source AS SubSourceOfEnquiry,
	----LSQ_PBASE.mx_Enquiry_Sub_source AS EnquirySubsource,  
	--CASE WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('BOOKED','ALLOCATED') THEN 'Booked'
	--WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('INVOICED','DELIVERED') THEN 'Invoiced'
	--WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER') THEN 'Lost' 
	--WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('VISITED' ,'CONTACTED' ,'OPEN' ,'TEST RIDE CANCELLED' ,'QUALIFIED' ,'PROSPECT' ,'TEST RIDE COMPLETED' ,'TEST RIDE BOOKED' ,'TEST RIDE RESCHEDULED') THEN 'Open' END AS LEADSTATUS,

  CASE WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('BOOKED','ALLOCATED') THEN 'Booked'
    WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('INVOICED','DELIVERED') THEN 'Invoiced'
    WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER','LOST TO CO-DEALER/CO- BRANCH') THEN 'Closed' 
    WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('OPEN', 'CONTACTED', 'QUALIFIED', 'TEST RIDE BOOKED', 'TEST RIDE CANCELLED', 'TEST RIDE RESCHEDULED', 'VISITED', 'SALES DEMO', 'TEST RIDE COMPLETED', 'FINANCE', 'EXCHANGE', 'BOOKING IN PROGRESS ', 'BOOKING FAILED') THEN 'Open' END AS LEADSTATUS,

	Case when UPPER(LSQ_PBASE.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER') then  LSQ_PBASE.ProspectStage END AS LeadLostReason,
	--LSQ_PBASE.ProspectStage AS LeadLostReason, -- LOGIC TO BE IMPLEMENTED
	'' as LostByCategory,	
    Null  AS PrimaryUsage, 
	LSQ_PBASE.mx_Enquiry_Classification AS LEADCLASSIFICATIONTYPE,
	CAST(Null AS INT) as LostByFinance, --- EXCLUSIVE to CDMS
	CAST(Null AS INT) as LostByChannel,  --- EXCLUSIVE to CDMS
	CAST(Null AS INT) as LostByProduct,  --- EXCLUSIVE to CDMS
	Case when Upper(LSQ_PBASE.ProspectStage)='LOST TO COMPETITION' then 'Yes' END  as LostToCompetition, 
	--LSQ_PBASE.ProspectStage as LostToCompetition,   
	CAST(Null AS INT) as LostByOthers,  --- EXCLUSIVE to CDMS
	DATEADD(mi,30,(DATEADD(hh,5,GETDATE()))) AS CREATEDDATETIME,
	DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.ModifiedOn))) as IMPORTEDDATE,
	CAST(Null AS INT) as CDMS_BATCHNO, -- EXCLUSIVE to CDMS
	Cast(0 as int) As RetailConversionFlag,
	LSQ_PBASE.mx_Exchange AS IsExchangeApplicable,
	NULL AS FinanceCompany, 
	1 AS BaseFlag,
	Case when LSQ_PBASE.mx_Need_Assessment=1 THEN 'Yes' when LSQ_PBASE.mx_Need_Assessment=0 then 'No' Else LSQ_PBASE.mx_Need_Assessment END AS IsNeedsAssessment,
               --CASE WHEN LSQ_PBASE.mx_Sales_Demo IS NOT NULL THEN 'Yes' else 'No' End as IsDemo,
    CASE WHEN LSQ_Sales_Demo.mx_Custom_1='Yes' THEN 'Yes' ELSE 'No' END AS IsDemo,
               CASE WHEN LSQ_PEXTBASE.mx_Visited = 'Yes' THEN 'Yes' ELSE 'No' END AS IsVisited,
    --NULL as ISVISITED,
    LSQ_PBASE.MX_AREA AS Area,
    LSQ_PBASE.Mx_pincode as Pincode, 
    LSQ_PBASE.mx_SalesPerson_Name as SalesPerson,
    DATEADD(mi,30,(DATEADD(hh,5,FIRST_FOLLOWUP.FirstFollowupDate))) as FirstFollowupDate,
    Case WHEN FIRST_FOLLOWUP.FirstIsCustomerContacted In('Yes','No') Then 'Yes' Else 'No' END  AS FirstIsCustomerContacted,
    DATEADD(mi,30,(DATEADD(hh,5,FIRST_FOLLOWUP.FirstFollowupScheduleDate))) as FirstFollowupScheduleDate,
    DATEADD(mi,30,(DATEADD(hh,5,LATEST_FOLLOWUP.LatestFollowupDate))) as LatestFollowupDate,
    DATEADD(mi,30,(DATEADD(hh,5,LATEST_FOLLOWUP.LatestFollowupScheduleDate))) as LatestFollowupScheduleDate,
    LATEST_FOLLOWUP.LatestIsCustomerContacted,
	CASE 
				WHEN LSQ_PEB.mx_Non_Working_Hour = 'Yes' 
				AND (CONVERT(TIME, DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))) NOT BETWEEN '08:00:00' AND '17:00:00')
				
				THEN 
			CASE 
				WHEN CAST(DATEDIFF(MINUTE, COALESCE(LSQ_UTBASE.DueDate,LSQ_PEXTBASE.mx_Dealer_Assignment_Date ), FIRST_FOLLOWUP.FirstFollowupDate) AS INT) < 180 THEN '<3 Hrs'
				WHEN CAST(DATEDIFF(MINUTE, COALESCE(LSQ_UTBASE.DueDate,LSQ_PEXTBASE.mx_Dealer_Assignment_Date ), FIRST_FOLLOWUP.FirstFollowupDate) AS INT) BETWEEN 180 AND 1440 THEN '3-24 Hrs'
				WHEN CAST(DATEDIFF(MINUTE, COALESCE(LSQ_UTBASE.DueDate,LSQ_PEXTBASE.mx_Dealer_Assignment_Date ), FIRST_FOLLOWUP.FirstFollowupDate) AS INT) > 1440 THEN '>24 Hrs'   END
			ELSE--WHEN LSQ_PEB.mx_Non_Working_Hour IS NULL THEN 
    CASE 
	WHEN CAST( DATEDIFF(MINUTE, LSQ_PEXTBASE.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) <3 THEN  '<3 Hrs'
    WHEN CAST( DATEDIFF(MINUTE, LSQ_PEXTBASE.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) BETWEEN 3 AND 24 THEN '3-24 Hrs'
    WHEN CAST( DATEDIFF(MINUTE, LSQ_PEXTBASE.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) >24 then '>24 Hrs'  END
	End as FollowupBucket,
     NULL as LeadLostSecondaryReason ,
     COALESCE (LATEST_FOLLOWUP.mx_custom_14, LATEST_FOLLOWUP.mx_custom_15,FIRST_FOLLOWUP.mx_custom_14, FIRST_FOLLOWUP.mx_custom_15) AS  FollowupLatestDisposition,
	 
	 CASE WHEN LSQ_PBASE.ProspectStage IN ('Open','Qualified','Contacted','Test Ride Booked',
                           'Test Ride Cancelled','Test Ride Rescheduled' ,'Visited' ,
						   'Sales Demo','Test Ride Completed','Finance' ,'Exchange',
						   'Booking in progress','Booking failed','Booking InProgress')	THEN 'Open' 
	WHEN LSQ_PBASE.ProspectStage = 'Booked' THEN 'Booked'
	WHEN LSQ_PBASE.ProspectStage = 'Invoiced' THEN 'Invoiced'
	WHEN LSQ_PBASE.ProspectStage IN('Lost','Closed','Auto','Lost to Co-Dealer','Lost to Competition','Lost to Co-Dealer/Co- Branch','Auto - Closed') THEN 'Closed' END  ENQUIRY_STAGE,
     LSQ_PACTEXTBASE.mx_Custom_2 AS OPPORTUNITY_STATUS,
     LSQ_PBASE.mx_Reason_for_Choosing_Competition AS REASON_FOR_CHOOSING_COMPETITION ,
     LSQ_PEXT2BASE.mx_Is_any_Follow_up_overdue AS IS_ANY_FOLLOWUP_OVERDUE,
     LSQ_PBASE.Origin AS ENQUIRY_ORIGIN,
	 LSQ_PBASE.mx_Competition_Brand  as COMPETITION_BRAND,
	 LSQ_PBASE.mx_Competition_Model as COMPETITION_MODEL,
	 Case when COALESCE(LSQ_PEXTBASE.mx_Contacted_Remarks_Non_Walk_In,LSQ_PEXTBASE.mx_Contacted_Remarks_Walk_In,LSQ_PEXTBASE.mx_RNR_Status) IS NOT NULL then
           COALESCE(LSQ_PEXTBASE.mx_Contacted_Remarks_Non_Walk_In,LSQ_PEXTBASE.mx_Contacted_Remarks_Walk_In,LSQ_PEXTBASE.mx_RNR_Status)
        when LSQ_PEXTBASE.mx_Customer_Contacted='No' Then 'RNR' else '' end 
       as Follow_up_Dispositions
	
FROM
  LSQ_Prospect_Base LSQ_PBASE 
  
  INNER JOIN DBO.BRANCH_MASTER BM 
  ON LSQ_PBASE.mx_Branch_Code=BM.CODE
    
  INNER JOIN DBO.COMPANY_MASTER CM 
  ON CM.COMPANYID=BM.COMPANYID
  AND (CM.COMPANYTYPE=2)-- AND CM.COMPANYSUBTYPE IS NULL)
  
  LEFT  JOIN LSQ_Prospect_ExtensionBase LSQ_PEXTBASE 
  ON (LSQ_PBASE.ProspectId = LSQ_PEXTBASE.ProspectId)
 
  INNER JOIN LSQ_ProspectActivity_ExtensionBase LSQ_PACTEXTBASE 
  ON (LSQ_PBASE.ProspectId = LSQ_PACTEXTBASE.RelatedProspectID) 
  AND LSQ_PACTEXTBASE.ActivityEvent=12002 
   --newly added for testing
   LEFT JOIN LSQ_CustomObjectProspectActivity_Base LSQ_CUSTPACT
    ON LSQ_CUSTPACT.RelatedProspectActivityID=LSQ_PACTEXTBASE.RelatedProspectActivityID
    AND LSQ_CUSTPACT.CustomObjectProspectActivityId=LSQ_PACTEXTBASE.mx_custom_14
    
    LEFT JOIN ITEM_MASTER IM
    ON cast(IM.ITEMID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_11

   INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND <>'TRIUMPH' and rnk = 1
  
   ---------- 
  LEFT  JOIN LSQ_Prospect_Extension2Base LSQ_PEB
  ON  (LSQ_PBASE.ProspectId = LSQ_PEB.ProspectId) 
  
  LEFT  JOIN  (select DueDate,OwnerId,RelatedEntityId from 
 (SELECT DueDate,OwnerId,RelatedEntityId, ROW_NUMBER()OVER(PARTITION BY RelatedEntityId ORDER BY DueDate Asc)RNK                   
  FROM LSQ_UserTask_Base ) UT
  WHERE RNK = 1 ) LSQ_UTBASE
  ON  (LSQ_PBASE.OwnerId = LSQ_UTBASE.OwnerId) 
  and (LSQ_PBASE.ProspectId = LSQ_UTBASE.RelatedEntityId) 
  
--------------- FIRST FOLLOWUP----------------

LEFT JOIN (SELECT RelatedProspectID,FirstfollowupDate, FirstIsCustomerContacted,FirstFollowupScheduleDate,mx_custom_14,mx_custom_15 FROM (
select RelatedProspectID,mx_Custom_13 FirstIsCustomerContacted,mx_custom_3 as FirstFollowupScheduleDate,
createdon FirstfollowupDate, mx_custom_14 , mx_custom_15,
ROW_NUMBER()OVER(PARTITION BY RelatedProspectID ORDER BY CREATEDON ASC) AS RNK 
from LSQ_ProspectActivity_ExtensionBase 
where ActivityEvent=213
and mx_Custom_13 is not null ) A where RNK=1
) FIRST_FOLLOWUP
ON FIRST_FOLLOWUP.RelatedProspectID=LSQ_PBASE.ProspectId
AND DATEADD(mi,30,(DATEADD(hh,5,FIRST_FOLLOWUP.FirstFollowupDate)))>DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))

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
AND DATEADD(mi,30,(DATEADD(hh,5,LATEST_FOLLOWUP.LatestFollowupDate))) > DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))
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
  
  
  WHERE LSQ_PEXTBASE.mx_Dealer_Assignment_Date is not null
  AND  LSQ_PBASE.mx_BU='PB'
  AND CAST(DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.Modifiedon))) AS DATE) BETWEEN '2025-06-09' AND Cast(Getdate()-1 as date)
  --AND DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.ModifiedOn))) > (SELECT MAX(IMPORTEDDATE) FROM ASM_PB_ENQUIRY_DIM_LSQ_STG);

  INSERT INTO ASM_PB_ENQUIRY_DIM_LSQ_STG
SELECT DISTINCT
	LSQ_PBASE.ProspectId AS PK_EnquiryHeaderID,
	LTRIM (Cast(DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date))) As DATE),10) As EnquiryDate,
	'' AS EnquiryDaysBucket,
	LSQ_PBASE.mx_Enquiry_Mode AS EnquiryMedium,
	CASE WHEN FIRST_FOLLOWUP.RelatedProspectID is Not null then 'Yes' Else 'No' END AS EnquiryFollowUp, 
	/*SOURCE_OF_ENQUIRY.NAME*/LSQ_PBASE.mx_Source_Of_Enquiry AS EnquiryLeadSource,  
	--LSQ_PBASE.ProspectStage AS EnquiryStatus, 

  CASE WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('BOOKED','ALLOCATED') THEN 'Booked'
    WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('INVOICED','DELIVERED') THEN 'Invoiced'
    WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER','LOST TO CO-DEALER/CO- BRANCH') THEN 'Closed' 
    WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('OPEN', 'CONTACTED', 'QUALIFIED', 'TEST RIDE BOOKED', 'TEST RIDE CANCELLED', 'TEST RIDE RESCHEDULED', 'VISITED', 'SALES DEMO', 'TEST RIDE COMPLETED', 'FINANCE', 'EXCHANGE', 'BOOKING IN PROGRESS ', 'BOOKING FAILED') THEN 'Open' END AS EnquiryStatus,

  
CASE WHEN LSQ_TESTRIDE.RelatedProspectID IS NOT NULL THEN 'Yes' else 'No' END AS IsTestRideTaken,
  Null AS TestRideOffered,
	LSQ_PBASE.mx_type_of_customer AS CustomerOwnershipProfileId ,
	LSQ_PBASE.mx_payment_mode AS ModeOfPurchase,
	LSQ_PBASE.mx_Enquiry_Mode AS LeadType,
	LSQ_PBASE.mx_Source_Of_Enquiry AS SourceType, 
	LSQ_PBASE.mx_Enquiry_Sub_source AS SubSourceOfEnquiry,
	----LSQ_PBASE.mx_Enquiry_Sub_source AS EnquirySubsource,  
	--CASE WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('BOOKED','ALLOCATED') THEN 'Booked'
	--WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('INVOICED','DELIVERED') THEN 'Invoiced'
	--WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER') THEN 'Lost' 
	--WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('VISITED' ,'CONTACTED' ,'OPEN' ,'TEST RIDE CANCELLED' ,'QUALIFIED' ,'PROSPECT' ,'TEST RIDE COMPLETED' ,'TEST RIDE BOOKED' ,'TEST RIDE RESCHEDULED') THEN 'Open' END AS LEADSTATUS,

  CASE WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('BOOKED','ALLOCATED') THEN 'Booked'
    WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('INVOICED','DELIVERED') THEN 'Invoiced'
    WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER','LOST TO CO-DEALER/CO- BRANCH') THEN 'Closed' 
    WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('OPEN', 'CONTACTED', 'QUALIFIED', 'TEST RIDE BOOKED', 'TEST RIDE CANCELLED', 'TEST RIDE RESCHEDULED', 'VISITED', 'SALES DEMO', 'TEST RIDE COMPLETED', 'FINANCE', 'EXCHANGE', 'BOOKING IN PROGRESS ', 'BOOKING FAILED') THEN 'Open' END AS LEADSTATUS,

	Case when UPPER(LSQ_PBASE.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER') then  LSQ_PBASE.ProspectStage END AS LeadLostReason,
	--LSQ_PBASE.ProspectStage AS LeadLostReason, -- LOGIC TO BE IMPLEMENTED
	'' as LostByCategory,	
    Null  AS PrimaryUsage, 
	LSQ_PBASE.mx_Enquiry_Classification AS LEADCLASSIFICATIONTYPE,
	CAST(Null AS INT) as LostByFinance, --- EXCLUSIVE to CDMS
	CAST(Null AS INT) as LostByChannel,  --- EXCLUSIVE to CDMS
	CAST(Null AS INT) as LostByProduct,  --- EXCLUSIVE to CDMS
	Case when Upper(LSQ_PBASE.ProspectStage)='LOST TO COMPETITION' then 'Yes' END  as LostToCompetition, 
	--LSQ_PBASE.ProspectStage as LostToCompetition,   
	CAST(Null AS INT) as LostByOthers,  --- EXCLUSIVE to CDMS
	DATEADD(mi,30,(DATEADD(hh,5,GETDATE()))) AS CREATEDDATETIME,
	DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.ModifiedOn))) as IMPORTEDDATE,
	CAST(Null AS INT) as CDMS_BATCHNO, -- EXCLUSIVE to CDMS
	Cast(0 as int) As RetailConversionFlag,
	LSQ_PBASE.mx_Exchange AS IsExchangeApplicable,
	NULL AS FinanceCompany, 
	1 AS BaseFlag,
	Case when LSQ_PBASE.mx_Need_Assessment=1 THEN 'Yes' when LSQ_PBASE.mx_Need_Assessment=0 then 'No' Else LSQ_PBASE.mx_Need_Assessment END AS IsNeedsAssessment,
               --CASE WHEN LSQ_PBASE.mx_Sales_Demo IS NOT NULL THEN 'Yes' else 'No' End as IsDemo,
    CASE WHEN LSQ_Sales_Demo.mx_Custom_1='Yes' THEN 'Yes' ELSE 'No' END AS IsDemo,
               CASE WHEN LSQ_PEXTBASE.mx_Visited = 'Yes' THEN 'Yes' ELSE 'No' END AS IsVisited,
    --NULL as ISVISITED,
    LSQ_PBASE.MX_AREA AS Area,
    LSQ_PBASE.Mx_pincode as Pincode, 
    LSQ_PBASE.mx_SalesPerson_Name as SalesPerson,
    DATEADD(mi,30,(DATEADD(hh,5,FIRST_FOLLOWUP.FirstFollowupDate))) as FirstFollowupDate,
    Case WHEN FIRST_FOLLOWUP.FirstIsCustomerContacted In('Yes','No') Then 'Yes' Else 'No' END  AS FirstIsCustomerContacted,
    DATEADD(mi,30,(DATEADD(hh,5,FIRST_FOLLOWUP.FirstFollowupScheduleDate))) as FirstFollowupScheduleDate,
    DATEADD(mi,30,(DATEADD(hh,5,LATEST_FOLLOWUP.LatestFollowupDate))) as LatestFollowupDate,
    DATEADD(mi,30,(DATEADD(hh,5,LATEST_FOLLOWUP.LatestFollowupScheduleDate))) as LatestFollowupScheduleDate,
    LATEST_FOLLOWUP.LatestIsCustomerContacted,
	CASE 
				WHEN LSQ_PEB.mx_Non_Working_Hour = 'Yes' 
				AND (CONVERT(TIME, DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))) NOT BETWEEN '08:00:00' AND '17:00:00')
				
				THEN 
			CASE 
				WHEN CAST(DATEDIFF(hour, COALESCE(LSQ_UTBASE.DueDate,LSQ_PEXTBASE.mx_Dealer_Assignment_Date ), FIRST_FOLLOWUP.FirstFollowupDate) AS INT) < 3 THEN '<3 Hrs'
				WHEN CAST(DATEDIFF(hour, COALESCE(LSQ_UTBASE.DueDate,LSQ_PEXTBASE.mx_Dealer_Assignment_Date ), FIRST_FOLLOWUP.FirstFollowupDate) AS INT) BETWEEN 3 AND 24 THEN '3-24 Hrs'
				WHEN CAST(DATEDIFF(hour, COALESCE(LSQ_UTBASE.DueDate,LSQ_PEXTBASE.mx_Dealer_Assignment_Date ), FIRST_FOLLOWUP.FirstFollowupDate) AS INT) > 24 THEN '>24 Hrs'   END
			ELSE--WHEN LSQ_PEB.mx_Non_Working_Hour IS NULL THEN 
    CASE 
	WHEN CAST( DATEDIFF(hour, LSQ_PEXTBASE.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) <3 THEN  '<3 Hrs'
    WHEN CAST( DATEDIFF(hour, LSQ_PEXTBASE.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) BETWEEN 3 AND 24 THEN '3-24 Hrs'
    WHEN CAST( DATEDIFF(hour, LSQ_PEXTBASE.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) >24 then '>24 Hrs'  END
	End as FollowupBucket,
     NULL as LeadLostSecondaryReason ,
     COALESCE (LATEST_FOLLOWUP.mx_custom_14, LATEST_FOLLOWUP.mx_custom_15,FIRST_FOLLOWUP.mx_custom_14, FIRST_FOLLOWUP.mx_custom_15) AS  FollowupLatestDisposition,
	 
	 CASE WHEN LSQ_PBASE.ProspectStage IN ('Open','Qualified','Contacted','Test Ride Booked',
                           'Test Ride Cancelled','Test Ride Rescheduled' ,'Visited' ,
						   'Sales Demo','Test Ride Completed','Finance' ,'Exchange',
						   'Booking in progress','Booking failed','Booking InProgress')	THEN 'Open' 
	WHEN LSQ_PBASE.ProspectStage = 'Booked' THEN 'Booked'
	WHEN LSQ_PBASE.ProspectStage = 'Invoiced' THEN 'Invoiced'
	WHEN LSQ_PBASE.ProspectStage IN('Lost','Closed','Auto','Lost to Co-Dealer','Lost to Competition','Lost to Co-Dealer/Co- Branch','Auto - Closed') THEN 'Closed' END  ENQUIRY_STAGE,
     LSQ_PACTEXTBASE.mx_Custom_2 AS OPPORTUNITY_STATUS,
     LSQ_PBASE.mx_Reason_for_Choosing_Competition AS REASON_FOR_CHOOSING_COMPETITION ,
     LSQ_PEXT2BASE.mx_Is_any_Follow_up_overdue AS IS_ANY_FOLLOWUP_OVERDUE,
     LSQ_PBASE.Origin AS ENQUIRY_ORIGIN,
	 LSQ_PBASE.mx_Competition_Brand  as COMPETITION_BRAND,
	 LSQ_PBASE.mx_Competition_Model as COMPETITION_MODEL,
	 Case when COALESCE(LSQ_PEXTBASE.mx_Contacted_Remarks_Non_Walk_In,LSQ_PEXTBASE.mx_Contacted_Remarks_Walk_In,LSQ_PEXTBASE.mx_RNR_Status) IS NOT NULL then
           COALESCE(LSQ_PEXTBASE.mx_Contacted_Remarks_Non_Walk_In,LSQ_PEXTBASE.mx_Contacted_Remarks_Walk_In,LSQ_PEXTBASE.mx_RNR_Status)
        when LSQ_PEXTBASE.mx_Customer_Contacted='No' Then 'RNR' else '' end 
       as Follow_up_Dispositions
	
FROM
  LSQ_Prospect_Base LSQ_PBASE 
  
  INNER JOIN DBO.BRANCH_MASTER BM 
  ON LSQ_PBASE.mx_Branch_Code=BM.CODE
    
  INNER JOIN DBO.COMPANY_MASTER CM 
  ON CM.COMPANYID=BM.COMPANYID
  AND (CM.COMPANYTYPE=2 AND CM.COMPANYSUBTYPE IS NULL)
  
  LEFT  JOIN LSQ_Prospect_ExtensionBase LSQ_PEXTBASE 
  ON (LSQ_PBASE.ProspectId = LSQ_PEXTBASE.ProspectId)
 
  INNER JOIN LSQ_ProspectActivity_ExtensionBase LSQ_PACTEXTBASE 
  ON (LSQ_PBASE.ProspectId = LSQ_PACTEXTBASE.RelatedProspectID) 
  AND LSQ_PACTEXTBASE.ActivityEvent=12002 
  
   ---------- 
  LEFT  JOIN LSQ_Prospect_Extension2Base LSQ_PEB
  ON  (LSQ_PBASE.ProspectId = LSQ_PEB.ProspectId) 
  
  LEFT  JOIN  (select DueDate,OwnerId,RelatedEntityId from 
 (SELECT DueDate,OwnerId,RelatedEntityId, ROW_NUMBER()OVER(PARTITION BY RelatedEntityId ORDER BY DueDate Asc)RNK                   
  FROM LSQ_UserTask_Base ) UT
  WHERE RNK = 1 ) LSQ_UTBASE
  ON  (LSQ_PBASE.OwnerId = LSQ_UTBASE.OwnerId) 
  and (LSQ_PBASE.ProspectId = LSQ_UTBASE.RelatedEntityId) 
  
--------------- FIRST FOLLOWUP----------------

LEFT JOIN (SELECT RelatedProspectID,FirstfollowupDate, FirstIsCustomerContacted,FirstFollowupScheduleDate,mx_custom_14,mx_custom_15 FROM (
select RelatedProspectID,mx_Custom_13 FirstIsCustomerContacted,mx_custom_3 as FirstFollowupScheduleDate,
createdon FirstfollowupDate, mx_custom_14 , mx_custom_15,
ROW_NUMBER()OVER(PARTITION BY RelatedProspectID ORDER BY CREATEDON ASC) AS RNK 
from LSQ_ProspectActivity_ExtensionBase 
where ActivityEvent=213
and mx_Custom_13 is not null ) A where RNK=1
) FIRST_FOLLOWUP
ON FIRST_FOLLOWUP.RelatedProspectID=LSQ_PBASE.ProspectId
AND DATEADD(mi,30,(DATEADD(hh,5,FIRST_FOLLOWUP.FirstFollowupDate)))>DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))

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
AND DATEADD(mi,30,(DATEADD(hh,5,LATEST_FOLLOWUP.LatestFollowupDate))) > DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))
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
  
  
  WHERE LSQ_PEXTBASE.mx_Dealer_Assignment_Date is not null
  AND  LSQ_PBASE.mx_BU='PB'
  AND CAST(DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.Modifiedon))) AS DATE) BETWEEN '2020-04-01' AND '2025-06-08'
  --AND DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.ModifiedOn))) > (SELECT MAX(IMPORTEDDATE) FROM ASM_PB_ENQUIRY_DIM_LSQ_STG);
   
   
-----------------------------------
   Delete from ASM_PB_HK_ENQUIRY_DIM_LSQ_STG Where Cast(EnquiryDate as date)>Cast(Getdate()-1 as date)

--Dedup Process:
  ;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_EnquiryHeaderID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_HK_ENQUIRY_DIM_LSQ_STG                  
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1; 
  
/* ------------------------------------------------------------------------------------------------------------------------------------
---------------STEP 1.5 UNION of CMDS Stage and LSQ Stage tables and load into ASM_MC_ENQUIRY_DIM--------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------*/ 
--Select top 10 * from ASM_PB_ENQUIRY_DIM
--Truncate table ASM_PB_ENQUIRY_DIM
INSERT INTO ASM_PB_HK_ENQUIRY_DIM
	    
	SELECT DISTINCT
	[PK_EnquiryHeaderID] ,
	[EnquiryDate] ,
	[EnquiryDaysBucket],
	[EnquiryMedium] ,
	[EnquiryFollowUp] ,
	[EnquiryLeadSource] ,
	[EnquiryStatus] ,
	[IsTestRideTaken] ,
	[TestRideOffered] ,
	[CustomerOwnershipProfileId] ,
	[ModeOfPurchase] ,
	[LeadType],
	[SourceType] ,
	[SubSourceOfEnquiry], 
	[LeadStatus] ,
	[LeadLostReason] ,
  [LostByCategory],
	[PrimaryUsage] ,
	[LEADCLASSIFICATIONTYPE] ,
	[LostByFinance] ,
	[LostByChannel] ,
	[LostByProduct] ,
	[LostToCompetition] ,
	[LostByOthers] ,
	[CREATEDDATETIME] ,
	[IMPORTEDDATE] ,
	[CDMS_BATCHNO] ,
	[RetailConversionFlag] ,
	[IsExchangeApplicable],
	[FinanceCompany] ,	
	[BaseFlag]
	,[ISNEEDSASSESSMENT]
	,[ISDEMO]
	,[ISVISITED]
	,[AREA] 
	,[PINCODE] 
	,[SALESPERSON] 
	,[FIRSTFOLLOWUPDATE]  
	,[FIRSTISCUSTOMERCONTACTED] 
	,[FOLLOWUPSCHEDULEDATE1] 
	,[LATESTFOLLOWUPDATE] 
	,[LATESTFOLLOWUPSCHEDULEDATE]
	,[LATESTISCUSTOMERCONTACTED]
	,[FollowupBucket]
  ,[LeadLostSecondaryReason],
  [FollowupLatestDisposition]
  ,[ENQUIRY_STAGE],
[OPPORTUNITY_STATUS],
[REASON_FOR_CHOOSING_COMPETITION],
[IS_ANY_FOLLOWUP_OVERDUE],
[ENQUIRY_ORIGIN],
[COMPETITION_BRAND],
[COMPETITION_MODEL],
 [Follow_up_Dispositions]
    FROM ASM_PB_HK_ENQUIRY_DIM_CDMS_STG
	
	UNION
	
	SELECT DISTINCT
	[PK_EnquiryHeaderID] ,
	[EnquiryDate] ,
	[EnquiryDaysBucket],
	[EnquiryMedium] ,
	[EnquiryFollowUp] ,
	[EnquiryLeadSource] ,
	[EnquiryStatus] ,
	[IsTestRideTaken] ,
	[TestRideOffered] ,
	[CustomerOwnershipProfileId] ,
	[ModeOfPurchase] ,
	[LeadType],
	[SourceType] ,
	[SubSourceOfEnquiry], 
	[LeadStatus] ,
	[LeadLostReason] ,
  [LostByCategory],
	[PrimaryUsage] ,
	[LEADCLASSIFICATIONTYPE] ,
	[LostByFinance] ,
	[LostByChannel] ,
	[LostByProduct] ,
	[LostToCompetition] ,
	[LostByOthers] ,
	[CREATEDDATETIME] ,
	[IMPORTEDDATE] ,
	[CDMS_BATCHNO] ,
	[RetailConversionFlag] ,
	[IsExchangeApplicable],
	[FinanceCompany] ,	
	[BaseFlag]
	,[ISNEEDSASSESSMENT]
	,[ISDEMO]
	,[ISVISITED]
	,[AREA] 
	,[PINCODE] 
	,[SALESPERSON] 
	,[FIRSTFOLLOWUPDATE]  
	,[FIRSTISCUSTOMERCONTACTED] 
	,[FOLLOWUPSCHEDULEDATE1] 
	,[LATESTFOLLOWUPDATE] 
	,[LATESTFOLLOWUPSCHEDULEDATE]
	,[LATESTISCUSTOMERCONTACTED]
	,[FollowupBucket]
  ,[LeadLostSecondaryReason]
  ,[FollowupLatestDisposition]
 , [ENQUIRY_STAGE],
[OPPORTUNITY_STATUS],
[REASON_FOR_CHOOSING_COMPETITION],
[IS_ANY_FOLLOWUP_OVERDUE],
[ENQUIRY_ORIGIN],
[COMPETITION_BRAND],
[COMPETITION_MODEL],
 [Follow_up_Dispositions]
    FROM ASM_PB_HK_ENQUIRY_DIM_LSQ_STG
	
	
--Dedup Process:
  ;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_EnquiryHeaderID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_HK_ENQUIRY_DIM                 
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1; 
	
	
/* ------------------------------------------------------------------------------------------------------------------------------------
---------------------------STEP 2.1 LOAD CDMS Data into Enquiry Fact (Copy from main script)-------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------
------ a. Loading first stage table from CDMS
------ b. deduplication of CDMS stage
------ c. Product Master and Dealer Master FK update: ASM_MC_ENQUIRY_STG
------ d. load enq target from TARGET_SALES_3W table 
------ e. Product Master and Dealer Master FK update: ASM_MC_ENQUIRY_TARGET  */

--Enquiry Trnasaction Table Dataset

--truncate table ASM_MC_ENQUIRY_STG
--Enquiry Trnasaction Table Dataset:

--Truncate table ASM_PB_ENQUIRY_STG
INSERT INTO ASM_PB_HK_ENQUIRY_STG
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
Isnull(Count(HEADERID),0) as ACTUALQUANTITY,
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
TEHSILID,
SalesPerson,
Leadtype,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource
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
   EH.BRANCHID as BRANCHID,
   EH.HEADERID,
   getdate() as LASTUPDATEDDATETIME,
   EH.IMPORTEDDATE,
   EH.CDMS_BATCHNO,
   Cast(0 as decimal(19,0)) As TARGETQUANTITY,
   (LEFT(DATENAME( MONTH,EH.DOCDATE),3)+'-'+Cast(Year(EH.DOCDATE) as varchar(4))) As PERIODNAME,
   IV.CODE As COLOUR_CODE,
   IM.CODE As MODELCODE,
   Cast(0 as int) as FK_MODEL,
   100011 As FLAG,
   0 as BaseFlag,
   EH.ADTEHSILID as TEHSILID,
   TRIM(UPPER(CN.NAME)) AS SALESPERSON,
   EH.LEADTYPE AS LeadType,
   EH.LEADTYPE AS First_Source_Lead_Type,
   Null AS First_Mode_Source,
   Null  AS First_Mode_SubSource
   --INTO ASM_PB_ENQUIRY_STG
FROM 
   ENQUIRY_HEADER EH INNER JOIN COMPANY_MASTER CM ON (EH.COMPANYID=CM.COMPANYID AND(CM.COMPANYTYPE=2))-- AND CM.COMPANYSUBTYPE IS NULL))
   LEFT JOIN CONTACT_MASTER CN ON (EH.OWNERCONTACTID = CN.CONTACTID AND CN.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CN.CONTACTID = CN1.CONTACTID))
   INNER JOIN ENQUIRY_LINE EL ON (EH.HEADERID=EL.DOCID)
   JOIN ITEM_MASTER IM ON (IM.ItemId=EL.ItemID)
   LEFT JOIN ITEMVARMATRIX_MASTER IV ON (EL.VARMATRIXID=IV.ITEMVARMATRIXID)
    INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND <>'TRIUMPH' and rnk = 1
  

   
WHERE Cast(EH.DOCDATE as date) BETWEEN '2023-04-01' AND Cast(Getdate()-1 as date) 
   --Cast(EH.DOCDATE as date)  BETWEEN '2023-03-09' AND '2023-03-12' --AND -- (6619606 rows affected)
--EH.IMPORTEDDATE>(SELECT MAX(IMPORTEDDATE) FROM ASM_PB_ENQUIRY_STG)
	   )base
	   
	   GROUP BY 
DEALERCODE, SKU,FK_DEALERCODE, FK_SKU,  FK_TYPE_ID,DATE,ENQUIRYLINEID,
 FK_ENQUIRYDOCID,COMPANYTYPE,BRANCHID, LASTUPDATEDDATETIME,IMPORTEDDATE,CDMS_BATCHNO ,TARGETQUANTITY,PERIODNAME
,COLOUR_CODE, MODELCODE, FK_MODEL,FLAG, BaseFlag,TEHSILID,SalesPerson,LeadType,First_Source_Lead_Type,First_Mode_Source,First_Mode_SubSource;
   

   --

   Delete from ASM_PB_HK_ENQUIRY_STG Where DATE>Cast(Getdate()-1 as date)

--Dedup Process:
  ;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_ENQUIRYDOCID,ENQUIRYLINEID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_HK_ENQUIRY_STG                 
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;  


  --*****************************************************
  --*******************************************************
  --Step 2:
--Product Master and Dealer Master FK update: ASM_PB_ENQUIRY_STG
update B set B.FK_SKU=C.PK_SKU from ASM_PB_HK_ENQUIRY_STG B INNER JOIN ASM_PB_HKT_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_PB_HK_ENQUIRY_STG B INNER JOIN ASM_PB_HKT_PRODUCT_DIM C on (B.MODELCODE=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].[ASM_PB_HK_ENQUIRY_STG] B INNER JOIN ASM_PB_HKT_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)

--********************************************************************




/* ------------------------------------------------------------------------------------------------------------------------------------
---------------------------STEP 2.2 LOAD LSQ Data into Enquiry Fact LSQ transactions Data----------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------- */
--Truncate table ASM_PB_ENQUIRY_FACT_LSQ_STG

INSERT INTO ASM_PB_HK_ENQUIRY_FACT_LSQ_STG
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
Isnull(Count(ProspectId),0) as ACTUALQUANTITY,
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
TEHSILID,
SalesPerson,
Leadtype,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource

 from (
SELECT
   DISTINCT
   CM.CODE AS DEALERCODE,
   IM.CODE+IV.CODE As SKU,
   Cast(0 as int) as FK_DEALERCODE,
   Cast(0 as int) as FK_SKU,
   10001 As FK_TYPE_ID,
   DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date))) AS DATE,
   LSQ_PACTEXTBASE.ProspectActivityExtensionId as ENQUIRYLINEID,
  LSQ_PBASE.ProspectID as FK_ENQUIRYDOCID, 
   2 AS COMPANYTYPE,
   BM.BRANCHID as BRANCHID,
   LSQ_PBASE.ProspectId,
   Getdate() as LASTUPDATEDDATETIME,
   DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.ModifiedOn))) as IMPORTEDDATE,
   null as CDMS_BATCHNO,
   Cast(0 as decimal(19,0)) As TARGETQUANTITY,
   (LEFT(DATENAME( MONTH,DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))),3)+'-'+Cast(Year(DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))) as varchar(4))) As   	   PERIODNAME,
   IV.CODE As COLOUR_CODE,
   IM.CODE As MODELCODE,
   Cast(0 as int) as FK_MODEL,
   100011 As FLAG,
   1 as BaseFlag,
   Null as TEHSILID,
   LSQ_PBASE.mx_SalesPerson_Name as SalesPerson,
      ISNULL(LSQ_PBASE.mx_Enquiry_Mode,'Not Available') AS LeadType,
	CASE WHEN CAST(LSQ_PEXTBASE.mx_Dealer_Assignment_Date AS DATE)>='2024-12-01' THEN COALESCE(PE.mx_Qualified_First_Source, LSQ_PBASE.mx_Enquiry_Mode,LSQ_PBASE.MX_MODE_OF_ENQUIRY,'Not Available')
   ELSE COALESCE(LSQ_PBASE.mx_Enquiry_Mode, LSQ_PBASE.MX_MODE_OF_ENQUIRY,'Not Available') END  AS First_Source_Lead_Type,
    ISNULL(PE.mx_Qualified_Source_of_Enquiry,'Not Available') AS First_Mode_Source,
   ISNULL(PE.mx_Qualified_Sub_Source,'Not Available') AS First_Mode_SubSource

   FROM
    LSQ_Prospect_Base LSQ_PBASE
    
    INNER JOIN DBO.BRANCH_MASTER BM ON LSQ_PBASE.mx_Branch_Code=BM.CODE
    
    INNER JOIN DBO.COMPANY_MASTER CM ON CM.COMPANYID=BM.COMPANYID
	 AND (CM.COMPANYTYPE=2 ) --AND CM.COMPANYSUBTYPE IS NULL)
    
    LEFT JOIN LSQ_Prospect_ExtensionBase LSQ_PEXTBASE
    ON (LSQ_PBASE.ProspectId = LSQ_PEXTBASE.ProspectId) 
    
		LEFT JOIN LSQ_Prospect_Extension2Base PE
    ON (LSQ_PBASE.ProspectId = PE.ProspectId) 
    
    INNER JOIN LSQ_ProspectActivity_ExtensionBase LSQ_PACTEXTBASE
    ON (LSQ_PBASE.ProspectId = LSQ_PACTEXTBASE.RelatedProspectID) 
 
    LEFT JOIN LSQ_CustomObjectProspectActivity_Base LSQ_CUSTPACT
    ON LSQ_CUSTPACT.RelatedProspectActivityID=LSQ_PACTEXTBASE.RelatedProspectActivityID
    AND LSQ_CUSTPACT.CustomObjectProspectActivityId=LSQ_PACTEXTBASE.mx_custom_14
    
    LEFT JOIN ITEM_MASTER IM
    ON cast(IM.ITEMID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_11
    
    LEFT JOIN ITEMVARMATRIX_MASTER IV
    ON cast(IV.ITEMVARMATRIXID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_14
	INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND <>'TRIUMPH' and rnk = 1

    WHERE LSQ_PACTEXTBASE.ActivityEvent=12002 and LSQ_PBASE.mx_BU='PB'
    And LSQ_PEXTBASE.mx_Dealer_Assignment_Date is not null
	AND CAST(DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.Modifiedon))) AS DATE) BETWEEN '2025-06-09' AND Cast(Getdate()-1 as date)
	--AND LSQ_PgBASE.Modifiedon > (SELECT MAX(IMPORTEDDATE) FROM ASM_PB_ENQUIRY_FACT_LSQ_STG)
  --AND DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.Modifiedon))) > (SELECT MAX(IMPORTEDDATE) FROM ASM_PB_ENQUIRY_FACT_LSQ_STG)
  ) TMP
	GROUP BY 
DEALERCODE, SKU,FK_DEALERCODE, FK_SKU,  FK_TYPE_ID,DATE,ENQUIRYLINEID,
 FK_ENQUIRYDOCID,COMPANYTYPE,BRANCHID,LASTUPDATEDDATETIME,IMPORTEDDATE,CDMS_BATCHNO ,TARGETQUANTITY,PERIODNAME
,COLOUR_CODE, MODELCODE, FK_MODEL,FLAG, BaseFlag,TEHSILID,SalesPerson,LeadType,First_Source_Lead_Type,First_Mode_Source,First_Mode_SubSource
;


INSERT INTO ASM_PB_HK_ENQUIRY_FACT_LSQ_STG
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
Isnull(Count(ProspectId),0) as ACTUALQUANTITY,
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
TEHSILID,
SalesPerson,
Leadtype,
First_Source_Lead_Type,
First_Mode_Source,
First_Mode_SubSource

 from (
SELECT
   DISTINCT
   CM.CODE AS DEALERCODE,
   IM.CODE+IV.CODE As SKU,
   Cast(0 as int) as FK_DEALERCODE,
   Cast(0 as int) as FK_SKU,
   10001 As FK_TYPE_ID,
   DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date))) AS DATE,
   LSQ_PACTEXTBASE.ProspectActivityExtensionId as ENQUIRYLINEID,
  LSQ_PBASE.ProspectID as FK_ENQUIRYDOCID, 
   2 AS COMPANYTYPE,
   BM.BRANCHID as BRANCHID,
   LSQ_PBASE.ProspectId,
   Getdate() as LASTUPDATEDDATETIME,
   DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.ModifiedOn))) as IMPORTEDDATE,
   null as CDMS_BATCHNO,
   Cast(0 as decimal(19,0)) As TARGETQUANTITY,
   (LEFT(DATENAME( MONTH,DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))),3)+'-'+Cast(Year(DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))) as varchar(4))) As   	   PERIODNAME,
   IV.CODE As COLOUR_CODE,
   IM.CODE As MODELCODE,
   Cast(0 as int) as FK_MODEL,
   100011 As FLAG,
   1 as BaseFlag,
   Null as TEHSILID,
   LSQ_PBASE.mx_SalesPerson_Name as SalesPerson,
      ISNULL(LSQ_PBASE.mx_Enquiry_Mode,'Not Available') AS LeadType,
	CASE WHEN CAST(LSQ_PEXTBASE.mx_Dealer_Assignment_Date AS DATE)>='2024-12-01' THEN COALESCE(PE.mx_Qualified_First_Source, LSQ_PBASE.mx_Enquiry_Mode,LSQ_PBASE.MX_MODE_OF_ENQUIRY,'Not Available')
   ELSE COALESCE(LSQ_PBASE.mx_Enquiry_Mode, LSQ_PBASE.MX_MODE_OF_ENQUIRY,'Not Available') END  AS First_Source_Lead_Type,
    ISNULL(PE.mx_Qualified_Source_of_Enquiry,'Not Available') AS First_Mode_Source,
   ISNULL(PE.mx_Qualified_Sub_Source,'Not Available') AS First_Mode_SubSource

   FROM
    LSQ_Prospect_Base LSQ_PBASE
    
    INNER JOIN DBO.BRANCH_MASTER BM ON LSQ_PBASE.mx_Branch_Code=BM.CODE
    
    INNER JOIN DBO.COMPANY_MASTER CM ON CM.COMPANYID=BM.COMPANYID
	 AND (CM.COMPANYTYPE=2 AND CM.COMPANYSUBTYPE IS NULL)
    
    LEFT JOIN LSQ_Prospect_ExtensionBase LSQ_PEXTBASE
    ON (LSQ_PBASE.ProspectId = LSQ_PEXTBASE.ProspectId) 
    
		LEFT JOIN LSQ_Prospect_Extension2Base PE
    ON (LSQ_PBASE.ProspectId = PE.ProspectId) 
    
    INNER JOIN LSQ_ProspectActivity_ExtensionBase LSQ_PACTEXTBASE
    ON (LSQ_PBASE.ProspectId = LSQ_PACTEXTBASE.RelatedProspectID) 
 
    LEFT JOIN LSQ_CustomObjectProspectActivity_Base LSQ_CUSTPACT
    ON LSQ_CUSTPACT.RelatedProspectActivityID=LSQ_PACTEXTBASE.RelatedProspectActivityID
    AND LSQ_CUSTPACT.CustomObjectProspectActivityId=LSQ_PACTEXTBASE.mx_custom_14
    
    LEFT JOIN ITEM_MASTER IM
    ON cast(IM.ITEMID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_11
    
    LEFT JOIN ITEMVARMATRIX_MASTER IV
    ON cast(IV.ITEMVARMATRIXID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_14

    WHERE LSQ_PACTEXTBASE.ActivityEvent=12002 and LSQ_PBASE.mx_BU='PB'
    And LSQ_PEXTBASE.mx_Dealer_Assignment_Date is not null
	AND CAST(DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.Modifiedon))) AS DATE) BETWEEN '2020-04-01' AND '2025-06-08'
	--AND LSQ_PgBASE.Modifiedon > (SELECT MAX(IMPORTEDDATE) FROM ASM_PB_ENQUIRY_FACT_LSQ_STG)
  --AND DATEADD(mi,30,(DATEADD(hh,5,LSQ_PBASE.Modifiedon))) > (SELECT MAX(IMPORTEDDATE) FROM ASM_PB_ENQUIRY_FACT_LSQ_STG)
  ) TMP
	GROUP BY 
DEALERCODE, SKU,FK_DEALERCODE, FK_SKU,  FK_TYPE_ID,DATE,ENQUIRYLINEID,
 FK_ENQUIRYDOCID,COMPANYTYPE,BRANCHID,LASTUPDATEDDATETIME,IMPORTEDDATE,CDMS_BATCHNO ,TARGETQUANTITY,PERIODNAME
,COLOUR_CODE, MODELCODE, FK_MODEL,FLAG, BaseFlag,TEHSILID,SalesPerson,LeadType,First_Source_Lead_Type,First_Mode_Source,First_Mode_SubSource
;
-----------------------------------------------------------------------------------------------------------------------------


Delete from ASM_PB_HK_ENQUIRY_FACT_LSQ_STG Where DATE>Cast(Getdate()-1 as date)  ;
--Dedup Process:
WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_ENQUIRYDOCID,ENQUIRYLINEID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_HK_ENQUIRY_FACT_LSQ_STG                 
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;  
 
   --*****************************************************
  --*******************************************************
  --Step 2:
--Product Master and Dealer Master FK update: ASM_MC_ENQUIRY_STG
update B set B.FK_SKU=C.PK_SKU from ASM_PB_HK_ENQUIRY_FACT_LSQ_STG B INNER JOIN ASM_PB_HKT_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_PB_HK_ENQUIRY_FACT_LSQ_STG B INNER JOIN ASM_PB_HKT_PRODUCT_DIM C on (B.MODELCODE=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].[ASM_PB_HK_ENQUIRY_FACT_LSQ_STG] B INNER JOIN ASM_PB_HKT_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)


/* ------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------STEP 2.3  UNION of CDMS and LSQ Data---------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------- */

Truncate table ASM_PB_HK_ENQUIRY_FACT

INSERT INTO ASM_PB_HK_ENQUIRY_FACT
SELECT * FROM ASM_PB_HK_ENQUIRY_STG
Union
SELECT * FROM ASM_PB_HK_ENQUIRY_FACT_LSQ_STG


/* ------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------STEP 2.4  Update RetailConversionFlag for CDMS-----------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------- */

/* ------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------STEP 2.4  Update RetailConversionFlag for CDMS-----------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------- */

--RetailConversion Flag:


 -- Update RetailConversion Flag in ASM_MC_ENQUIRY_DIM:

--Truncate table ASM_PB_ENQTORET_CONVERSION
INSERT INTO ASM_PB_HK_ENQTORET_CONVERSION
SELECT DISTINCT 
EF.FK_ENQUIRYDOCID,
EF.DATE,
RetailConversionFlag=1,
EF.IMPORTEDDATE,
GETDATE() AS CREATEDDATETIME
--INTO ASM_PB_ENQTORET_CONVERSION
FROM 
ASM_PB_HK_ENQUIRY_FACT EF 
JOIN BOOKING_LINE BL ON (Cast(BL.ENQUIRYDATALINEID as Varchar(50))=EF.ENQUIRYLINEID ) 
JOIN RETAIL_LINE RL ON (BL.LINEID=RL.BOOKINGDATALINEID) 
WHERE [DATE] BETWEEN '2023-04-01' AND Cast(Getdate()-1 as date)
--[DATE] BETWEEN '2023-03-09' AND '2023-03-12'  -- (1545805 rows affected)
--[DATE]>(SELECT MAX(DATE) from ASM_PB_ENQTORET_CONVERSION)


Update ED
Set ED.RetailConversionFlag=ERC.RetailConversionFlag
From ASM_PB_HK_ENQUIRY_DIM ED  JOIN ASM_PB_ENQTORET_CONVERSION ERC  ON (Cast(ERC.FK_ENQUIRYDOCID as Varchar(50))= ED.PK_EnquiryHeaderID) --(1638322 rows affected)

IF(OBJECT_ID('TempDB..#TEMP1','U') IS NOT NULL)
BEGIN
    DROP TABLE TEMP1
    END



SELECT HEADERID,LINEID, LMSBOOKINGID INTO #TEMP1
FROM 
( SELECT BH.HEADERID, LINE.LINEID, BHEXT.LMSBOOKINGID FROM
BOOKING_HEADER BH
JOIN BOOKING_HEADER_EXT  BHEXT ON BH.HEADERID=BHEXT.HEADERID
JOIN BOOKING_LINE LINE ON LINE.HEADERID=BH.HEADERID
WHERE BH.BU='ProBiking'
and BHEXT.LMSBOOKINGID IS NOT NULL
)A;


Update ED
Set ED.RetailConversionFlag=1
FROM ASM_PB_HK_ENQUIRY_DIM ED 
JOIN  LSQ_Prospect_Base LSQ_PBASE ON (LSQ_PBASE.ProspectId=ED.PK_EnquiryHeaderID)
INNER JOIN DBO.BRANCH_MASTER BM ON LSQ_PBASE.mx_Branch_Code=BM.CODE
INNER JOIN DBO.COMPANY_MASTER CM ON CM.COMPANYID=BM.COMPANYID  AND (CM.COMPANYTYPE=2 AND CM.COMPANYSUBTYPE IS NULL)
JOIN  LSQ_ProspectActivity_ExtensionBase PAE ON (LSQ_PBASE.ProspectID=PAE.RelatedProspectId and PAE.ActivityEvent=12002 )
JOIN #TEMP1 TMP ON (Cast(LSQ_PBASE.ProspectID+','+PAE.ProspectActivityExtensionId as varchar(8000))=TMP.LMSBOOKINGID)
INNER JOIN ALLOCATION_LINE AL ON (TMP.LINEID=AL.BOOKINGDATALINEID)
INNER JOIN RETAIL_LINE RL ON (AL.LINEID=RL.ALLOCATIONDATALINEID)
WHERE ED.BaseFlag=1 
AND LSQ_PBASE.mx_BU='PB'


END
GO