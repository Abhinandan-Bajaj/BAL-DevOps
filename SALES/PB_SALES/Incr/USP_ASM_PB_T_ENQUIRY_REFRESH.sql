/****** Object:  StoredProcedure [dbo].[USP_Full_Load_ASM_PB_T_ENQUIRY_REFRESH]    Script Date: 6/26/2025 8:13:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USP_ASM_PB_T_ENQUIRY_REFRESH] AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION				                        	*/
/*--------------------------------------------------------------------------------------------------*/
/*  2025-07-18 	|	Lachmanna		        | Newly Added script for K+T        */
/*  2025-09-25 	|	Lachmanna		        | Newly Added No of Followup  and   Followup Bucket CR      */
/*  2025-09-25 	|	Lachmanna		        | Newly added CRE Followup  and   Followup Bucket BUG      */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
--1. Enquiry Dim & Fact:

--*/ 
 --Truncate table ASM_PB_T_ENQUIRY_DIM

 
declare @ASMDim_IMPORTEDDATE date;
set @ASMDim_IMPORTEDDATE = CAST((SELECT  MAX(IMPORTEDDATE) FROM ASM_PB_T_ENQUIRY_DIM)AS DATE);
declare @ASMStg_IMPORTEDDATE date;
set @ASMStg_IMPORTEDDATE =CAST((SELECT  MAX(IMPORTEDDATE) FROM ASM_PB_T_ENQUIRY_STG) AS DATE);


DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_PB_T_ENQUIRY_REFRESH';

----------------------------------------------------------------
    -- Audit Segment 1: ASM_PB_T_ENQUIRY_DIM
----------------------------------------------------------------  

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			@table_name1 VARCHAR(128) = 'ASM_PB_T_ENQUIRY_DIM', 
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT,   
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX); 


BEGIN TRY
        SELECT @SourceCount1 =  COUNT( LSQ_PBASE.ProspectId)  FROM LSQ_Prospect_Base LSQ_PBASE   
  INNER JOIN DBO.BRANCH_MASTER BM 
  ON LSQ_PBASE.mx_Branch_Code=BM.CODE
    
  INNER JOIN DBO.COMPANY_MASTER CM 
  ON CM.COMPANYID=BM.COMPANYID
  AND (CM.COMPANYTYPE=2 )
  
  LEFT  JOIN LSQ_Prospect_ExtensionBase LSQ_PEXTBASE 
  ON (LSQ_PBASE.ProspectId = LSQ_PEXTBASE.ProspectId)

  INNER JOIN LSQ_ProspectActivity_ExtensionBase LSQ_PACTEXTBASE 
  ON (LSQ_PBASE.ProspectId = LSQ_PACTEXTBASE.RelatedProspectID) 
  AND LSQ_PACTEXTBASE.ActivityEvent=12002 
     LEFT JOIN LSQ_CustomObjectProspectActivity_Base LSQ_CUSTPACT
    ON LSQ_CUSTPACT.RelatedProspectActivityID=LSQ_PACTEXTBASE.RelatedProspectActivityID
    AND LSQ_CUSTPACT.CustomObjectProspectActivityId=LSQ_PACTEXTBASE.mx_custom_14
    LEFT JOIN ITEM_MASTER IM
    ON cast(IM.ITEMID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_11
   INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM ) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND in('TRIUMPH') and rnk = 1
  WHERE LSQ_PEXTBASE.mx_Dealer_Assignment_Date is not null
	and LSQ_PEXTBASE.mx_BU_sub_type='PB'
	and Cast(LSQ_PEXTBASE.mx_Dealer_Assignment_Date As Date) = Cast(Getdate()-1 as date)

 
IF(OBJECT_ID('TempDB..#LSQ_UTBASE','U') IS NOT NULL)
BEGIN
    DROP TABLE #LSQ_UTBASE
END

CREATE TABLE #LSQ_UTBASE (
    OwnerId VARCHAR(100),             
    DueDate DATETIME,
    RelatedEntityId VARCHAR(100),
    TaskType VARCHAR(100),
    CreatedON DATETIME
)
WITH
(
  	DISTRIBUTION = HASH(RelatedEntityId),
	CLUSTERED COLUMNSTORE INDEX
);

