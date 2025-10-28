SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[TradeIn_ExchangeAppLoad_SP] AS
--------------------------Vehicles-----------------------

Truncate table TradeIn_Vehicles
insert into TradeIn_Vehicles(
[Pk_vehicle_id]
,[listing_id]
,[brand]
,[model]
,[registration_no]
,[colour]
,[response_time]
,[status]
,[created_at]
,[updated_at]
,[created_by]
,[updated_by]
,[ownership_transferred_to]
,[ownership_transfer_date]
,[ownership_transfer_status]
,[applicable_vendors]
,[bid_won_on]
,[turn_around_days]
,[customer_expected_price]
,[approved_amount]
,[realization_percentage]
,[lowest_bid_selection_comments]
,[bid_opened_at]
,[dealer_id]
,[dealer_code]
,[branch_code]
,[bu]
,[Refresh_Date])
select v.id
      ,v.[listing_id]
      ,v.[brand]
      ,v.[model]
      ,v.[registration_no]
      ,v.[colour]
      ,v.[response_time]
      ,v.[status]
      ,v.[created_at]
      ,v.[updated_at]
	  ,v.[created_by]
	  ,v.[updated_by]
      ,v.[ownership_transferred_to]
      ,v.[ownership_transfer_date]
      ,v.[ownership_transfer_status]
      ,v.[applicable_vendors]
      ,v.[bid_won_on]
      ,v.[turn_around_days]
      ,TRY_CONVERT(float,v.[customer_expected_price])
      ,TRY_CONVERT(float,v.[approved_amount])
      ,v.[realization_percentage]
      ,v.[lowest_bid_selection_comments]
      ,v.[bid_opened_at]
      ,v.[dealer_id]
	  ,case when u.dealer_code like '[0-9][0-9][0-9][0-9][0-9]' then concat('00000',u.dealer_code) else u.dealer_code end as dealer_code 
	  ,case when u.branch_code like '[0-9][0-9][0-9][0-9][0-9]' then concat('00000',u.branch_code) else u.branch_code end as branch_code
        ,v.bu
	  ,getdate()
	  from [dbo].[TRADEAPP_VEHICLES] v
	  --left join [dbo].[TRADEAPP_DEALERS] d on d.id=v.dealer_id
	  left join [dbo].[TRADEAPP_USERS] u on v.created_by=u.id
	  where year(cast(isnull(v.ownership_transfer_date,'') as date)) !='1970'

----------------------------Users--------------------------------------
Truncate table TradeIn_Users_Dim
insert into TradeIn_Users_Dim(
[Pk_user_id]
,[name]
,[email]
,[phone_no]
,[created_at]
,[updated_at]
,[role]
,[status]
,[dealer_code]
,[dealer_name]
,[region]
,[branch_code]
,[vendor_type]
,[Refresh_Date])
select [id]
      ,[name]
      ,[email]
      ,[phone_no]
      ,[created_at]
      ,[updated_at]
      ,[role]
      ,[status]
      ,[dealer_code]
      ,[dealer_name]
      ,[region]
	  ,branch_code
	  ,case when [vendor_type]='' then 'NA'
	  when [vendor_type] is null then 'NA'
	  else vendor_type end as vendor_type
	  ,getdate()
       from [dbo].[TRADEAPP_USERS]


-----------------------------Dealer_Vendor---------------------------
Truncate table TradeIn_Dealer_Vendor
Insert into TradeIn_Dealer_Vendor(
[Vehicle_id]
,Fk_DealerCode
,Fk_Branch_code
,Vendor_id
,Created_at
,Bu)
select v.pk_vehicle_id
	  ,v.dealer_code
	  ,v.branch_code
	  ,vav.vendor_id
	  ,v.created_at
          ,v.bu
	  from TradeIn_Vehicles v
	  left join [dbo].[TRADEAPP_VEHICLE_APPLICABLE_VENDORS] vav on v.Pk_vehicle_id=vav.vehicle_id

