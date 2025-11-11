SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Alter PROC [dbo].[USP_ASM_MC_SERVICE_REPORT_REFRESH] AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-09-20 	|	Sarvesh Kulkari		| Updated code fix 3rd fs to 1st Ps flag					*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
/*	2024-6-09 	|	Sarvesh Kulkari		| Added Code for AMC Report, RV RJ report					*/
/*	2024-05-06 	|	Aakash Kundu		| Updating DocDate filter to FY20-21                        */
/*	2025-09-18 	|	Richa Mishra		| Added changes for Repeate jobcards and addition of ABC table                   */
/*--------------------------------------------------------------------------------------------------*/
--Free Service Due Report

DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_MC_SERVICE_REPORT_REFRESH';
		
---Audit parameters --------------

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			@table_name1 VARCHAR(128) = 'ASM_MC_RETAIL_FLAGS_UNION', 
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT,   
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX);  
 
			

 BEGIN TRY			
			
					SELECT @SourceCount1 = COUNT(DISTINCT FK_DOCID)
        from ASM_MC_RETAIL_FLAGS AR
	    LEFT JOIN COMPANY_MASTER CM1 ON CM1.COMPANYID = AR.FS_COMPANYID
		LEFT JOIN COMPANY_MASTER CM2 ON CM2.COMPANYID = AR.SS_COMPANYID
		LEFT JOIN COMPANY_MASTER CM3 ON CM3.COMPANYID = AR.TS_COMPANYID
			

TRUNCATE TABLE [dbo].[ASM_MC_RETAIL_FLAGS_UNION]

INSERT [dbo].[ASM_MC_RETAIL_FLAGS_UNION]

SELECT 
* 
FROM
(SELECT 
    [FK_Docid],
    DOCNAME,
    Retail_Type,
    PaidDueDate,
    FK_Companyid,
    Lineid,
    BU,
    AR.Companytype,
    [Dealercode],
    CASE WHEN RETAIL_TYPE = 'VSI' THEN FK_Contactid
    WHEN RETAIL_TYPE = 'AVSI' THEN ASDA_CONTACT ELSE NULL END AS FK_Contactid,
    [FK_Ibid],
    CASE WHEN RETAIL_TYPE = 'VSI' THEN FK_Branchid 
    WHEN RETAIL_TYPE = 'AVSI' THEN ASDA_BRANCHID ELSE NULL END AS FK_Branchid,
	FK_Modelid,
    [1stFS_EXPIRY1_Date] as Due_date,
    [1stFS_EXPIRY2_Date] as Expiry_date,
    'First Free Service' as Service_type,
    FSServicingStatus as Service_Status,
	FS_SERVICE_DATE AS Service_Date,
	CM.NAME AS Servicing_Outlet
    from ASM_MC_RETAIL_FLAGS AR
	LEFT JOIN COMPANY_MASTER CM ON CM.COMPANYID = AR.FS_COMPANYID
	WHERE CAST(DOCDATE AS DATE) >= '2020-04-01'

    UNION ALL
	
    SELECT 
    [FK_Docid],
    DOCNAME,
    Retail_Type,
    PaidDueDate,
    FK_Companyid,
    Lineid,
    BU,
    AR.Companytype,
    [Dealercode],
    CASE WHEN RETAIL_TYPE = 'VSI' THEN FK_Contactid
    WHEN RETAIL_TYPE = 'AVSI' THEN ASDA_CONTACT ELSE NULL END AS FK_Contactid,
    [FK_Ibid],
    CASE WHEN RETAIL_TYPE = 'VSI' THEN FK_Branchid 
    WHEN RETAIL_TYPE = 'AVSI' THEN ASDA_BRANCHID ELSE NULL END AS FK_Branchid,
	FK_Modelid,
    [2ndFS_EXPIRY1_Date] as Due_date,
    [2ndFS_EXPIRY2_Date] as Expiry_date,
    'Second Free Service' as Service_type,
    SSServicingStatus as Service_Status,
	SS_SERVICE_DATE AS Service_Date,
	CM.NAME AS Servicing_Outlet
    from ASM_MC_RETAIL_FLAGS AR
	LEFT JOIN COMPANY_MASTER CM ON CM.COMPANYID = AR.SS_COMPANYID
	WHERE CAST(DOCDATE AS DATE) >= '2020-04-01'
    
    UNION ALL
	
    SELECT 
    [FK_Docid],
    DOCNAME,
    Retail_Type,
    PaidDueDate,
    FK_Companyid,
    Lineid,
    BU,
    AR.Companytype,
    [Dealercode],
    CASE WHEN RETAIL_TYPE = 'VSI' THEN FK_Contactid
    WHEN RETAIL_TYPE = 'AVSI' THEN ASDA_CONTACT ELSE NULL END AS FK_Contactid,
    [FK_Ibid],
    CASE WHEN RETAIL_TYPE = 'VSI' THEN FK_Branchid 
    WHEN RETAIL_TYPE = 'AVSI' THEN ASDA_BRANCHID ELSE NULL END AS FK_Branchid,
	FK_Modelid,
    [3rdFS_EXPIRY1_Date] as Due_date,
    [3rdFS_EXPIRY2_Date] as Expiry_date,
    'Third Free Service' as Service_type,
    TSServicingStatus as Service_Status,
	TS_SERVICE_DATE AS Service_Date,
	CM.NAME AS Servicing_Outlet
    from ASM_MC_RETAIL_FLAGS AR
	LEFT JOIN COMPANY_MASTER CM ON CM.COMPANYID = AR.TS_COMPANYID
	WHERE CAST(DOCDATE AS DATE) >= '2020-04-01'
   
) t
	