IF(OBJECT_ID('TempDB..#LSQ_ProspectId','U') IS NOT NULL)
BEGIN
    DROP TABLE #LSQ_ProspectId
END

CREATE TABLE #LSQ_ProspectId (
    ProspectId VARCHAR(100)  )
WITH ( DISTRIBUTION = HASH(ProspectId),
	CLUSTERED COLUMNSTORE INDEX );
INSERT INTO #LSQ_ProspectId
SELECT ProspectId
FROM LSQ_Prospect_Base WHERE DATEADD(MINUTE, 30, DATEADD(HOUR, 5, ModifiedOn)) >= @ASMDim_IMPORTEDDATE;

INSERT INTO #LSQ_UTBASE
SELECT   OwnerId,DueDate,RelatedEntityId, TaskType,CreatedON                  
FROM LSQ_UserTask_Base U  WHERE TaskType in(
select CODE from DM_CodeInclusionExclusion_Master where TypeFlag='Tasktype_001' and IncORExc='Include')
and  convert(varchar(500),U.RelatedEntityId) IN (  SELECT ProspectId   FROM #LSQ_ProspectId )

INSERT INTO ASM_PB_T_ENQUIRY_DIM
SELECT DISTINCT
				LSQ_PBASE.ProspectId AS PK_EnquiryHeaderID,
				LTRIM (Cast(LSQ_PEXTBASE.mx_Dealer_Assignment_Date As DATE),10) As EnquiryDate,
               '' AS EnquiryDaysBucket,
               LSQ_PBASE.mx_Enquiry_Mode AS EnquiryMedium,
               CASE WHEN FIRST_FOLLOWUP.RelatedProspectID is Not null then 'Yes' Else 'No' END AS EnquiryFollowUp, 
               /*SOURCE_OF_ENQUIRY.NAME*/LSQ_PBASE.mx_Source_Of_Enquiry AS EnquiryLeadSource,  
               LSQ_PBASE.ProspectStage AS EnquiryStatus, 
               /*EH.ISTESTRIDETAKEN*/ CAST(Null AS INT) AS IsTestRideTaken ,
               LSQ_TESTRIDE.STATUS AS TestRideOffered,
               LSQ_PBASE.mx_type_of_customer AS CustomerOwnershipProfileId ,
               LSQ_PBASE.mx_payment_mode AS ModeOfPurchase,
               LSQ_PBASE.mx_Enquiry_Mode AS LeadType,
               LSQ_PBASE.mx_Source_Of_Enquiry AS SourceType, 
                   LSQ_PBASE.mx_Enquiry_Sub_source AS SubSourceOfEnquiry,
               --LSQ_PBASE.mx_Enquiry_Sub_source AS EnquirySubsource,  
               CASE WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('BOOKED','ALLOCATED') THEN 'Booked'
               WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('INVOICED','DELIVERED') THEN 'Invoiced'
               WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('LOST' ,'AUTO - CLOSED' ,'CLOSED' ,'LOST TO COMPETITION' ,'LOST TO CO-DEALER') THEN 'Lost' 
               WHEN UPPER(LSQ_PBASE.ProspectStage) IN ('VISITED' ,'CONTACTED' ,'OPEN' ,'TEST RIDE CANCELLED' ,'QUALIFIED' ,'PROSPECT' ,'TEST RIDE COMPLETED' ,'TEST RIDE BOOKED' ,'TEST RIDE RESCHEDULED') THEN 'Open' END AS LEADSTATUS,
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
               GETDATE() AS CREATEDDATETIME,
               LSQ_PBASE.ModifiedOn as IMPORTEDDATE,
               CAST(Null AS INT) as CDMS_BATCHNO, -- EXCLUSIVE to CDMS
               Cast(0 as int) As RetailConversionFlag,
               LSQ_PBASE.mx_Exchange AS IsExchangeApplicable,
               NULL AS FinanceCompany, -- EXCLUSIVE to CDMS
               1 AS BaseFlag,
               Case when LSQ_PBASE.mx_Need_Assessment=1 THEN 'Yes' when LSQ_PBASE.mx_Need_Assessment=0 then 'No' Else LSQ_PBASE.mx_Need_Assessment END AS IsNeedsAssessment,
               CASE WHEN LSQ_Sales_Demo.mx_Custom_1='Yes' THEN 'Yes' ELSE 'No' END AS IsDemo,
               CASE WHEN LSQ_PEXTBASE.mx_Visited ='Yes' THEN 'Yes' ELSE 'No' END AS IsVisited,
               LSQ_PBASE.MX_AREA AS Area,
               LSQ_PBASE.Mx_pincode as Pincode, 
               LSQ_PBASE.Mx_salesperson as SalesPerson,
               FIRST_FOLLOWUP.FirstFollowupDate,
			   FIRST_FOLLOWUP.FirstIsCustomerContacted,
			   FIRST_FOLLOWUP.FirstFollowupScheduleDate,
			   LATEST_FOLLOWUP.LatestFollowupDate,
			   LATEST_FOLLOWUP.LatestFollowupScheduleDate,
			   LATEST_FOLLOWUP.LatestIsCustomerContacted,
			  
				/*CASE 
				WHEN LSQ_PEB.mx_Non_Working_Hour = 'yes' 
				AND (CONVERT(TIME, DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))) NOT BETWEEN '08:00:00' AND '17:00:00')
				THEN */
			/*CASE 
				WHEN LSQ_PEB.mx_Non_Working_Hour = 'yes' 
				--AND (CONVERT(TIME, DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))) NOT BETWEEN '08:00:00' AND '17:00:00')
				THEN */
					CASE 
				WHEN CAST(DATEDIFF(MINUTE, LSQ_UTBASE.DueDate,COALESCE(CRE_FIRST_FOLLOWUP.CREfollowupDate , FIRST_FOLLOWUP.FirstFollowupDate)) AS INT) <= 120 THEN '<3 Hrs'
				WHEN CAST(DATEDIFF(MINUTE, LSQ_UTBASE.DueDate,COALESCE(CRE_FIRST_FOLLOWUP.CREfollowupDate , FIRST_FOLLOWUP.FirstFollowupDate)) AS INT) BETWEEN 121 AND 1380 THEN '3-24 Hrs'
				WHEN CAST(DATEDIFF(MINUTE, LSQ_UTBASE.DueDate,COALESCE(CRE_FIRST_FOLLOWUP.CREfollowupDate , FIRST_FOLLOWUP.FirstFollowupDate)) AS INT) > 1380 THEN '>24 Hrs' --  END
			/*ELSE --WHEN LSQ_PEB.mx_Non_Working_Hour IS NULL THEN 
			CASE 
				WHEN CAST(DATEDIFF(MINUTE, LSQ_PEXTBASE.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT)< 180 THEN '<3 Hrs'
				WHEN CAST(DATEDIFF(MINUTE, LSQ_PEXTBASE.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) BETWEEN 180 AND 1440 THEN '3-24 Hrs'
				WHEN CAST(DATEDIFF(MINUTE, LSQ_PEXTBASE.mx_Dealer_Assignment_Date, FIRST_FOLLOWUP.FirstFollowupDate) AS INT) > 1440 THEN '>24 Hrs'  END */
			END AS FollowupBucket,
			   null as LeadLostSecondaryReason,
			   LSQ_PACTEXTBASE.mx_Custom_87 AS IsTestRideBooked,
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
       as Follow_up_Dispositions,
	   cast(0 as int) as No_of_Follow_ups
FROM
  LSQ_Prospect_Base LSQ_PBASE 
  
  INNER JOIN DBO.BRANCH_MASTER BM 
  ON LSQ_PBASE.mx_Branch_Code=BM.CODE
    
  INNER JOIN DBO.COMPANY_MASTER CM 
  ON CM.COMPANYID=BM.COMPANYID
  AND (CM.COMPANYTYPE=2)-- AND CM.COMPANYSUBTYPE='Triumph')
  
  LEFT  JOIN LSQ_Prospect_ExtensionBase LSQ_PEXTBASE 
  ON (LSQ_PBASE.ProspectId = LSQ_PEXTBASE.ProspectId)

  INNER JOIN LSQ_ProspectActivity_ExtensionBase LSQ_PACTEXTBASE 
  ON (LSQ_PBASE.ProspectId = LSQ_PACTEXTBASE.RelatedProspectID) 
  AND LSQ_PACTEXTBASE.ActivityEvent=12002 
 ---------- 
  LEFT  JOIN LSQ_Prospect_Extension2Base LSQ_PEB
  ON  (LSQ_PBASE.ProspectId = LSQ_PEB.ProspectId) 

  --newly added for testing
   LEFT JOIN LSQ_CustomObjectProspectActivity_Base LSQ_CUSTPACT
    ON LSQ_CUSTPACT.RelatedProspectActivityID=LSQ_PACTEXTBASE.RelatedProspectActivityID
    AND LSQ_CUSTPACT.CustomObjectProspectActivityId=LSQ_PACTEXTBASE.mx_custom_14
    
    LEFT JOIN ITEM_MASTER IM
    ON cast(IM.ITEMID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_11

   INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND in('TRIUMPH') and rnk = 1
  
    LEFT JOIN (select DueDate,OwnerId,RelatedEntityId,TaskType,CreatedON  from
 (SELECT DueDate,OwnerId,RelatedEntityId, TaskType,CreatedON, ROW_NUMBER()OVER(PARTITION BY RelatedEntityId ORDER BY CreatedON Asc)RNK                  
  FROM #LSQ_UTBASE  ) UT
  WHERE RNK = 1 ) LSQ_UTBASE
  ON  --(LSQ_PBASE.OwnerId = LSQ_UTBASE.OwnerId) and
  (LSQ_PBASE.ProspectId = LSQ_UTBASE.RelatedEntityId) 
  
--------------- FIRST FOLLOWUP----------------

LEFT JOIN (SELECT RelatedProspectID,FirstfollowupDate, FirstIsCustomerContacted,FirstFollowupScheduleDate FROM (
select RelatedProspectID,mx_Custom_13 FirstIsCustomerContacted,mx_custom_3 as FirstFollowupScheduleDate,
createdon FirstfollowupDate,
ROW_NUMBER()OVER(PARTITION BY RelatedProspectID ORDER BY CREATEDON ASC) AS RNK 
from LSQ_ProspectActivity_ExtensionBase 
where ActivityEvent=213
and mx_Custom_13 is not null ) A where RNK=1
) FIRST_FOLLOWUP
ON FIRST_FOLLOWUP.RelatedProspectID=LSQ_PBASE.ProspectId
AND FIRST_FOLLOWUP.FirstFollowupDate>LSQ_PEXTBASE.mx_dealer_assignment_Date

--------------- CRE FOLLOWUP----------------
LEFT JOIN (SELECT RelatedProspectID,CREfollowupDate, FirstIsCustomerContacted,CREFollowupScheduleDate,mx_custom_14,mx_custom_15 FROM (
select RelatedProspectID,mx_Custom_13 as FirstIsCustomerContacted,mx_custom_3 as CREFollowupScheduleDate,
createdon as CREfollowupDate, mx_custom_14 , mx_custom_15,
ROW_NUMBER()OVER(PARTITION BY RelatedProspectID ORDER BY CREATEDON ASC) AS RNK 
from LSQ_PROSPECTACTIVITY_EXTENSIONBASE  
where ActivityEvent=237
) A where RNK=1
) CRE_FIRST_FOLLOWUP
ON CRE_FIRST_FOLLOWUP.RelatedProspectID=LSQ_PBASE.ProspectId
AND DATEADD(mi,30,(DATEADD(hh,5,CRE_FIRST_FOLLOWUP.CREfollowupDate))) > DATEADD(mi,30,(DATEADD(hh,5,LSQ_PEXTBASE.mx_Dealer_Assignment_Date)))

---------------LATEST FOLLOWUP ------------------------------------------
LEFT JOIN (SELECT RelatedProspectID,LatestFollowupDate, LatestIsCustomerContacted,LatestFollowupScheduleDate FROM (
select RelatedProspectID,mx_Custom_13 LatestIsCustomerContacted,mx_custom_3 as LatestFollowupScheduleDate,
createdon LatestFollowupDate,
ROW_NUMBER()OVER(PARTITION BY RelatedProspectID ORDER BY CREATEDON DESC) AS RNK 
from LSQ_ProspectActivity_ExtensionBase 
where ActivityEvent=213
and mx_Custom_13 is not null ) B where RNK=1
)LATEST_FOLLOWUP
ON LATEST_FOLLOWUP.RelatedProspectID=LSQ_PBASE.ProspectId
AND LATEST_FOLLOWUP.LatestFollowupDate> LSQ_PEXTBASE.mx_dealer_assignment_Date


  
 -------TestRIDE Logic------------------------------------------------------
  LEFT JOIN (select RelatedProspectID,STATUS , ROW_NUMBER() OVER (PARTITION BY RelatedProspectID ORDER BY createdon DESC) AS RANK1
  from 
  LSQ_ProspectActivity_ExtensionBase 
  where ActivityEvent IN (201,202) 
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
	--and LSQ_PEXTBASE.mx_BU_sub_type='TRM'
	--AND CAST(LSQ_PBASE.ModifiedOn AS DATE) BETWEEN '2025-06-09' AND Cast(Getdate()-1 as date)  
 AND LSQ_PBASE.ModifiedOn >= @ASMDim_IMPORTEDDATE; 

/* ------------------------------------------------------------------------------------------------------------------------------------
--------------------Dedup--------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------*/ 
  Delete from ASM_PB_T_ENQUIRY_DIM Where Cast(EnquiryDate as date)>Cast(Getdate()-1 as date)

--Dedup Process:
  ;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_EnquiryHeaderID,EnquiryFollowUp ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_T_ENQUIRY_DIM                  
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;  
	
	---------No of fllow up 
Update ED
Set ED.No_of_Follow_ups=ERC.No_of_Follow_ups
From ASM_PB_T_ENQUIRY_DIM ED  JOIN  (
select RelatedProspectID,count(RelatedProspectID) as No_of_Follow_ups 
from LSQ_ProspectActivity_ExtensionBase 
where ActivityEvent=213
and mx_Custom_13 is not null 
and convert(date,CREATEDON)>='2022-08-11' 
group by RelatedProspectID
) ERC on ED.PK_EnquiryHeaderID=ERC.RelatedProspectID


----------------------------------Audit Log Target

SELECT @TargetCount1 = COUNT( PK_EnquiryHeaderID) FROM ASM_PB_T_ENQUIRY_DIM where EnquiryDate= Cast(Getdate()-1 as date);
        IF @SourceCount1 <> @TargetCount1
        BEGIN
            SET @Status1 = 'WARNING';  
            SET @ErrorMessage1 = CONCAT('Record count mismatch. Source=', @SourceCount1, ', Target=', @TargetCount1);
        END
        ELSE
        BEGIN
            SET @Status1 = 'SUCCESS';
            SET @ErrorMessage1 = NULL;
        END
    END TRY
    BEGIN CATCH
        SET @Status1 = 'FAILURE';
        SET @ErrorMessage1 = ERROR_MESSAGE();
        THROW;  
    END CATCH
    SET @EndDate_utc1 = GETDATE();
	SET @EndDate_ist1 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));
	SET @Duration1 = CONVERT(VARCHAR(8), DATEADD(SECOND, @Duration_sec1, 0), 108);
    EXEC [USP_Audit_Balance_Control_Logs] 
	     @SPID,
        @sp_name,
		@table_name1,
        'Sales',
        'PB-TRM',
        @StartDate_utc1,
        @EndDate_utc1,
		@StartDate_ist1,
        @EndDate_ist1,
        @Duration1,  
        @SourceCount1,
        @TargetCount1,
        @Status1,
        @ErrorMessage1;
	
/* ------------------------------------------------------------------------------------------------------------------------------------
---------------------------STEP 2.2 LOAD LSQ Data into Enquiry Fact LSQ transactions Data----------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------- */
--Truncate table ASM_PB_T_ENQUIRY_STG


DECLARE @StartDate_utc2 DATETIME = GETDATE(),
        @EndDate_utc2 DATETIME,
	    @StartDate_ist2 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
        @EndDate_ist2 DATETIME,
		@Duration_sec2 bigint,
		@Duration2 varchar(15),
		@table_name2 VARCHAR(128) = 'ASM_PB_T_ENQUIRY_STG', 
        @SourceCount2 BIGINT,  
        @TargetCount2 BIGINT,   
        @Status2 VARCHAR(10),
        @ErrorMessage2 VARCHAR(MAX); 

BEGIN TRY
 SELECT @SourceCount2 = COUNT( LSQ_PBASE.ProspectId)  FROM LSQ_Prospect_Base LSQ_PBASE   
  INNER JOIN DBO.BRANCH_MASTER BM 
  ON LSQ_PBASE.mx_Branch_Code=BM.CODE
    
  INNER JOIN DBO.COMPANY_MASTER CM 
  ON CM.COMPANYID=BM.COMPANYID
  AND (CM.COMPANYTYPE=2 )
  
  LEFT  JOIN LSQ_Prospect_ExtensionBase LSQ_PEXTBASE 
  ON (LSQ_PBASE.ProspectId = LSQ_PEXTBASE.ProspectId)

  INNER JOIN LSQ_ProspectActivity_ExtensionBase LSQ_PACTEXTBASE 
  ON (LSQ_PBASE.ProspectId = LSQ_PACTEXTBASE.RelatedProspectID) 
  AND LSQ_PACTEXTBASE.ActivityEvent=12002 
     LEFT JOIN LSQ_CustomObjectProspectActivity_Base LSQ_CUSTPACT
    ON LSQ_CUSTPACT.RelatedProspectActivityID=LSQ_PACTEXTBASE.RelatedProspectActivityID
    AND LSQ_CUSTPACT.CustomObjectProspectActivityId=LSQ_PACTEXTBASE.mx_custom_14
    LEFT JOIN ITEM_MASTER IM
    ON cast(IM.ITEMID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_11
   INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND in('TRIUMPH') and rnk = 1
  WHERE LSQ_PEXTBASE.mx_Dealer_Assignment_Date is not null
	and LSQ_PEXTBASE.mx_BU_sub_type='PB'
	and Cast(LSQ_PEXTBASE.mx_Dealer_Assignment_Date As Date) = Cast(Getdate()-1 as date)

INSERT INTO ASM_PB_T_ENQUIRY_STG
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
   Cast(LSQ_PEXTBASE.mx_Dealer_Assignment_Date As Date) As DATE,
   LSQ_PACTEXTBASE.ProspectActivityExtensionId as ENQUIRYLINEID,
  LSQ_PBASE.ProspectID as FK_ENQUIRYDOCID, 
   2 AS COMPANYTYPE,
   BM.BRANCHID as BRANCHID,
   LSQ_PBASE.ProspectId,
   getdate() as LASTUPDATEDDATETIME,
   LSQ_PBASE.Modifiedon AS IMPORTEDDATE,
   null as CDMS_BATCHNO,
   Cast(0 as decimal(19,0)) As TARGETQUANTITY,
   (LEFT(DATENAME( MONTH,LSQ_PEXTBASE.mx_Dealer_Assignment_Date),3)+'-'+Cast(Year(LSQ_PEXTBASE.mx_Dealer_Assignment_Date) as varchar(4))) As   	   PERIODNAME,
   IV.CODE As COLOUR_CODE,
   IM.CODE As MODELCODE,
   Cast(0 as int) as FK_MODEL,
   100011 As FLAG,
   1 as BaseFlag,
   null as TEHSILID,
   REPLACE(REPLACE(REPLACE(REPLACE(UPPER(LSQ_User.Firstname),CHAR(160),''),' ',' |'),'| ',''),' |',' ') as SalesPerson,
   ISNULL(LSQ_PBASE.mx_Enquiry_Mode,'Not Available') AS LeadType,
   CASE WHEN CAST(LSQ_PEXTBASE.mx_Dealer_Assignment_Date AS DATE)>='2024-12-01' THEN COALESCE(PE.mx_Qualified_First_Source, LSQ_PBASE.mx_Enquiry_Mode,LSQ_PBASE.MX_MODE_OF_ENQUIRY,'Not Available')
   ELSE COALESCE(LSQ_PBASE.mx_Enquiry_Mode, LSQ_PBASE.MX_MODE_OF_ENQUIRY,'Not Available') END  AS First_Source_Lead_Type,
   ISNULL(PE.mx_Qualified_Source_of_Enquiry,'Not Available') AS First_Mode_Source,
   ISNULL(PE.mx_Qualified_Sub_Source,'Not Available') AS First_Mode_SubSource

   FROM
    LSQ_Prospect_Base LSQ_PBASE
 
	INNER JOIN DBO.BRANCH_MASTER BM 
	ON LSQ_PBASE.mx_Branch_Code=BM.CODE
    
	INNER JOIN DBO.COMPANY_MASTER CM 
	ON CM.COMPANYID=BM.COMPANYID
	AND (CM.COMPANYTYPE=2)-- AND CM.COMPANYSUBTYPE='Triumph')

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

	
    INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND in('TRIUMPH') and rnk = 1
    
    LEFT JOIN ITEMVARMATRIX_MASTER IV
    ON cast(IV.ITEMVARMATRIXID as VARCHAR(50))=LSQ_CUSTPACT.mx_CustomObject_14
    LEFT JOIN LSQ_users LSQ_User  on LSQ_PBASE.OwnerId=LSQ_User.UserId

    WHERE LSQ_PACTEXTBASE.ActivityEvent=12002 
	--and LSQ_PEXTBASE.mx_BU_sub_type='TRM'
	AND  LSQ_PBASE.mx_BU='PB'
    AND LSQ_PEXTBASE.mx_Dealer_Assignment_Date is not null
	--AND CAST(LSQ_PBASE.ModifiedOn AS DATE) BETWEEN '2025-06-09' AND Cast(Getdate()-1 as date)
	AND LSQ_PBASE.modifiedon >= @ASMStg_IMPORTEDDATE 
  ) TMP
	GROUP BY 
