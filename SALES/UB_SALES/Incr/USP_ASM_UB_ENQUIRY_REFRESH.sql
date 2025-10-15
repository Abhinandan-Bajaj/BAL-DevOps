SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter PROC [dbo].[USP_ASM_UB_ENQUIRY_REFRESH] AS
BEGIN

--***************************START************************************************
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-10-24 	|	Richa		        | Added new column in Enq Dim- Booking Flag		*/
/*	2024-12-11 	|	Nikita		        | Followup bucket logic change		*/
/*	2024-12-24 	|	Nikita		        | First_Source_Lead_type Changes 	
    2025-01-15 	|	Richa, Ashwini		        | Source, Subsource Changes  	*/
/*	2025-03-24	|	Lachmanna		 | First Mode : Source   and subsource   add fact table    
    2025-05-27	|	Richa		 | Demo and sessiontime added     */
/*  2025-06-18	|	Lachmanna		 | SameDay booking,Retail and Enquiry     */
/*  2025-09-05	|	Ashwini		 | UB duedate Followup logic  update    */
/*  2025-10-08	|	Ashwini		 | UB duedate Followup logic  with CRE UPDATE    */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
 /* Step 1 : Loading Enquiry Dim */

DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_UB_ENQUIRY_REFRESH';

----------------------------------------------------------------
    -- Audit Segment 1: ASM_UB_ENQUIRY_DIM
----------------------------------------------------------------  

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			@table_name1 VARCHAR(128) = 'ASM_UB_ENQUIRY_DIM', 
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT,   
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX);  
BEGIN TRY

 --- Truncate table ASM_UB_ENQUIRY_DIM 
 INSERT INTO ASM_UB_ENQUIRY_DIM
 SELECT DISTINCT
 UB.ProspectID as PK_EnquiryProspectID