SELECT @TargetCount1 = COUNT(DISTINCT FK_DOCID) FROM ASM_MC_RETAIL_FLAGS_UNION;
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
    SET @Duration_sec1 = DATEDIFF(SECOND, @StartDate_ist1, @EndDate_ist1);
	SET @Duration1 = CONVERT(VARCHAR(8), DATEADD(SECOND, @Duration_sec1, 0), 108);
    EXEC [USP_Audit_Balance_Control_Logs] 
	     @SPID,
        @sp_name,@table_name1,'Service','MC',@StartDate_utc1,@EndDate_utc1,@StartDate_ist1, @EndDate_ist1,@Duration1,  @SourceCount1,@TargetCount1,@Status1,
        @ErrorMessage1;


-----------------------------------------------------------



--3rdFS_to_1stPS Conversion Report

TRUNCATE TABLE [ASM_MC_FS_PS_CONV]
;;with
FREE_BLOCK as (
    SELECT *
    FROM (
            SELECT DISTINCT FK_IBID,
                SS.BILLEDDATETIME AS FREE_DATE,
                DATEADD(MM,7,Billeddatetime) AS FilterDate,
                SS.USAGEREADING AS USAGEREADING_FS3,
                Dealercode as FS_Dealercode,
                FK_Branchid,
                FK_Contactid,
                FK_Modelid,

                ROW_NUMBER() OVER(
                    PARTITION BY FK_IBID
                    ORDER BY SS.BILLEDDATETIME
                ) FREE_RNO
            FROM ASM_MC_SERVICE_STG SS
            WHERE SS.FK_Contracttypeid IN (40)
            and ss.CANCELLATIONDATE is null
        ) FREE_BLOCK1
    WHERE 1 = 1
),
PAID_BLOCK as (
    SELECT DISTINCT FK_IBID,
        BU,
        SS.BILLEDDATETIME AS PAID_DATE,
        SS.USAGEREADING AS USAGEREADING_PAID1,
		docname,
        SS.DealerCode AS PS_Dealercode,
	    [3rdFS_To_1stPS],
	    [1st_Ps_Date],
        SS.USAGEREADING AS USAGEREADING_PAID
    FROM ASM_MC_SERVICE_STG SS
    WHERE SS.FK_CONTRACTTYPEID IN (2,41,42,192,193,13)
	and ss.BILLEDDATETIME is not null
),
RET_BASE as(
    SELECT FK_Ibid, PaidDueDate, Dealercode AS Ret_Dealercode
    FROM ASM_MC_SERVICE_FACT 
    WHERE SERVICE_RETAIL_TYPEIDENTIFIER=102) 

INSERT INTO [ASM_MC_FS_PS_CONV]
select
FK_Ibid,Ret_Dealercode,PaidDueDate,FS_DealerCode,FK_Branchid,Fk_Contactid,Fk_Modelid,FilterDate
,[3rdFS_To_1stPS]
,CASE WHEN [3rdFS_To_1stPS]=1 THEN 'Yes' WHEN [3rdFS_To_1stPS]=0 THEN 'No' END AS [3rdFS_To_1stPS_Conversion]
,FREE_DATE AS [3rd_FS_Date]
,USAGEREADING_FS3 as KmReading_3rdFS
,[1st_Ps_Date]
,USAGEREADING_PAID AS KmReading_1stPS
,PS_Dealercode