DEALERCODE, SKU,FK_DEALERCODE, FK_SKU,  FK_TYPE_ID,DATE,ENQUIRYLINEID,
 FK_ENQUIRYDOCID,COMPANYTYPE,BRANCHID,LASTUPDATEDDATETIME,IMPORTEDDATE,CDMS_BATCHNO ,TARGETQUANTITY,PERIODNAME
,COLOUR_CODE, MODELCODE, FK_MODEL,FLAG, BaseFlag,TEHSILID,SalesPerson,LeadType,First_Source_Lead_Type,First_Mode_Source,First_Mode_SubSource;

Delete from ASM_PB_T_ENQUIRY_STG Where DATE>Cast(Getdate()-1 as date)  ;
--Dedup Process:
WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_ENQUIRYDOCID,ENQUIRYLINEID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_T_ENQUIRY_STG                 
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;  
 
   --*****************************************************
  --*******************************************************
  --Step 2:
--Product Master and Dealer Master FK update: ASM_MC_ENQUIRY_STG
update B set B.FK_SKU=C.PK_SKU from ASM_PB_T_ENQUIRY_STG B INNER JOIN ASM_PB_HKT_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_PB_T_ENQUIRY_STG B INNER JOIN ASM_PB_HKT_PRODUCT_DIM C on (B.MODELCODE=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].[ASM_PB_T_ENQUIRY_STG] B INNER JOIN ASM_PB_HKT_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)