--,Cast(EXTUB.mx_Dealer_Assignment_Date AS DATE) as EnquiryDate
,LTRIM(CAST(DATEADD(mi,30,(DATEADD(hh,5,EXTUB.mx_Dealer_Assignment_Date)))AS DATE),10) as EnquiryDate
,'' AS EnquiryDaysBucket
,CASE WHEN FIRST_FOLLOWUP.RelatedProspectID is Not null then 'Yes' Else 'No' END AS EnquiryFollowUp
,UB.MX_SOURCE_OF_ENQUIRY AS SourceOfEnquiry
,Case when LSQ_TESTRIDE.RelatedProspectID is not null then 'Completed' End AS  TestRideOffered
,NULL AS CustomerOwnershipProfileId
,Case when UB.mx_Interested_in_Finance='Yes' theN 'Finance' WHEN  UB.mx_Interested_in_Finance='No' then 'Cash' else UB.mx_Interested_in_Finance END AS ModeOfPurchase
,UB.Mx_enquiry_mode  As LeadType
,UB.mx_Enquiry_Subsource AS SubSourceOfEnquiry
,CASE WHEN UPPER(UB.ProspectStage) IN ('BOOKED','ALLOCATED') THEN 'Booked'
WHEN UPPER(UB.ProspectStage) IN ('INVOICED','DELIVERED') THEN 'Invoiced'
WHEN UPPER(UB.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER') THEN 'Lost' 
WHEN UPPER(UB.ProspectStage) IN ('VISITED' ,'CONTACTED' ,'OPEN' ,'TEST RIDE CANCELLED' ,'QUALIFIED' ,'PROSPECT' ,'TEST RIDE COMPLETED' ,'TEST RIDE BOOKED' ,'TEST RIDE RESCHEDULED') THEN 'Open' 
END AS LeadStatus
,Case when UPPER(UB.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER') then  UB.ProspectStage 
END AS LeadLostReason
,'' as LostByCategory
,NULL  AS PrimaryUsage
,UB.mx_Enquiry_Clasification AS LEADCLASSIFICATIONTYPE
,Case when Upper(UB.ProspectStage)='LOST TO COMPETITION' then 'Yes' END  as LostToCompetition	
,GETDATE () CREATEDDATETIME
--,UB.Modifiedon AS IMPORTEDDATE
,DATEADD(mi,30,(DATEADD(hh,5,UB.ModifiedOn))) AS IMPORTEDDATE
,0 as RetailConversionFlag
,UB.mx_Interested_in_Exchange AS IsExchangeApplicable
,Case when UB.mx_Need_Assessment=1 THEN 'Yes' when UB.mx_Need_Assessment=0 then 'No' Else UB.mx_Need_Assessment END AS IsNeedsAssessment
--,CASE WHEN LSQ_Sales_Demo.mx_Custom_1='Yes' THEN 'Yes' ELSE 'No' END AS IsDemo
,CASE WHEN LSQ_Sales_Demo.mx_Custom_1='Yes' THEN 'Yes' ELSE 'No' END AS IsDemo
,Case when EXTUB.mx_visited='Yes' then 1 else 0 END AS IS_VISITED
,UB.MX_AREA AS Area
,UB.mx_Zip AS PINCODE
,UB.mx_SalesPerson_Name SALES_PERSON
--,FIRST_FOLLOWUP.FirstFollowupDate
 ,DATEADD(mi,30,(DATEADD(hh,5,FIRST_FOLLOWUP.FirstFollowupDate))) as FirstFollowupDate
,FIRST_FOLLOWUP.FirstIsCustomerContacted
--,FIRST_FOLLOWUP.FirstFollowupScheduleDate
 ,DATEADD(mi,30,(DATEADD(hh,5,FIRST_FOLLOWUP.FirstFollowupScheduleDate))) as FirstFollowupScheduleDate
--,LATEST_FOLLOWUP.LatestFollowupDate
 ,DATEADD(mi,30,(DATEADD(hh,5,LATEST_FOLLOWUP.LatestFollowupDate))) as LatestFollowupDate
--,LATEST_FOLLOWUP.LatestFollowupScheduleDate
 ,DATEADD(mi,30,(DATEADD(hh,5,LATEST_FOLLOWUP.LatestFollowupScheduleDate))) as LatestFollowupScheduleDate
,LATEST_FOLLOWUP.LatestIsCustomerContacted
,
			/*CASE 
				WHEN EXTUB.mx_Non_Working_Hour = 'yes' 
				--AND (CONVERT(TIME, DATEADD(mi,30,(DATEADD(hh,5,EXTUB.mx_Dealer_Assignment_Date)))) NOT BETWEEN '08:00:00' AND '17:00:00')
				THEN */
			CASE 
				WHEN CAST(DATEDIFF(MINUTE, COALESCE(LSQ_UTBASE.DueDate,EXTUB.mx_Dealer_Assignment_Date ),COALESCE( CRE_FIRST_FOLLOWUP.CREfollowupDate , FIRST_FOLLOWUP.FirstFollowupDate )) AS INT) < 120 THEN '<3 Hrs'
				WHEN CAST(DATEDIFF(MINUTE, COALESCE(LSQ_UTBASE.DueDate,EXTUB.mx_Dealer_Assignment_Date ),COALESCE( CRE_FIRST_FOLLOWUP.CREfollowupDate , FIRST_FOLLOWUP.FirstFollowupDate )) AS INT) BETWEEN 120 AND 1380 THEN '3-24 Hrs'
				WHEN CAST(DATEDIFF(MINUTE, COALESCE(LSQ_UTBASE.DueDate,EXTUB.mx_Dealer_Assignment_Date ),COALESCE( CRE_FIRST_FOLLOWUP.CREfollowupDate , FIRST_FOLLOWUP.FirstFollowupDate )) AS INT) > 1380 THEN '>24 Hrs'  -- END
			/*ELSE --WHEN LSQ_PEB.mx_Non_Working_Hour IS NULL THEN 
			CASE 
				WHEN CAST(DATEDIFF(MINUTE, EXTUB.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) < 180  THEN '<3 Hrs'
				WHEN CAST(DATEDIFF(MINUTE, EXTUB.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) BETWEEN 180 AND 1440 THEN '3-24 Hrs'
				WHEN CAST(DATEDIFF(MINUTE, EXTUB.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) > 1440 THEN '>24 Hrs'  END*/
			END AS  FollowupBucket 
,NULL AS LeadLostSecondaryReason
,COALESCE (LATEST_FOLLOWUP.mx_custom_2, LATEST_FOLLOWUP.mx_custom_3,FIRST_FOLLOWUP.mx_custom_2, FIRST_FOLLOWUP.mx_custom_3) AS  FollowupLatestDisposition
,UB.PHONE AS PHONE
,UB.mx_enquiry_state AS STATE
,UB.mx_enquiry_city AS CITY
--,ROW_NUMBER() OVER (PARTITION BY UB.PHONE, UB.mx_Branch_Code ORDER BY UB.CREATEDON ASC) AS RANK_PHONE_BRANCH
,NULL AS RANK_PHONE_BRANCH
,CASE WHEN FIRST_FOLLOWUP.RelatedProspectID is Not NULL THEN 'Yes' else 'No' END  IS_FOLLOWUP
,UB.CREATEDON AS EnquiryCreationDate
,NULL AS CityCluster
,Null AS Booking_Flag
,NULL AS ENQUIRY_SESSIONTIME_MORETHAN_2MINS
,CASE WHEN UPPER(UB.ProspectStage) IN ('BOOKED','ALLOCATED','INVOICED','DELIVERED','LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER') and  
CAST(DATEADD(mi,30,(DATEADD(hh,5,EXTUB.mx_Dealer_Assignment_Date)))AS DATE)=  CAST(DATEADD(mi,30,(DATEADD(hh,5,ACTEXT.mx_Custom_25)))AS DATE)  then 'YES' ELSE 'NO' end as SameDayBooking
,CASE WHEN UPPER(UB.ProspectStage) IN ('INVOICED','DELIVERED') and  
CAST(DATEADD(mi,30,(DATEADD(hh,5,EXTUB.mx_Dealer_Assignment_Date)))AS DATE)= CAST(DATEADD(mi,30,(DATEADD(hh,5,ACTEXT.mx_Custom_28)))AS DATE) then 'YES' ELSE 'NO' end as SameDayRetail
,CASE WHEN  UPPER(UB.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER') and 
CAST(DATEADD(mi,30,(DATEADD(hh,5,EXTUB.mx_Dealer_Assignment_Date)))AS DATE)= CAST(DATEADD(mi,30,(DATEADD(hh,5,ACTEXT.mx_Custom_27)))AS DATE)  then 'YES' ELSE 'NO' end as SameDayClosed

/*lachmanna DEV columns not in PROD yet*/
,EXTUB.mx_Lost_to_Competition_Make	as COMPETITION_BRAND
,EXTUB.mx_Competition_Model as 	COMPETITION_MODEL
,EXTUB.mx_Reason_for_Choosing_Competition as 	REASON_FOR_CHOOSING_COMPETITION
,EXTUB.mx_Follow_Up_Dispositions as 	Follow_Up_Dispositions
,CASE WHEN UPPER(UB.ProspectStage) IN ('BOOKED') THEN 'Booked'
	WHEN UPPER(UB.ProspectStage) IN ('INVOICED') THEN 'Invoiced'
	WHEN UPPER(UB.ProspectStage) IN ('LOST' ,'AUTO - CLOSED','AUTO-CLOSED' ,'AUTO- CLOSED','CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER','LOST TO CO-DEALER/CO- BRANCH','FUTURE RETARGETING') THEN 'Closed' 
	WHEN UPPER(UB.ProspectStage) IN ('OPEN', 'CONTACTED', 'QUALIFIED', 'TEST RIDE BOOKED', 'TEST RIDE CANCELLED', 'TEST RIDE RESCHEDULED', 'VISITED', 'SALES DEMO', 'TEST RIDE COMPLETED', 'FINANCE', 'EXCHANGE', 'BOOKING IN PROGRESS ','BOOKING INPROGRESS', 'BOOKING FAILED','Intent to Book') THEN 'Open' END AS EnquiryStatus
,ACTEXT.mx_Custom_2 as OPPORTUNITY_STATUS
FROM LSQ_UB_PROSPECT_BASE UB

JOIN BRANCH_MASTER BM  WITH (NOLOCK)
ON BM.CODE=UB.mx_Branch_Code

JOIN COMPANY_MASTER CM WITH (NOLOCK) 
ON CM.COMPANYID=BM.COMPANYID

LEFT JOIN LSQ_UB_PROSPECT_EXTENSIONBASE EXTUB ON 
UB.ProspectID=EXTUB.ProspectID

LEFT JOIN LSQ_UB_PROSPECTACTIVITY_BASE ACT 
ON ACT.RelatedProspectID = UB.ProspectID

INNER JOIN LSQ_UB_PROSPECTACTIVITY_EXTENSIONBASE ACTEXT ON 
ACT.ProspectActivityID=ACTEXT.RelatedProspectActivityID
and UB.ProspectID=ACTEXT.RelatedProspectID
AND ACTEXT.ActivityEvent=12000


LEFT JOIN (select DueDate,OwnerId,RelatedEntityId,TaskType,CreatedON  from
 (SELECT DueDate,OwnerId,RelatedEntityId, TaskType,CreatedON, ROW_NUMBER()OVER(PARTITION BY RelatedEntityId ORDER BY CreatedON Asc)RNK                  
  FROM LSQ_UB_UserTask_Base
   WHERE TaskType in (select CODE from DM_CodeInclusionExclusion_Master where TypeFlag='Tasktype_002' and IncORExc='Include')  
  --TaskType ='f0dc0c93-cd31-11ed-b683-02b0de8eaa1e'
  ) UT
  WHERE RNK = 1 ) LSQ_UTBASE
  ON  --(LSQ_PBASE.OwnerId = LSQ_UTBASE.OwnerId) and
  (UB.ProspectId = LSQ_UTBASE.RelatedEntityId)

--------------- FIRST FOLLOWUP----------------
LEFT JOIN (SELECT RelatedProspectID,FirstfollowupDate, FirstIsCustomerContacted,FirstFollowupScheduleDate,mx_custom_2,mx_custom_3 FROM (
select RelatedProspectID,mx_Custom_1 as FirstIsCustomerContacted,mx_custom_5 as FirstFollowupScheduleDate,
createdon FirstfollowupDate, mx_custom_2 , mx_custom_3,
ROW_NUMBER()OVER(PARTITION BY RelatedProspectID ORDER BY CREATEDON ASC) AS RNK 
from LSQ_UB_PROSPECTACTIVITY_EXTENSIONBASE 
where ActivityEvent = 205
--and mx_Custom_13 is not null
 ) A where RNK=1
) FIRST_FOLLOWUP
ON FIRST_FOLLOWUP.RelatedProspectID=UB.ProspectId
AND FIRST_FOLLOWUP.FirstFollowupDate>EXTUB.mx_dealer_assignment_Date

---- CRE Followup

LEFT JOIN (SELECT RelatedProspectID,CREfollowupDate, FirstIsCustomerContacted,CREFollowupScheduleDate,mx_custom_14,mx_custom_15 FROM (
select RelatedProspectID,mx_Custom_13 as FirstIsCustomerContacted,mx_custom_3 as CREFollowupScheduleDate,
createdon as CREfollowupDate, mx_custom_14 , mx_custom_15,
ROW_NUMBER()OVER(PARTITION BY RelatedProspectID ORDER BY CREATEDON ASC) AS RNK 
from LSQ_UB_PROSPECTACTIVITY_EXTENSIONBASE  
where ActivityEvent=214
) A where RNK=1
) CRE_FIRST_FOLLOWUP
ON CRE_FIRST_FOLLOWUP.RelatedProspectID=UB.ProspectId
AND DATEADD(mi,30,(DATEADD(hh,5,CRE_FIRST_FOLLOWUP.CREfollowupDate))) > DATEADD(mi,30,(DATEADD(hh,5,EXTUB.mx_Dealer_Assignment_Date)))



---------------LATEST FOLLOWUP ------------------------------------------
LEFT JOIN (SELECT RelatedProspectID,LatestfollowupDate, LatestIsCustomerContacted,LatestFollowupScheduleDate,mx_custom_2,mx_custom_3 FROM (
select RelatedProspectID,mx_Custom_1 as LatestIsCustomerContacted,mx_custom_5 as LatestFollowupScheduleDate,
createdon LatestfollowupDate, mx_custom_2 , mx_custom_3,
ROW_NUMBER()OVER(PARTITION BY RelatedProspectID ORDER BY CREATEDON DESC) AS RNK 
from LSQ_UB_PROSPECTACTIVITY_EXTENSIONBASE 
where ActivityEvent = 205
--and mx_Custom_13 is not null 
) A where RNK=1
) LATEST_FOLLOWUP
ON LATEST_FOLLOWUP.RelatedProspectID=UB.ProspectId
AND LATEST_FOLLOWUP.LatestFollowupDate>EXTUB.mx_dealer_assignment_Date

 -------TestRIDE Logic------------------------------------------------------
  LEFT JOIN (select RelatedProspectID , ROW_NUMBER() OVER (PARTITION BY RelatedProspectID ORDER BY createdon DESC) AS RANK1
  from 
  LSQ_UB_PROSPECTACTIVITY_EXTENSIONBASE 
  where ActivityEvent=204 
  AND STATUS='Completed'
  )LSQ_TESTRIDE
  ON LSQ_TESTRIDE.RelatedProspectID=UB.ProspectId
  AND LSQ_TESTRIDE.RANK1=1
  
    -------Sales_Demo Logic------------------------------------------------------
  LEFT JOIN (select RelatedProspectID, mx_Custom_1, ROW_NUMBER() OVER (PARTITION BY RelatedProspectID ORDER BY createdon DESC) AS RANK2 
  from 
  LSQ_ub_ProspectActivity_ExtensionBase 
  where ActivityEvent = 216
  --and mx_Custom_1='Yes'  
  )LSQ_Sales_Demo

  ON LSQ_Sales_Demo.RelatedProspectID=UB.ProspectId
  AND LSQ_Sales_Demo.RANK2=1
  
 WHERE EXTUB.mx_Dealer_Assignment_Date IS NOT NULL
 AND CAST(UB.Modifiedon AS DATE) >= CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_UB_ENQUIRY_DIM) AS DATE)
 --(SELECT CASE WHEN (SELECT COUNT(*) FROM ASM_UB_ENQUIRY_DIM)=0 THEN '1900-01-01 00:00:00.0000' ELSE MAX(IMPORTEDDATE) END FROM ASM_UB_ENQUIRY_DIM)
 
 
 
 -------------------Update-------(update for new column in Enq Dim- Booking Flag)-------
 Update Dim
 SET Dim.Booking_Flag=
 CASE 
WHEN CAST( DATEDIFF(hour,DATEADD(mi,30,(DATEADD(hh,5,EXTUB.mx_Dealer_Assignment_Date))), BH.DOCDATE) AS INT) <=4 THEN  '<4 Hrs'               
WHEN CAST( DATEDIFF(hour,DATEADD(mi,30,(DATEADD(hh,5,EXTUB.mx_Dealer_Assignment_Date))), BH.DOCDATE) AS INT) >4 then '>4 Hrs'
else 'Not Booked' End
 from ASM_UB_ENQUIRY_DIM Dim 
 LEFT JOIN LSQ_UB_PROSPECT_EXTENSIONBASE EXTUB ON 
Dim.PK_EnquiryProspectID=EXTUB.ProspectID
LEFT JOIN BOOKING_HEADER_EXT BHE on 
SUBSTRING(BHE.LMSBOOKINGID,0,CHARINDEX(',',BHE.LMSBOOKINGID,0)) = Dim.PK_EnquiryProspectID
LEFT JOIN BOOKING_HEADER BH ON BH.HEADERID = BHE.HEADERID

---------------------------Update Sessiontime ---------------------------------------

SELECT
    COUNT(DISTINCT (CASE 
        WHEN Sessiontime >= 120 THEN PK_EnquiryProspectID 
        ELSE NULL 
    END)) AS ENQUIRY_SESSIONTIME_MORETHAN_2MINS, e.PK_EnquiryProspectID
INTO #Sessiontime
FROM (
    SELECT 
        STG.PK_EnquiryProspectID,
        SUM(EZ.TotalSessionTime) AS Sessiontime
    FROM ASM_UB_ENQUIRY_DIM STG
    INNER JOIN EXT_ZERSYS_SALES_DEMO_DATA EZ
        ON STG.PK_EnquiryProspectID = EZ.Enquiry
    GROUP BY STG.PK_EnquiryProspectID
) AS e
group by e.PK_EnquiryProspectID;

UPDATE DIM
SET ENQUIRY_SESSIONTIME_MORETHAN_2MINS= EZSDD.ENQUIRY_SESSIONTIME_MORETHAN_2MINS
FROM  ASM_UB_ENQUIRY_DIM DIM
INNER JOIN #Sessiontime EZSDD
ON DIM.PK_EnquiryProspectID =EZSDD.PK_EnquiryProspectID


-------------------------------------------------------------------------------------------------------------------------------------------
Delete from ASM_UB_ENQUIRY_DIM Where Cast(EnquiryDate as date)>Cast(Getdate()-1 as date);

--Dedup Process:
  WITH CTE AS                  
 (                  
  SELECT *,                  
  -- ROW_NUMBER()OVER(PARTITION BY PK_EnquiryProspectID ORDER BY IMPORTEDDATE DESC)RNK  
  ROW_NUMBER() OVER (
    PARTITION BY PK_EnquiryProspectID 
    ORDER BY LEN(ISSAMEDAYBOOKING) DESC,LEN(ISSameDayClosed) DESC, IMPORTEDDATE DESC) RNK 
  FROM ASM_UB_ENQUIRY_DIM                  
 )                  
DELETE FROM CTE                 
 WHERE RNK<>1; 

----------------------------------Audit Log Target

    END TRY
    BEGIN CATCH
        SET @Status1 = 'FAILURE';
        SET @ErrorMessage1 = ERROR_MESSAGE();
        THROW;  
    END CATCH
    SET @EndDate_utc1 = GETDATE();
	SET @EndDate_ist1 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));
    SET @Duration_sec1 = DATEDIFF(SECOND, @StartDate_ist1, @EndDate_ist1);
	SET @Duration1 = CONVERT(VARCHAR(8), DATEADD(SECOND, @Duration_sec1, 0), 108);
    EXEC [USP_Audit_Balance_Control_Logs] 
	     @SPID,
        @sp_name,
		@table_name1,
        'Sales',
        'UB',
        @StartDate_utc1,
        @EndDate_utc1,
		@StartDate_ist1,
        @EndDate_ist1,
        @Duration1,  
        0,
        0,
        @Status1,
        @ErrorMessage1;
 ---------------------------------------------------------------------------------------------------
 /* Step 2 : Loading Enquiry STAGE FACT */
 -- TRUNCATE TABLE ASM_UB_ENQUIRY_STG