from(
        select DISTINCT 
            FREE_BLOCK.FK_IBID,
            FREE_DATE,
            FilterDate,
            USAGEREADING_FS3,
            FS_Dealercode,
            FK_Branchid,
            FK_Contactid,
            FK_Modelid,
            coalesce([3rdFS_To_1stPS],0) as [3rdFS_To_1stPS],
            [1st_Ps_Date],
            USAGEREADING_PAID,
            PS_Dealercode,
            Ret_Dealercode,
            PaidDueDate,
            ROW_NUMBER() OVER(
                PARTITION BY FREE_BLOCK.FK_IBID
                ORDER BY PAID_BLOCK.PAID_DATE ASC,docname asc
            ) PAID_RNO
        from FREE_BLOCK 
            LEFT JOIN PAID_BLOCK ON PAID_BLOCK.FK_IBID = FREE_BLOCK.FK_IBID
            and (
                PAID_BLOCK.PAID_DATE > FREE_BLOCK.FREE_DATE
                OR PAID_BLOCK.PAID_DATE is null
            )
            LEFT JOIN RET_BASE ON RET_BASE.FK_Ibid=FREE_BLOCK.FK_IBID
    ) t 
where PAID_RNO = 1

---------------------------------------------------AMC redemption report
			
DECLARE @StartDate_utc2 DATETIME = GETDATE(),
            @EndDate_utc2 DATETIME,
			@StartDate_ist2 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist2 DATETIME,
            @Duration_sec2 bigint,
			@Duration2 varchar(15),
			@table_name2 VARCHAR(128) = 'ASM_MC_AMC_Service_report', 
            @SourceCount2 BIGINT,  
            @TargetCount2 BIGINT,   
            @Status2 VARCHAR(10),
            @ErrorMessage2 VARCHAR(MAX); 


 BEGIN TRY			
			
					SELECT @SourceCount2 = COUNT(1)
        from ASM_MC_AMC_Service_Flags
		
		 
 

truncate table ASM_MC_AMC_Service_report; 
print('truncated table ASM_MC_AMC_Service_report')
print('inserting AMC report data in ASM_MC_AMC_Service_report')
Insert Into ASM_MC_AMC_Service_report(
	fk_branchid ,
	fk_modelid,
	[policyno],
	[policysolddate] ,
	[dealercode],
	[dealername],
	[customername],
	[mobile],
	[chassisno.],
	[cardno.],
	[startdate],
	[enddate],
	service_type,
	[exp_date],
	[done_date],
	odometer_reading,
	redemption_status
)
select 
fk_branchid,fk_modelid,policyno,policysolddate,dealercode,dealername,customername,mobile,[chassisno.],[cardno.],startdate,enddate
,'AMC1'as service_type,AMC1ExpDate as exp_date,AMC1Date as done_date,AMC1_kmreading as odometer_reading,AMC1_Red_Flag as redemption_status
from ASM_MC_AMC_Service_Flags;

Insert Into ASM_MC_AMC_Service_report(
		fk_branchid ,
	fk_modelid,
	[policyno],
	[policysolddate] ,
	[dealercode],
	[dealername],
	[customername],
	[mobile],
	[chassisno.],
	[cardno.],
	[startdate],
	[enddate],
	service_type,
	[exp_date],
	[done_date],
	odometer_reading,
	redemption_status
)
select
fk_branchid,fk_modelid,policyno,policysolddate,dealercode,dealername,customername,mobile,[chassisno.],[cardno.],startdate,enddate
,'AMC2' as service_type,AMC2ExpDate  as exp_date,AMC2Date  as done_date,AMC2_kmreading as odometer_reading,AMC2_Red_Flag as redemption_status
from ASM_MC_AMC_Service_Flags;
 
Insert Into ASM_MC_AMC_Service_report(
	fk_branchid ,
	fk_modelid,
	[policyno],
	[policysolddate] ,
	[dealercode],
	[dealername],
	[customername],
	[mobile],
	[chassisno.],
	[cardno.],
	[startdate],
	[enddate],
	service_type,
	[exp_date],
	[done_date],
	odometer_reading,
	redemption_status
)
select
fk_branchid,fk_modelid,policyno,policysolddate,dealercode,dealername,customername,mobile,[chassisno.],[cardno.],startdate,enddate
,'AMC3'as service_type,AMC3ExpDate  as exp_date,AMC3Date as done_date,AMC3_kmreading as odometer_reading,AMC3_Red_Flag as redemption_status
from ASM_MC_AMC_Service_Flags;