/* ------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------STEP 2.3  UNION of CDMS and LSQ Data---------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------- */

Truncate table ASM_PB_T_ENQUIRY_FACT

INSERT INTO ASM_PB_T_ENQUIRY_FACT
SELECT * FROM ASM_PB_T_ENQUIRY_STG



/* ------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------STEP 2.4  Update RetailConversionFlag for CDMS-----------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------- */

/* ------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------STEP 2.4  Update RetailConversionFlag for CDMS-----------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------- */

--RetailConversion Flag:

 -- Update RetailConversion Flag in ASM_MC_ENQUIRY_DIM:

INSERT INTO ASM_PB_T_ENQTORET_CONVERSION
SELECT DISTINCT 
EF.FK_ENQUIRYDOCID,
EF.DATE,
RetailConversionFlag=1,
EF.IMPORTEDDATE,
GETDATE() AS CREATEDDATETIME
FROM 
ASM_PB_T_ENQUIRY_FACT EF 
JOIN BOOKING_LINE BL ON (Cast(BL.ENQUIRYDATALINEID as Varchar(50))=EF.ENQUIRYLINEID ) 
JOIN RETAIL_LINE RL ON (BL.LINEID=RL.BOOKINGDATALINEID) 
WHERE [DATE]>(SELECT MAX(DATE) from ASM_PB_T_ENQTORET_CONVERSION)