---------------------------------------------------------------
    -- Audit Segment 1: ASM_UB_ENQUIRY_STG
----------------------------------------------------------------  

DECLARE @StartDate_utc2 DATETIME = GETDATE(),
            @EndDate_utc2 DATETIME,
			@StartDate_ist2 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist2 DATETIME,
            @Duration_sec2 bigint,
			@Duration2 varchar(15),
			@table_name2 VARCHAR(128) = 'ASM_UB_ENQUIRY_STG', 
            @SourceCount2 BIGINT,  
            @TargetCount2 BIGINT,   
            @Status2 VARCHAR(10),
            @ErrorMessage2 VARCHAR(MAX);  
BEGIN TRY

INSERT INTO ASM_UB_ENQUIRY_STG
SELECT DEALERCODE, 
SKU,
FK_DEALERCODE, 
FK_SKU,  
FK_TYPE_ID,
DATE,
FK_EnquiryProspectID,
ProspectActivityExtensionId,
COMPANYTYPE,
BRANCHID,
Isnull(Count(ProspectID),0) as ACTUALQUANTITY ,
TARGETQUANTITY,
LASTUPDATEDDATETIME,
IMPORTEDDATE,
PERIODNAME,
COLOUR_CODE, 
MODELCODE, 
FK_MODEL,
FLAG,
TEHSILID,
'' AS SALESPERSON,
LeadType,
SALESPERSON_ID,
First_Source_Lead_type,
SourceOfEnquiry,
SubSourceOfEnquiry,
mx_dse_enquiry_status,
mx_Lead_Score,
mx_first_lead_classification,
First_Mode_Source,
First_Mode_SubSource
 FROM 
