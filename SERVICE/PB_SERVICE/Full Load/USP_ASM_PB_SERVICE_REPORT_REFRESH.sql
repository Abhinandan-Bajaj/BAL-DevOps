SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter PROC [dbo].[USP_ASM_PB_SERVICE_REPORT_REFRESH] AS
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-10-16 	|	Sarvesh Kulkarni		|Added paid due report flag			*/
/*	2024-06-17 	|	Sarvesh Kulkarni		| 3rd fs to 1st ps & 2nd fs to 1st ps report, last service dealercode added in the paid due report			*/
/*	2024-06-17 	|	Sarvesh Kulkarni		| First deployment for USP_ASM_MC_SERVICE_REPORT_REFRESH (Paid Due Report)			*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
BEGIN
Print('Declaringe variables for Paid Due Report Calculations')
DECLARE @FiscalYearStartDate DATE;

-- Determine the fiscal year boundaries based on the check date
IF MONTH(GETDATE()) >= 4
BEGIN
    SET @FiscalYearStartDate = DATEFROMPARTS(YEAR(GETDATE()), 4, 1);
END
ELSE
BEGIN
    SET @FiscalYearStartDate = DATEFROMPARTS(YEAR(GETDATE()) - 1, 4, 1);
END

Print('Truncating PB_PAID_DUE_REPORT table')

TRUNCATE table PB_PAID_DUE_REPORT

Print('Inserting data in PB_PAID_DUE_REPORT table')

INSERT INTO PB_PAID_DUE_REPORT
([FK_Ibid],[FK_Companyid],[FK_Contactid],[FK_Branchid],[FK_Modelid],[Dealercode],[Docdate],[LastServiceDate],[LastServiceName],[LastKmReading],[TSServicingStatus]
,[SSServicingStatus_TRM],[Last_Service_Branch],[LAST_PAID_SERVICE_DATE],[Last_Paid_Service_km_reading],[Last_Paid_Service_Branch_Name],[isPadidDue],[ls_dealercode],[Last_Service_Branch_code]
,[PaidReportFlag],[PaidReportFlag_TRM],[PaidReportFlagHE],[AGING],[uniqe_vin_recovery])
SELECT  *
,case when TSServicingStatus = 'serviced' and lastservicename = 'third free service' and DATEDIFF(d,lastservicedate,GETDATE())>120 then 1
when TSServicingStatus = 'expired' and lastservicename = 'second free service' then 1
when TSServicingStatus = 'expired' AND LAST_PAID_SERVICE_DATE IS NULL Then 1
when TSServicingStatus = 'serviced' and lastservicename <> 'third free service' AND LAST_PAID_SERVICE_DATE IS NULL Then 1
when DATEDIFF(d,LAST_PAID_SERVICE_DATE,GETDATE())>120 THEN 1
else 0 end as PaidReportFlag

,case when SSServicingStatus_TRM = 'serviced' and lastservicename = 'third free service' and DATEDIFF(d,lastservicedate,GETDATE())>305 then 1
when SSServicingStatus_TRM = 'expired' and lastservicename = 'first free service' then 1
when SSServicingStatus_TRM = 'expired' AND LAST_PAID_SERVICE_DATE IS NULL Then 1
when SSServicingStatus_TRM = 'serviced' and lastservicename <> 'second free service' AND LAST_PAID_SERVICE_DATE IS NULL Then 1
when DATEDIFF(d,LAST_PAID_SERVICE_DATE,GETDATE())>305 THEN 1
else 0 end as PaidReportFlag_TRM

,case 
    when lastservicedate IS NULL Then 1
    when DATEDIFF(d,LAST_PAID_SERVICE_DATE,GETDATE())>305 THEN 1 -- 10 months approximate 305 days
    else 0 end as PaidReportFlagHE,

-- current fiscal year visit yes and retail date should be last 5 years skipping immediate year
-- 0 - no
-- 1 yes
--
Coalesce(DATEDIFF(M,LAST_PAID_SERVICE_DATE,GETDATE()),DATEDIFF(M,docdate,GETDATE())) AS AGING,
CASE 
    WHEN isPadidDue=0 Then 'NA'
    WHEN isPadidDue=1 AND LastServiceDate>=@FiscalYearStartDate THEN 'Yes'
    WHEN isPadidDue=1 AND LastServiceDate<@FiscalYearStartDate THEN 'No'
END as uniqe_vin_recovery
FROM 
(SELECT DISTINCT main.FK_Ibid,
main.FK_Companyid,
main.FK_Contactid,
main.FK_Branchid,
main.FK_Modelid,
main.Dealercode,
main.Docdate,
main.LastServiceDate,
main.LastServiceName,
main.LastKmReading,
main.TSServicingStatus,
main.SSServicingStatus_TRM,
BD.BranchName as Last_Service_Branch,
Paid_Service.LAST_PAID_SERVICE_DATE,
Paid_Service.Last_Paid_Service_km_reading,
Paid_Service.Last_Paid_Service_Branch_Name,
CASE
    WHEN  month(getdate())>3 AND DATEFROMPARTS(year(getdate())-6,4,1)  <= main.docdate and main.docdate <= EOMONTH(DATEADD(month, -13, Cast(Getdate() as date)))  THEN 1 
    WHEN  month(getdate())<=3 AND DATEFROMPARTS(year(getdate())-7,4,1) <= main.docdate and main.docdate <= EOMONTH(DATEADD(month, -13, Cast(Getdate() as date)))  THEN 1
    ELSE 0
END as isPadidDue,
Coalesce(Ls_dealercode,Dealercode) as Ls_dealercode,
BD.BranchCode as Last_Service_Branch_code
FROM ASM_PB_RETAIL_FLAGS main 
LEFT JOIN ASM_SERVICE_BRANCH_MASTER_DIM BD ON main.LS_BRANCHID = BD.BRANCHID 

left join

(SELECT BASE.FK_IBID,
BASE.LAST_PAID_SERVICE_DATE,
BASE.Last_Paid_Service_km_reading,
BD1.BranchName as Last_Paid_Service_Branch_Name  
FROM 
(SELECT DISTINCT 
FK_Ibid,
Billeddatetime AS Last_Paid_Service_Date
,USAGEREADING AS Last_Paid_Service_km_reading
,FK_BRANCHID AS PAID_BRANCHID
,ROW_NUMBER() OVER(PARTITION by FK_Ibid order by Billeddatetime desc) rnk
FROM ASM_PB_SERVICE_STG 
WHERE PAIDFLAG = 1 
)BASE
LEFT JOIN ASM_SERVICE_BRANCH_MASTER_DIM BD1 ON BASE.PAID_BRANCHID = BD1.BRANCHID
WHERE BASE.RNK=1) Paid_Service 
ON Paid_Service.FK_Ibid=main.FK_Ibid
WHERE VEHICLEAGING >12)BASE


Print('Data inserted in PB_PAID_DUE_REPORT')
---------------------------------------------------------------------------------------
TRUNCATE TABLE ASM_PB_FS_PS_CONV
 --------------------------------------3rd fs to 1st ps report -----------
;;with
FREE_BLOCK as (

    SELECT *
    FROM (
            SELECT DISTINCT FK_IBID,
                SS.DOCDATE AS FREE_DATE,
                DATEADD(DD,210,Docdate) AS FilterDate,
                SS.USAGEREADING AS USAGEREADING_FS3,
                Dealercode as FS_Dealercode,
                FK_Branchid,
                FK_Contactid,
                FK_Modelid,
                ROW_NUMBER() OVER(
                    PARTITION BY FK_IBID
                    ORDER BY SS.DOCDATE
                ) FREE_RNO
            FROM ASM_PB_SERVICE_STG SS
            WHERE SS.FK_Contracttypeid IN (40)
            and ss.CANCELLATIONDATE is null
        ) FREE_BLOCK1
    WHERE 1 = 1
),

PAID_BLOCK as (
    SELECT DISTINCT FK_IBID,
        BU,
        SS.DOCDATE AS PAID_DATE,
        SS.USAGEREADING AS USAGEREADING_PAID1,
		docname,
        SS.DealerCode AS PS_Dealercode,
	    [3rdFS_To_1stPS],
	    [1st_Ps_Date],
        SS.USAGEREADING AS USAGEREADING_PAID
    FROM ASM_PB_SERVICE_STG SS
    WHERE SS.PAIDFLAG = 1
),

RET_BASE as(
    SELECT FK_Ibid, Dealercode AS Ret_Dealercode
    FROM ASM_PB_SERVICE_FACT 
    WHERE SERVICE_RETAIL_TYPEIDENTIFIER=102)
 
INSERT INTO [ASM_PB_FS_PS_CONV]
select
FK_Ibid,Ret_Dealercode,FS_DealerCode,FK_Branchid,Fk_Contactid,Fk_Modelid,FilterDate
,[FS_To_1stPS]
,CASE WHEN [FS_To_1stPS]=1 THEN 'Yes' WHEN [FS_To_1stPS]=0 THEN 'No' END AS [FS_To_1stPS_Conversion]
,FREE_DATE AS [FS_Date]
,USAGEREADING_FS3 as KmReading_FS
,[1st_Ps_Date]
,USAGEREADING_PAID AS KmReading_1stPS
,PS_Dealercode
,'3rd_fs_1st_ps' as flag
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
            coalesce([3rdFS_To_1stPS],0) as [FS_To_1stPS],
            [1st_Ps_Date],
            USAGEREADING_PAID,
            PS_Dealercode,
            Ret_Dealercode,
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
  --------------------------------------2nd fs to 1st ps report -----------
;;with
FREE_BLOCK as (
    SELECT *
    FROM (
            SELECT DISTINCT FK_IBID,
                SS.DOCDATE AS FREE_DATE,
                DATEADD(DD,395,Docdate) AS FilterDate,
                SS.USAGEREADING AS USAGEREADING_FS2,
                Dealercode as FS_Dealercode,
                FK_Branchid,
                FK_Contactid,
                FK_Modelid,
 
                ROW_NUMBER() OVER(
                    PARTITION BY FK_IBID
                    ORDER BY SS.DOCDATE
                ) FREE_RNO
            FROM ASM_PB_SERVICE_STG SS
            WHERE SS.FK_Contracttypeid IN (39)
            and ss.CANCELLATIONDATE is null
        ) FREE_BLOCK1
    WHERE 1 = 1
),
PAID_BLOCK as (
    SELECT DISTINCT FK_IBID,
        BU,
        SS.DOCDATE AS PAID_DATE,
        SS.USAGEREADING AS USAGEREADING_PAID1,
		docname,
        SS.DealerCode AS PS_Dealercode,
	    [2ndFS_To_1stPS],
	    [1st_Ps_Date],
        SS.USAGEREADING AS USAGEREADING_PAID
    FROM ASM_PB_SERVICE_STG SS
    WHERE SS.PAIDFLAG = 1
    and ss.CANCELLATIONDATE is null
),
RET_BASE as(
    SELECT FK_Ibid, Dealercode AS Ret_Dealercode
    FROM ASM_PB_SERVICE_FACT 
    WHERE SERVICE_RETAIL_TYPEIDENTIFIER=102)
	
INSERT INTO [ASM_PB_FS_PS_CONV]
select
FK_Ibid,Ret_Dealercode,FS_DealerCode,FK_Branchid,Fk_Contactid,Fk_Modelid,FilterDate
,[FS_To_1stPS]
,CASE WHEN [FS_To_1stPS]=1 THEN 'Yes' WHEN [FS_To_1stPS]=0 THEN 'No' END AS [FS_To_1stPS_Conversion]
,FREE_DATE AS [FS_Date]
,USAGEREADING_FS2 as KmReading_FS
,[1st_Ps_Date]
,USAGEREADING_PAID AS KmReading_1stPS
,PS_Dealercode
,'2nd_fs_1st_ps' as flag

from(
        select DISTINCT 
            FREE_BLOCK.FK_IBID,
            FREE_DATE,
            FilterDate,
            USAGEREADING_FS2,
            FS_Dealercode,
            FK_Branchid,
            FK_Contactid,
            FK_Modelid,
            coalesce([2ndFS_To_1stPS],0) as [FS_To_1stPS],
            [1st_Ps_Date],
            USAGEREADING_PAID,
            PS_Dealercode,
            Ret_Dealercode,
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
Print('Data inserted in ASM_PB_FS_PS_CONV')
----------------------------------------------------------------------------------------
/*
Below reports are shifted to Fact table.
Print('Truncating ASM_PB_SERVICE_REVENUE_REPORT table')

TRUNCATE table ASM_PB_SERVICE_REVENUE_REPORT;

Print('Inserting data in ASM_PB_SERVICE_REVENUE_REPORT table')
Print('Inserting data in ASM_PB_SERVICE_REVENUE_REPORT table')

INSERT INTO ASM_PB_SERVICE_REVENUE_REPORT
select 
DealerCode,
F.FK_Modelid,
F.FK_Ibid,
F.FK_Branchid,
F.FK_Contactid,
f.fk_itemid,
[FK_Contracttypeid] ,
[FK_PartContracttypeid],
F.InvoiceDate AS DOS,
F.DOCNAME AS JCNumber,
F.Billeddatetime AS JCClosuredate,
F.Service_Advisor,
F.Technician,
F.ServiceType AS HeaderRepairType,
F.Type AS RepairType,
F.Itemgrouptype AS ItemGroupType,
F.Usagereading AS KMReading,
F.Posttaxrevenue AS TotalAmount
from ASM_PB_SERVICE_FACT F 
where Service_Retail_TypeIdentifier=101;

Print('Data inserted in ASM_PB_SERVICE_REVENUE_REPORT')
----------------------------------------------------------------------------------------
Print('Truncating ASM_PB_SERVICE_TAT_REPORT table')

TRUNCATE table ASM_PB_SERVICE_TAT_REPORT;

Print('Inserting data in ASM_PB_SERVICE_TAT_REPORT table')
Print('Inserting data in ASM_PB_SERVICE_TAT_REPORT table')

INSERT INTO ASM_PB_SERVICE_TAT_REPORT
select
Distinct
DealerCode,
FK_Modelid,
FK_Ibid,
FK_Branchid,
FK_Contactid,
F.InvoiceDate AS DOS,
F.DOCNAME AS JCNumber,
F.Docdate as JCOpenDate,
F.Billeddatetime AS JCClosuredate,
F.TAT_Days,
F.[7DaysTat_Delivery] as TAT_bucket,
F.Service_Advisor,
F.Technician,
F.ServiceType AS HeaderRepairType,
F.Usagereading AS KMReading
from ASM_PB_SERVICE_FACT F
where Service_Retail_TypeIdentifier=101

Print('Data inserted in ASM_PB_SERVICE_TAT_REPORT')
-------------------------------------------------------------------------------------------
*/
END
GO