print('Data load to ASM_MC_AMC_Service_report is completed')


SELECT @TargetCount2 = COUNT(1) FROM ASM_MC_AMC_Service_report;
        IF @SourceCount2 <> @TargetCount1
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
    SET @Duration_sec2 = DATEDIFF(SECOND, @StartDate_ist1, @EndDate_ist1);
	SET @Duration2 = CONVERT(VARCHAR(8), DATEADD(SECOND, @Duration_sec1, 0), 108);
    EXEC [USP_Audit_Balance_Control_Logs] 
	     @SPID,
        @sp_name,@table_name2 ,'Service','MC',@StartDate_utc2 ,@EndDate_utc2 ,@StartDate_ist2 , @EndDate_ist2 ,@Duration2 ,  @SourceCount2 ,@TargetCount2 ,@Status2 ,
        @ErrorMessage2 ;

 
--------------------------------------------------------------RV RJ Report---------------------------------------------------

DECLARE @StartDate_utc3 DATETIME = GETDATE(),
            @EndDate_utc3 DATETIME,
			@StartDate_ist3 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist3 DATETIME,
            @Duration_sec3 bigint,
			@Duration3 varchar(15),
			@table_name3 VARCHAR(128) = 'ASM_MC_SERVICE_RVRJ_REPORT', 
            @SourceCount3 BIGINT,  
            @TargetCount3 BIGINT,   
            @Status3 VARCHAR(10),
            @ErrorMessage3 VARCHAR(MAX);  


BEGIN TRY			
			
		SELECT @SourceCount3 = COUNT(1)
        from ASM_MC_SERVICE_FACT SF
LEFT JOIN ITEM_MASTER IM ON IM.ITEMID=SF.FK_ITEMID
where Service_Retail_TypeIdentifier=101
and isrevisited =1
and FK_Contracttypeid not in (8, 168)


truncate table ASM_MC_SERVICE_RVRJ_REPORT
Insert INTO [ASM_MC_SERVICE_RVRJ_REPORT]
( 
	[docname],
	[fk_ibid],
	[fk_branchid],
	[FK_Contactid],
	[docdate],
	[Isrevisited],
	[Dealercode],
	[ASD_Dealercode],
	[isrepeated],
	[RepeatType],
	[Previous Doc Name],
	[Previous Doc Date],
	[Desc of Repeated lineitem],
	[repeated part Code]
)
select 
docname,fk_ibid,fk_branchid,FK_Contactid,docdate,Isrevisited,Dealercode,ASD_Dealercode
,max(isrepeated) as isrepeated
,COALESCE(MAX(CASE WHEN isrepeated = 1 THEN Repeat_Type END), 'Revisited') AS RepeatType
,max(repeated_from_docname) as 'Previous Doc Name'
,max(repeated_from_docdate) 'Previous Doc Date'
,String_AGG(Case WHEN isrepeated =1 then IM.DESCRIPTION end ,',') as 'Desc of Repeated lineitem'
,max(Case WHEN isrepeated =1 then IM.CODE end) as 'repeated part Code'
from 
ASM_MC_SERVICE_FACT SF
LEFT JOIN ITEM_MASTER IM ON IM.ITEMID=SF.FK_ITEMID
where Service_Retail_TypeIdentifier=101
and isrevisited =1
and FK_Contracttypeid not in (8, 168) --excluding pre sales types
group by docname,fk_ibid,fk_branchid,FK_Contactid,docdate,Isrevisited,Dealercode,ASD_Dealercode,Repeat_Type



 SELECT @TargetCount3 = COUNT(1) FROM ASM_MC_SERVICE_RVRJ_REPORT;
        IF @SourceCount3 <> @TargetCount3
        BEGIN
            SET @Status3 = 'WARNING';  
            SET @ErrorMessage3 = CONCAT('Record count mismatch. Source=', @SourceCount3 , ', Target=', @TargetCount3);
        END
        ELSE
        BEGIN
            SET @Status3 = 'SUCCESS';
            SET @ErrorMessage3 = NULL;
        END
    END TRY
    BEGIN CATCH
        SET @Status3 = 'FAILURE';
        SET @ErrorMessage3 = ERROR_MESSAGE();
        THROW;  
    END CATCH
    SET @EndDate_utc3 = GETDATE();
	SET @EndDate_ist3 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));
    SET @Duration_sec3 = DATEDIFF(SECOND, @StartDate_ist1, @EndDate_ist1);
	SET @Duration3 = CONVERT(VARCHAR(8), DATEADD(SECOND, @Duration_sec1, 0), 108);
    EXEC [USP_Audit_Balance_Control_Logs] 
	     @SPID,
        @sp_name,@table_name3 ,'Service','MC',@StartDate_utc3 ,@EndDate_utc3 ,@StartDate_ist3 , @EndDate_ist3 ,@Duration3 ,  @SourceCount3 ,@TargetCount3 ,@Status3 ,
        @ErrorMessage3 ;