(SELECT
	DISTINCT
	CM.CODE AS DEALERCODE,
	IM.CODE + IV.CODE SKU, 
	Cast(0 as int) as FK_DEALERCODE,
	Cast(0 as int) as FK_SKU,
	10001 As FK_TYPE_ID,
	--Cast(EXTUB.mx_Dealer_Assignment_Date As Date) As DATE,
	LTRIM(CAST(DATEADD(mi,30,(DATEADD(hh,5,EXTUB.mx_Dealer_Assignment_Date)))AS DATE),10) as date,
	ACTEXT.ProspectActivityExtensionId as ProspectActivityExtensionId,
	UB.ProspectID as FK_EnquiryProspectID,
	BM.BRANCHID,
	10 AS COMPANYTYPE,
    Isnull((UB.ProspectID),0) as ProspectID,
	getdate() as LASTUPDATEDDATETIME,
	UB.Modifiedon AS IMPORTEDDATE,
	Cast(0 as decimal(19,0)) As TARGETQUANTITY,
	(LEFT(DATENAME( MONTH,DATEADD(mi,30,(DATEADD(hh,5,EXTUB.mx_Dealer_Assignment_Date)))),3)+'-'+Cast(Year(DATEADD(mi,30,(DATEADD(hh,5,EXTUB.mx_Dealer_Assignment_Date)))) as varchar(4))) As PERIODNAME,
	IV.CODE AS COLOUR_CODE, 
    IM.CODE AS ModelCode,
	Cast(0 as int) as FK_MODEL,
	100011 As FLAG,
	NULL AS TEHSILID,
    ISNULL(UB.mx_Enquiry_Mode,'Not Available') AS LeadType,
	UB.OWNERID AS SALESPERSON_ID,
	CASE when Cast(EXTUB.mx_Dealer_Assignment_Date As Date) >='2024-12-01' THEN  EXTUB.MX_QUALIFIED_FIRST_SOURCE
	ELSE 'Not Available' END AS First_Source_Lead_type,
	UB.MX_SOURCE_OF_ENQUIRY AS SourceOfEnquiry,
	UB.mx_Enquiry_Subsource AS SubSourceOfEnquiry,
	EXTUB.mx_dse_enquiry_status,
	EXTUB.mx_Lead_Score,
	EXTUB.mx_first_lead_classification,
	ISNULL(EXTUB.mx_Qualified_Source_of_Enquiry,'Not Available') AS First_Mode_Source,
   ISNULL(EXTUB.mx_Qualified_Sub_Source,'Not Available') AS First_Mode_SubSource
	
FROM LSQ_UB_PROSPECT_BASE UB
JOIN BRANCH_MASTER BM WITH (NOLOCK) ON BM.CODE=UB.mx_Branch_Code
JOIN COMPANY_MASTER CM WITH (NOLOCK) ON CM.COMPANYID=BM.COMPANYID
LEFT JOIN LSQ_UB_PROSPECT_EXTENSIONBASE EXTUB ON UB.ProspectID=EXTUB.ProspectID

LEFT JOIN LSQ_UB_PROSPECTACTIVITY_BASE ACT ON ACT.RelatedProspectID = UB.ProspectID

INNER JOIN LSQ_UB_PROSPECTACTIVITY_EXTENSIONBASE ACTEXT ON ACT.ProspectActivityID=ACTEXT.RelatedProspectActivityID
and UB.ProspectID=ACTEXT.RelatedProspectID
AND ACTEXT.ActivityEvent=12000

LEFT JOIN LSQ_UB_CUSTOMOBJECTPROSPECTACTIVITY_BASE  LSQ_CUSTPACT 
ON LSQ_CUSTPACT.RelatedProspectActivityID=ACTEXT.RelatedProspectActivityID
AND LSQ_CUSTPACT.CustomObjectProspectActivityId=ACTEXT.mx_custom_4

LEFT JOIN  ITEM_MASTER IM WITH (NOLOCK) ON cast(IM.ITEMID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_7
    
LEFT JOIN ITEMVARMATRIX_MASTER IV WITH (NOLOCK)  ON cast(IV.ITEMVARMATRIXID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_8
  
where EXTUB.mx_Dealer_Assignment_Date is not null 
 AND CAST(UB.Modifiedon AS DATE) >= CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_UB_ENQUIRY_STG) AS DATE)
 --(SELECT CASE WHEN (SELECT COUNT(*) FROM ASM_UB_ENQUIRY_STG)=0 THEN '1900-01-01 00:00:00.0000' ELSE MAX(IMPORTEDDATE) END FROM ASM_UB_ENQUIRY_STG)
 
	) TMP
	GROUP BY 
