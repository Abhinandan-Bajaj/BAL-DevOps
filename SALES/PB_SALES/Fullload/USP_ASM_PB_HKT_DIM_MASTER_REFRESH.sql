

GO
SET QUOTED_IDENTIFIER ON
GO
create  PROC [dbo].[USP_ASM_PB_HKT_DIM_MASTER_REFRESH] AS
BEGIN
--***************************START************************************************
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2025-06-30 	|	Lachmanna		| KTM and trm dim table */
/*  2025-09-25 	|	Lachmanna		        | Newly Added No of Followup  and   Followup Bucket CR      */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
--******************************* START ******************************************

Truncate table ASM_PB_HKT_ENQUIRY_DIM
insert into ASM_PB_HKT_ENQUIRY_DIM
select 
PK_EnquiryHeaderID
,EnquiryDate
,EnquiryDaysBucket
,EnquiryMedium
,EnquiryFollowUp
,EnquiryLeadSource
,EnquiryStatus
,IsTestRideTaken
,TestRideOffered
,CustomerOwnershipProfileId
,ModeOfPurchase
,LeadType
,SourceType
,SubSourceOfEnquiry
,LeadStatus
,LeadLostReason
,LostByCategory
,PrimaryUsage
,LEADCLASSIFICATIONTYPE
,LostByFinance
,LostByChannel
,LostByProduct
,LostToCompetition
,LostByOthers
,CREATEDDATETIME
,IMPORTEDDATE
,CDMS_BATCHNO
,RetailConversionFlag
,IsExchangeApplicable
,FINANCECOMPANY
,Baseflag
,ISNEEDSASSESSMENT
,ISDEMO
,ISVISITED
,AREA
,PINCODE
,SALESPERSON
,FIRSTFOLLOWUPDATE
,FirstIsCustomerContacted
,FollowupScheduleDate1
,LATESTFOLLOWUPDATE
,LatestFollowupScheduleDate
,LatestIsCustomerContacted
,FOLLOWUPBUCKET
,LeadLostSecondaryReason
,CAST(NULL AS VARCHAR(10)) AS VisitedBooking
,FollowupLatestDisposition
,ENQUIRY_STAGE
,OPPORTUNITY_STATUS
,REASON_FOR_CHOOSING_COMPETITION
,IS_ANY_FOLLOWUP_OVERDUE
,ENQUIRY_ORIGIN
,COMPETITION_BRAND
,COMPETITION_MODEL
,Follow_up_Dispositions
,'PB-KTM' as Brand_Flag
,No_of_Follow_ups
from  ASM_PB_HK_ENQUIRY_DIM
-------Triumph 
insert into ASM_PB_HKT_ENQUIRY_DIM
select 
 PK_EnquiryHeaderID
,EnquiryDate
,EnquiryDaysBucket
,EnquiryMedium
,EnquiryFollowUp
,EnquiryLeadSource
,EnquiryStatus
,CAST(IsTestRideTaken AS VARCHAR(10)) AS IsTestRideTaken
,TestRideOffered
,CustomerOwnershipProfileId
,ModeOfPurchase
,LeadType
,SourceType
,SubSourceOfEnquiry
,LeadStatus
,LeadLostReason
,LostByCategory
,PrimaryUsage
,LEADCLASSIFICATIONTYPE
,LostByFinance
,LostByChannel
,LostByProduct
,LostToCompetition
,LostByOthers
,CREATEDDATETIME
,IMPORTEDDATE
,CDMS_BATCHNO
,RetailConversionFlag
,IsExchangeApplicable
,FINANCECOMPANY
,Baseflag
,ISNEEDSASSESSMENT
,ISDEMO
,ISVISITED
,AREA
,PINCODE
,SALESPERSON
,FIRSTFOLLOWUPDATE
,FirstIsCustomerContacted
,FirstFollowupScheduleDate
,LATESTFOLLOWUPDATE
,LatestFollowupScheduleDate
,LatestIsCustomerContacted
,FOLLOWUPBUCKET
,LeadLostSecondaryReason
,CAST(IsTestRideBooked AS VARCHAR(10)) AS IsTestRideBooked 
,CAST(NULL AS VARCHAR(10)) AS FollowupLatestDisposition
,ENQUIRY_STAGE
,OPPORTUNITY_STATUS
,REASON_FOR_CHOOSING_COMPETITION
,IS_ANY_FOLLOWUP_OVERDUE
,ENQUIRY_ORIGIN
,COMPETITION_BRAND
,COMPETITION_MODEL
,Follow_up_Dispositions
,'PB-TRM' as Brand_Flag
,No_of_Follow_ups
from  ASM_PB_T_ENQUIRY_DIM

END
GO