--Update:
	  Update
	  A
	  Set A.Pk_Key=Cast(B.Vehicle_id as varchar(100))+'-'+Cast(B.Vendor_id As varchar(100))
	  From TradeIn_Dealer_Vendor A Join TradeIn_Dealer_Vendor B on A.Vehicle_id=B.Vehicle_id and A.Vendor_id=B.Vendor_id

--select * from TradeIn_Dealer_Vendor order by Vehicle_id
--Truncate table TradeIn_Dealer_Vendor

-----------------------------Vehicle_Bids----------------------------
--Upsert Logic(Update)


DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'TradeIn_ExchangeAppLoad_SP';

----------------------------------------------------------------
    -- Audit Segment 1: TradeIn_Vehicle_Bids_Fact
----------------------------------------------------------------  

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			@table_name1 VARCHAR(128) = 'TradeIn_Vehicle_Bids_Fact', 
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT,   
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX);  
BEGIN TRY



Update B Set 
 B.[Pk_bid_id]=A.[id]
,B.[Fk_vehicle_id]=A.vehicle_id
,B.[Fk_user_id]=A.[user_id]
,B.[amount]=A.[amount]
,B.[status]=A.[status]
,B.[created_at]=A.[created_at]
,B.[updated_at]=A.[updated_at]
,B.[submission_count]=A.[submission_count]
,B.Fk_Key=Cast(A.vehicle_id as varchar(100))+'-'+Cast(A.user_id As varchar(100))
,B.bu=TV.bu
,B.Refresh_Date=getdate()
From [dbo].[TRADEAPP_VEHICLE_BIDS] A JOIN TradeIn_Vehicle_Bids_Fact B ON A.id=B.[Pk_bid_id]
left join [dbo].[TRADEAPP_VEHICLES] TV on TV.id=B.Fk_vehicle_id
--Insert
INSERT INTO TradeIn_Vehicle_Bids_Fact
 (B.[Pk_bid_id]
,B.[Fk_vehicle_id]
,B.[Fk_user_id]
,B.[amount]
,B.[status]
,B.[created_at]
,B.[updated_at]
,B.[submission_count]
,B.Fk_Key
,B.highest_flag
,B.bu
,B.Refresh_Date
)
select base.id
,base.vehicle_id
,base.user_id
,base.amount
,base.status
,base.created_at
,base.updated_at
,base.submission_count
,base.fk_key
,case when highest_amount.amount=base.amount then 1 else 0 end as highest_flag
,base.bu
,getdate() as Refresh_Date
from
(Select
 A.id
,A.vehicle_id
,A.user_id
,A.amount
,A.status
,A.created_at
,A.updated_at
,A.submission_count
,Cast(A.vehicle_id as varchar(100))+'-'+Cast(A.user_id As varchar(100)) fk_key
,v.bu
,getdate() as Refresh_Date
From [dbo].[TRADEAPP_VEHICLE_BIDS] A
left join TRADEAPP_VEHICLES v on A.vehicle_id=v.id  WHERE NOT EXISTS (Select 1 from TradeIn_Vehicle_Bids_Fact B Where A.id=B.Pk_bid_id)) base

left join

(Select vehicle_id
,amount
,ROW_NUMBER() over(partition by vehicle_id order by amount desc) rno
from TRADEAPP_VEHICLE_BIDS) highest_amount on base.vehicle_id=highest_amount.vehicle_id and rno=1

--Update Highest_flag column value

update TradeIn_Vehicle_Bids_Fact set highest_flag = a.highest_flag from 
(select block1.vehicle_id,block1.amount,case when highest_amount.amount=block1.amount then 1 else 0 end  highest_flag from
(select  vehicle_id,amount from TRADEAPP_VEHICLE_BIDS) block1
left join 
(Select vehicle_id
,amount
,ROW_NUMBER() over(partition by vehicle_id order by amount desc) rno
from TRADEAPP_VEHICLE_BIDS) highest_amount on block1.vehicle_id=highest_amount.vehicle_id and rno=1)a
join TradeIn_Vehicle_Bids_Fact v on v.fk_vehicle_id=a.vehicle_id and v.amount=a.amount


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

GO