DEALERCODE, SKU,FK_DEALERCODE, FK_SKU,  FK_TYPE_ID,DATE,ProspectActivityExtensionId,
 FK_ENQUIRYProspectID,BRANCHID, COMPANYTYPE,LASTUPDATEDDATETIME,IMPORTEDDATE ,TARGETQUANTITY,PERIODNAME
,COLOUR_CODE, MODELCODE, FK_MODEL,FLAG, TEHSILID,LeadType,SALESPERSON_ID, First_Source_Lead_type,SourceOfEnquiry,
SubSourceOfEnquiry,mx_dse_enquiry_status, mx_Lead_Score, mx_first_lead_classification,First_Mode_Source,First_Mode_SubSource
--------------------------------------------------------------------------------------------
 /* Step 3 : Dedup data if any*/ 

Delete from ASM_UB_ENQUIRY_STG Where DATE>Cast(Getdate()-1 as date)  ;
--Dedup Process:
WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_ENQUIRYProspectID,ProspectActivityExtensionId ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_UB_ENQUIRY_STG                 
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;  


 ----------------------------------------------------------------------------------------------
  /* Step 4 : Update Model, Dealer, sku FK*/
update B set B.FK_SKU=C.PK_SKU from ASM_UB_ENQUIRY_STG B INNER JOIN ASM_UB_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE);
update B set B.FK_MODEL=C.PK_Model_Code from ASM_UB_ENQUIRY_STG B INNER JOIN ASM_UB_PRODUCT_DIM C on (B.MODELCODE=C.MODELCODE);
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from ASM_UB_ENQUIRY_STG B INNER JOIN ASM_UB_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE);