Update ED
Set ED.RetailConversionFlag=ERC.RetailConversionFlag
From ASM_PB_T_ENQUIRY_DIM ED  JOIN ASM_PB_T_ENQTORET_CONVERSION ERC  ON (Cast(ERC.FK_ENQUIRYDOCID as Varchar(50))= ED.PK_EnquiryHeaderID) --(1638322 rows affected)

IF(OBJECT_ID('TempDB..#TEMP1','U') IS NOT NULL)
BEGIN
    DROP TABLE #TEMP1
END

SELECT HEADERID,LINEID, LMSBOOKINGID INTO #TEMP1
FROM 
( SELECT BH.HEADERID, LINE.LINEID, BHEXT.LMSBOOKINGID FROM
BOOKING_HEADER BH
INNER JOIN COMPANY_MASTER CM 
ON (BH.COMPANYID=CM.COMPANYID 
AND (CM.COMPANYTYPE =2  AND CM.COMPANYSUBTYPE='Triumph' ))
JOIN BOOKING_HEADER_EXT  BHEXT ON BH.HEADERID=BHEXT.HEADERID
JOIN BOOKING_LINE LINE ON LINE.HEADERID=BH.HEADERID
WHERE BH.BU='ProBiking'
and BHEXT.LMSBOOKINGID IS NOT NULL
)A;