---------------------------------------------WORKSHOP PROFITABILITY------------------------------------------
DECLARE @StartDate_utc4 DATETIME = GETDATE(),
            @EndDate_utc4 DATETIME,
			@StartDate_ist4 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist4 DATETIME,
            @Duration_sec4 bigint,
			@Duration4 varchar(15),
			@table_name4 VARCHAR(128) = 'ASM_MC_WORKSHOP_PROFITABILITY', 
            @SourceCount4 BIGINT,  
            @TargetCount4 BIGINT,   
            @Status4 VARCHAR(10),
            @ErrorMessage4 VARCHAR(MAX);  

BEGIN TRY			
			
		SELECT @SourceCount4= COUNT(1)
        from 
 CDMS_WORKSHOP_PROFITABILITY WP
left join BRANCH_MASTER BM ON WP.BranchID=BM.BRANCHID
LEFT JOIN COMPANY_MASTER CM ON BM.COMPANYID= CM.COMPANYID


TRUNCATE TABLE [dbo].ASM_MC_WORKSHOP_PROFITABILITY

INSERT into [dbo].ASM_MC_WORKSHOP_PROFITABILITY
( 
BranchID
,Month
,Year
,AreaID
,ActualRent
,NRID
,NetProfit
,WorkshopIncome
,Workshopexpenses
,TotalSalary
,TotWorkIncome
,TotSerVolume
,DelearCode
,Date
,DocDate
,Approve
,Reject
,Remark
,ImportedDate
,RefreshDate
,IsASMSubmit
)
select 
WP.BranchID
,WP.Month
,WP.Year
,WP.AreaID
,WP.ActualRent
,WP.NRID
,WP.NetProfit
,WP.WorkshopIncome
,WP.Workshopexpenses
,WP.TotalSalary
,WP.TotWorkIncome
,WP.TotSerVolume
,CM.Code as DelearCode
,CAST(CONCAT(Year, '-', Month, '-01') AS DATE) AS Date
,WP.DocDate
,WP.Approve
,WP.Reject
,WP.Remark
,WP.ImportedDate
,getdate() as RefreshDate
,WP.IsASMSubmit
 from 
 CDMS_WORKSHOP_PROFITABILITY WP
left join BRANCH_MASTER BM ON WP.BranchID=BM.BRANCHID
LEFT JOIN COMPANY_MASTER CM ON BM.COMPANYID= CM.COMPANYID



 
 SELECT @TargetCount4 = COUNT(1) FROM ASM_MC_WORKSHOP_PROFITABILITY;
        IF @SourceCount4 <> @TargetCount4
        BEGIN
            SET @Status4 = 'WARNING';  
            SET @ErrorMessage4 = CONCAT('Record count mismatch. Source=', @SourceCount4 , ', Target=', @TargetCount4 );
        END
        ELSE
        BEGIN
            SET @Status4 = 'SUCCESS';
            SET @ErrorMessage4 = NULL;
        END
    END TRY
    BEGIN CATCH
        SET @Status4 = 'FAILURE';
        SET @ErrorMessage4 = ERROR_MESSAGE();
        THROW;  
    END CATCH
    SET @EndDate_utc4 = GETDATE();
	SET @EndDate_ist4 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));
    SET @Duration_sec4 = DATEDIFF(SECOND, @StartDate_ist1, @EndDate_ist1);
	SET @Duration4 = CONVERT(VARCHAR(8), DATEADD(SECOND, @Duration_sec1, 0), 108);
    EXEC [USP_Audit_Balance_Control_Logs] 
	     @SPID,
        @sp_name,@table_name4 ,'Service','MC',@StartDate_utc4 ,@EndDate_utc4 ,@StartDate_ist4 , @EndDate_ist4 ,@Duration4 ,  @SourceCount4 ,@TargetCount4 ,@Status4 ,
        @ErrorMessage4 ;



END
GO