------------------------------------------------------------------------------------------------------------
  /* Step 4 : Loading Enquiry Fact*/
Truncate table ASM_UB_ENQUIRY_FACT

INSERT INTO ASM_UB_ENQUIRY_FACT
SELECT * FROM ASM_UB_ENQUIRY_STG
----------------------------------------------------------------------------------------------------------

drop table #Sessiontime

----------------------------------Audit Log Target

    END TRY
    BEGIN CATCH
        SET @Status2 = 'FAILURE';
        SET @ErrorMessage2 = ERROR_MESSAGE();
        THROW;  
    END CATCH
    SET @EndDate_utc2 = GETDATE();
	SET @EndDate_ist2 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));
    SET @Duration_sec2 = DATEDIFF(SECOND, @StartDate_ist2, @EndDate_ist2);
	SET @Duration2 = CONVERT(VARCHAR(8), DATEADD(SECOND, @Duration_sec2, 0), 108);
    EXEC [USP_Audit_Balance_Control_Logs] 
	     @SPID,
        @sp_name,
		@table_name2,
        'Sales',
        'UB',
        @StartDate_utc2,
        @EndDate_utc2,
		@StartDate_ist2,
        @EndDate_ist2,
        @Duration2,  
        0,
        0,
        @Status2,
        @ErrorMessage2;

END

GO