Update ED
Set ED.RetailConversionFlag=1
FROM ASM_PB_T_ENQUIRY_DIM ED 
JOIN  LSQ_Prospect_Base LSQ_PBASE ON (LSQ_PBASE.ProspectId=ED.PK_EnquiryHeaderID)
JOIN LSQ_Prospect_ExtensionBase LSQ_PEXTBASE ON (LSQ_PBASE.ProspectId=LSQ_PEXTBASE.ProspectId) and LSQ_PEXTBASE.mx_BU_sub_type='TRM'
INNER JOIN DBO.BRANCH_MASTER BM ON LSQ_PBASE.mx_Branch_Code=BM.CODE
INNER JOIN DBO.COMPANY_MASTER CM ON CM.COMPANYID=BM.COMPANYID AND (CM.COMPANYTYPE=2 AND CM.COMPANYSUBTYPE='Triumph')
JOIN  LSQ_ProspectActivity_ExtensionBase PAE ON (LSQ_PBASE.ProspectID=PAE.RelatedProspectId and PAE.ActivityEvent=12002 and PAE.mx_Custom_48 IS NULL)
JOIN #TEMP1 TMP ON (Cast(LSQ_PBASE.ProspectID+','+PAE.ProspectActivityExtensionId as varchar(8000))=TMP.LMSBOOKINGID)
INNER JOIN ALLOCATION_LINE AL ON (TMP.LINEID=AL.BOOKINGDATALINEID)
INNER JOIN RETAIL_LINE RL ON (AL.LINEID=RL.ALLOCATIONDATALINEID)
WHERE ED.BaseFlag=1 
--AND LSQ_PBASE.mx_BU='PB'


----------------------------------Audit Log Target

SELECT @TargetCount2 = COUNT( FK_ENQUIRYDOCID) FROM ASM_PB_T_ENQUIRY_STG where Date= Cast(Getdate()-1 as date)
        IF @SourceCount2 <> @TargetCount2
        BEGIN
            SET @Status2 = 'WARNING';  
            SET @ErrorMessage2 = CONCAT('Record count mismatch. Source=', @SourceCount2, ', Target=', @TargetCount2);
        END
        ELSE
        BEGIN
            SET @Status2 = 'SUCCESS';
            SET @ErrorMessage2 = NULL;
        END
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
        'PB-TRM',
        @StartDate_utc2,
        @EndDate_utc2,
		@StartDate_ist2,
        @EndDate_ist2,
        @Duration2,  
        @SourceCount2,
        @TargetCount2,
        @Status2,
        @ErrorMessage2;


END
GO