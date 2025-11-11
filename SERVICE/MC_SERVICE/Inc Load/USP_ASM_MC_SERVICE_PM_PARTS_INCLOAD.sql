SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_MC_SERVICE_PM_PARTS_INCLOAD] AS 
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	14-11-2024  |Sarvesh K & Richa M		|	Initial SP creation								    */
/*	09-01-2025  |Sarvesh K 			        |	Fixed Incremental load issue	                    */
/*  20-05-2025  |Rashi P                    | Item code addition                                    */
/*	03-09-2025  |Rashi P                    |  CR- Aging logic update, Oils exclusion               */
/*	30-09-2025  |Rashi P                    |  updated aging logic, removed hardcoding for oils and added audit logs  */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

Begin

DECLARE @MAXDATESTG DATETIME2(7)= (SELECT MAX(IMPORTEDDATE) FROM ASM_MC_SERVICE_PM_PARTS_STG)
DECLARE @MAXDATESTG2 DATETIME2(7)= (SELECT MAX(IMPORTEDDATE) FROM ASM_MC_PM_PARTS_REPORT)

DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_MC_SERVICE_PM_PARTS_INCLOAD';

----------------------------------------------------------------
    -- Audit Segment 1: ASM_MC_SERVICE_PM_PARTS_STG
----------------------------------------------------------------  

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			@table_name1 VARCHAR(128) = 'ASM_MC_SERVICE_PM_PARTS_STG', 
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT,   
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX), 

			@StartDate_utc3 DATETIME,
            @EndDate_utc3 DATETIME,
			@StartDate_ist3 DATETIME,
            @EndDate_ist3 DATETIME,
            @Duration_sec3 bigint,
			@Duration3 varchar(15),
			@table_name3 VARCHAR(128) = 'update for is_pm_part ASM_MC_SERVICE_PM_PARTS_STG',
			
			@StartDate_utc4 DATETIME ,
            @EndDate_utc4 DATETIME,
			@StartDate_ist4 DATETIME ,
            @EndDate_ist4 DATETIME,
            @Duration_sec4 bigint,
			@Duration4 varchar(15),
			@table_name4 VARCHAR(128) = 'update for item_qty_jc ASM_MC_SERVICE_PM_PARTS_STG',

			@StartDate_utc5 DATETIME ,
            @EndDate_utc5 DATETIME,
			@StartDate_ist5 DATETIME ,
            @EndDate_ist5 DATETIME,
            @Duration_sec5 bigint,
			@Duration5 varchar(15),
			@table_name5 VARCHAR(128) = 'update for due count ASM_MC_SERVICE_PM_PARTS_STG';
           

----------------------------------------------------------------
    -- Audit Segment 2: ASM_MC_PM_PARTS_REPORT
----------------------------------------------------------------  

DECLARE @StartDate_utc2 DATETIME ,
            @EndDate_utc2 DATETIME,
			@StartDate_ist2 DATETIME,
            @EndDate_ist2 DATETIME,
            @Duration_sec2 bigint,
			@Duration2 varchar(15),
			@table_name2 VARCHAR(128) = 'ASM_MC_PM_PARTS_REPORT', 
            @SourceCount2 BIGINT,  
            @TargetCount2 BIGINT,   
            @Status2 VARCHAR(10),
            @ErrorMessage2 VARCHAR(MAX); 

print('Inserting data in #MC_SERVICE_STG temp table')

---CTE for veh invoicedate from retail table 
 
;WITH CTE AS(
select 
	ft.FK_Contracttypeid
	,ft.FK_Docid
	,ft.DOCNAME
	,ft.Docdate
	,ft.FK_Companyid
	,ft.Isclosed
	,ft.FK_Ibid
	,ft.FK_Branchid
	,ft.FK_Modelid
	,ft.Billeddatetime
	,ft.Usagereading
	,ft.DealerCode
	,ft.ASD_DealerCode
	,ft.importeddate
	,ft.fk_contactid
	,ft.CANCELLATIONDATE
	,DATEDIFF(MONTH, CAST(IB.INVOICEDATE AS DATE) , ft.docdate) AS AGING
	,ROW_NUMBER()OVER(PARTITION BY ft.DOCNAME,ft.FK_DOCID ORDER BY ft.IMPORTEDDATE DESC)RNK  
from ASM_MC_SERVICE_STG ft
LEFT JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IB ON IB.PK_IBID = ft.FK_IBID
--left JOIN IBBASE ON IBBASE.IBID = ft.FK_IBID
WHERE ft.IMPORTEDDATE > @MAXDATESTG
AND ft.CANCELLATIONDATE is null
)
SELECT * 
INTO #MC_SERVICE_STG
FROM CTE
WHERE RNK = 1
---------------------------Oils------------------------------------
print('Inserting HP na d Gulf Oil codes in #OILS temp table')

SELECT CAST(CODE AS INT) AS ITEMID
INTO #OILS 
FROM DM_CodeInclusionExclusion_Master 
WHERE typeflag IN ('itemid_002','itemid_003')

----------------------------------Audit Log Source

    BEGIN TRY
        SELECT @SourceCount1 = NULL

print('Inserting data in ASM_MC_SERVICE_PM_PARTS_STG table')

INSERT INTO ASM_MC_SERVICE_PM_PARTS_STG
select 
distinct
stg.FK_Contracttypeid
,stg.FK_Docid
,stg.DOCNAME
,stg.Docdate
,stg.FK_Companyid
,stg.Isclosed
,stg.FK_Ibid
,stg.FK_Branchid
,stg.FK_Modelid
,stg.Billeddatetime
,stg.Usagereading
,stg.DealerCode
,stg.ASD_DealerCode
,pm.ItemID
,pm.PartQty
,stg.importeddate
,null as is_pm_part
,null as lineid
,null as item_qty_jc
,stg.fk_contactid
,IG.Itemgrouptype
,GETDATE() AS Refresh_Date
,SCM.NAME as servicetype
,IM.Code As ITEMCODE
,null as DUE
from CDMS_MENU_SERVICING_PART pm 
inner JOIN  #MC_SERVICE_STG stg
on pm.modelid=stg.FK_Modelid
and pm.ServiceType=stg.FK_Contracttypeid
--and ((stg.Usagereading between pm.FromKM and pm.ToKM) OR (stg.aging between pm.frommonth and pm.tomonth))
--adding prefrence to usage, if not available check on aging
AND (
     CASE 
         WHEN stg.Usagereading BETWEEN pm.FromKM AND pm.ToKM THEN 1
         WHEN NOT EXISTS (
             SELECT 1 
             FROM CDMS_MENU_SERVICING_PART pm2
             WHERE pm2.modelid = stg.FK_Modelid
               AND pm2.ServiceType = stg.FK_Contracttypeid
               AND stg.Usagereading BETWEEN pm2.FromKM AND pm2.ToKM
          ) 
          AND stg.aging BETWEEN pm.frommonth AND pm.tomonth THEN 1
          ELSE 0
      END = 1)
left join ITEM_MASTER IM ON pm.ItemID = IM.ItemID
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=pm.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
INNER JOIN SERVICE_CONTRACT_MASTER SCM ON SCM.SERVICECONTRACTID = stg.FK_Contracttypeid
where stg.CANCELLATIONDATE is null
and stg.importeddate > @MAXDATESTG


-------------------Storing unique headerids in Temp. Object--------------

PRINT('LOADING JC HEADERID FROM STG TABLE IN TEMP OBJ')

SELECT DISTINCT FK_DOCID
INTO #JC_HEADER_MC
FROM ASM_MC_SERVICE_PM_PARTS_STG

----Load missing JC data-----

INSERT INTO ASM_MC_SERVICE_PM_PARTS_STG
select 
distinct
stg.FK_Contracttypeid
,stg.FK_Docid
,stg.DOCNAME
,stg.Docdate
,stg.FK_Companyid
,stg.Isclosed
,stg.FK_Ibid
,stg.FK_Branchid
,stg.FK_Modelid
,stg.Billeddatetime
,stg.Usagereading
,stg.DealerCode
,stg.ASD_DealerCode
,pm.ItemID
,pm.PartQty
,stg.importeddate
,null as is_pm_part
,null as lineid
,null as item_qty_jc
,stg.fk_contactid
,IG.Itemgrouptype
,GETDATE() AS Refresh_Date
,SCM.NAME as servicetype
,IM.Code As ITEMCODE
,null as DUE
from CDMS_MENU_SERVICING_PART pm 
inner JOIN  #MC_SERVICE_STG stg
on pm.modelid=stg.FK_Modelid
and pm.ServiceType=stg.FK_Contracttypeid
--and ((stg.Usagereading between pm.FromKM and pm.ToKM) OR (stg.aging between pm.frommonth and pm.tomonth))
--adding prefrence to usage, if not available check on aging
AND (
     CASE 
         WHEN stg.Usagereading BETWEEN pm.FromKM AND pm.ToKM THEN 1
         WHEN NOT EXISTS (
             SELECT 1 
             FROM CDMS_MENU_SERVICING_PART pm2
             WHERE pm2.modelid = stg.FK_Modelid
               AND pm2.ServiceType = stg.FK_Contracttypeid
               AND stg.Usagereading BETWEEN pm2.FromKM AND pm2.ToKM
          ) 
          AND stg.aging BETWEEN pm.frommonth AND pm.tomonth THEN 1
          ELSE 0
      END = 1)
left join ITEM_MASTER IM ON pm.ItemID = IM.ItemID
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=pm.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
INNER JOIN SERVICE_CONTRACT_MASTER SCM ON SCM.SERVICECONTRACTID = stg.FK_Contracttypeid
where stg.CANCELLATIONDATE is null
and --stg.importeddate > @MAXDATESTG

CAST(stg.importeddate AS DATE) >= CAST(DATEADD(D,-30,GETDATE()) AS DATE) 
AND stg.FK_Docid NOT IN (SELECT DISTINCT FK_DOCID FROM #JC_HEADER_MC)


------Updates-----

PRINT('Updates for is_pm_part and item_qty_jc')

    SET @StartDate_utc3 = GETDATE();
	SET @StartDate_ist3 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));

UPDATE PM 
set pm.is_pm_part= CASE WHEN stg.lineid is NOT null THEN 1 ELSE 0 END
,pm.lineid=stg.lineid
--,item_qty_jc=coalesce(stg.)
from ASM_MC_SERVICE_PM_PARTS_STG pm
inner JOIN  asm_mc_service_stg stg
on pm.fk_docid=stg.fk_docid
and pm.itemid=stg.fk_itemid

    SET @EndDate_utc3 = GETDATE();
	SET @EndDate_ist3 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));
    SET @Duration_sec3 = DATEDIFF(SECOND, @StartDate_ist3, @EndDate_ist3);
	SET @Duration3 = CONVERT(VARCHAR(8), DATEADD(SECOND, @Duration_sec3, 0), 108);
    EXEC [USP_Audit_Balance_Control_Logs] 
	     @SPID,
        @sp_name,
		@table_name3,
        'Service',
        'MC',
        @StartDate_utc3,
        @EndDate_utc3,
		@StartDate_ist3,
        @EndDate_ist3,
        @Duration3,  
        NULL,
        NULL,
        'NA',
        'NA';

--------------------------------------------------------------------------------------------------------------------

    SET @StartDate_utc4 = GETDATE();
	SET @StartDate_ist4 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));

update pm
set pm.item_qty_jc= CASE WHEN COALESCE(SL.QtyAllocated,0) = 0 Then (SL.Qty - SL.QtyCancelled)  
       Else (SL.QtyAllocated - SL.QtyReturned) END
from ASM_MC_SERVICE_PM_PARTS_STG pm
INNER JOIN Service_line sl
on sl.lineid=pm.lineid
where pm.lineid is not null
and sl.docdate>'2022-04-01'

SET @EndDate_utc4 = GETDATE();
	SET @EndDate_ist4 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));
    SET @Duration_sec4 = DATEDIFF(SECOND, @StartDate_ist4, @EndDate_ist4);
	SET @Duration4 = CONVERT(VARCHAR(8), DATEADD(SECOND, @Duration_sec3, 0), 108);
    EXEC [USP_Audit_Balance_Control_Logs] 
	     @SPID,
        @sp_name,
		@table_name4,
        'Service',
        'MC',
        @StartDate_utc4,
        @EndDate_utc4,
		@StartDate_ist4,
        @EndDate_ist4,
        @Duration4,  
        NULL,
        NULL,
        'NA',
        'NA';

----------------------Oil Replaced Flag---------

SET @StartDate_utc5 = GETDATE();
SET @StartDate_ist5 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));

PRINT('Update for oil replaced flag')

SELECT fct.DOCNAME,
MAX(CASE WHEN (fct.is_pm_part <= fct.item_qty_jc OR fct.item_qty_jc <> 0) AND O.ITEMID IS NOT NULL
THEN 1 ELSE 0 END) AS OilReplaced
INTO #OilFlag
FROM ASM_MC_SERVICE_PM_PARTS_STG fct LEFT JOIN
#OILS O ON fct.ITEMID = O.ITEMID
GROUP BY fct.DOCNAME

--------------------Update Due Count

--due count to exclude gulf codes

PRINT('Insert oil codes in #OILS_GULF and update for Due count')

SELECT CAST(CODE AS INT) AS ITEMID 
INTO #OILS_GULF
FROM DM_CodeInclusionExclusion_Master 
WHERE typeflag = 'itemid_003'


update pm
set pm.DUE = CASE WHEN O.ITEMID IS NOT NULL AND item_qty_jc IS  NULL AND OL.OilReplaced = 1 THEN 0 ---Gulf exclusion if oil is replaced
                  WHEN OL.OilReplaced = 0 AND OG.ITEMID IS NOT NULL THEN 0
                  ELSE pm.PARTQTY 
		     END 
FROM ASM_MC_SERVICE_PM_PARTS_STG PM
LEFT JOIN #OilFlag OL ON OL.DOCNAME = pm.DOCNAME 
LEFT JOIN #OILS O ON PM.ITEMID = O.ITEMID
LEFT JOIN #OILS_GULF OG ON PM.ITEMID = OG.ITEMID

SET @EndDate_utc5 = GETDATE();
	SET @EndDate_ist5 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));
    SET @Duration_sec5 = DATEDIFF(SECOND, @StartDate_ist4, @EndDate_ist4);
	SET @Duration5 = CONVERT(VARCHAR(8), DATEADD(SECOND, @Duration_sec3, 0), 108);
    EXEC [USP_Audit_Balance_Control_Logs] 
	     @SPID,
        @sp_name,
		@table_name5,
        'Service',
        'MC',
        @StartDate_utc5,
        @EndDate_utc5,
		@StartDate_ist5,
        @EndDate_ist5,
        @Duration5,  
        NULL,
        NULL,
        'NA',
        'NA';

--------DeDup PM Parts Table---------------------------

print('De-dupe for ASM_MC_SERVICE_PM_PARTS_STG')

;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY FK_DOCID ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_MC_SERVICE_PM_PARTS_STG              
)          
DELETE FROM CTE                  
WHERE RNK<>1;

----------------------------------Audit Log Target

SELECT @TargetCount1 = COUNT(DISTINCT FK_docid) FROM ASM_MC_SERVICE_PM_PARTS_STG;
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
        @sp_name,
		@table_name1,
        'Service',
        'MC',
        @StartDate_utc1,
        @EndDate_utc1,
		@StartDate_ist1,
        @EndDate_ist1,
        @Duration1,  
        @SourceCount1,
        @TargetCount1,
        @Status1,
        @ErrorMessage1;



------Insert INTO ASM_MC_PM_PARTS_REPORT-----------

SET @StartDate_utc2 = GETDATE();
SET @StartDate_ist2 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));

----------------------------------Audit Log Source

    BEGIN TRY
        SELECT @SourceCount1 = NULL

print('Inserting data in ASM_MC_PM_PARTS_REPORT table')

INSERT INTO ASM_MC_PM_PARTS_REPORT
select 
pm.FK_Contracttypeid, 
pm.FK_Docid, 
pm.DOCNAME, 
pm.Docdate, 
pm.FK_Companyid, 
pm.Isclosed, 
pm.FK_Ibid, 
pm.FK_Branchid, 
pm.FK_Modelid, 
pm.fk_contactid,
pm.Billeddatetime, 
pm.Usagereading, 
pm.DealerCode, 
pm.ASD_DealerCode
,String_AGG (Case When pm.is_pm_part <= pm.item_qty_jc  THEN im.code Else null end, ',') as PM_Parts_Replaced_code
,String_AGG (Case When pm.is_pm_part <= pm.item_qty_jc  THEN im.name Else null end, ',') as PM_Parts_Replaced_code_name
,String_AGG (Case When pm.is_pm_part <= pm.item_qty_jc OR (OL.OilReplaced = 1 AND O.ITEMID IS NOT NULL) OR pm.due = 0 THEN null Else im.code  end, ',') as PM_Parts_not_Replaced_code
,String_AGG (Case When pm.is_pm_part <= pm.item_qty_jc OR (OL.OilReplaced = 1 AND O.ITEMID IS NOT NULL) OR pm.due = 0 THEN null Else im.name  end, ',') as PM_Parts_not_Replaced_name
,pm.Itemgrouptype
,pm.IMPORTEDDATE
,GETDATE() AS Refresh_Date
,pm.servicetype
,IM.Code As ITEMCODE
,pm.partqty
,pm.due
,pm.item_qty_jc
from ASM_MC_SERVICE_PM_PARTS_STG pm
LEFT JOIN item_master im on im.itemid=pm.itemid
LEFT JOIN #OilFlag OL ON OL.DOCNAME = pm.DOCNAME
LEFT JOIN #OILS O ON O.ITEMID = PM.ITEMID
where   pm.IMPORTEDDATE > @MAXDATESTG2
group by pm.FK_Contracttypeid, pm.FK_Docid, pm.DOCNAME, pm.Docdate, pm.FK_Companyid, pm.Isclosed, pm.FK_Ibid, pm.FK_Branchid,pm.fk_contactid, pm.FK_Modelid, pm.Billeddatetime, pm.Usagereading, pm.DealerCode, pm.ASD_DealerCode,pm.IMPORTEDDATE, Refresh_Date,pm.Itemgrouptype,pm.servicetype,IM.Code,pm.partqty,pm.partqty,pm.due,pm.item_qty_jc

-------------------Storing unique headerids in Temp. Object--------------

PRINT('LOADING JC HEADERID FROM STG TABLE IN TEMP OBJ')

SELECT DISTINCT FK_DOCID
INTO #JC_HEADER_MC2
FROM ASM_MC_PM_PARTS_REPORT

----Load missing JC data-----

INSERT INTO ASM_MC_PM_PARTS_REPORT
select 
pm.FK_Contracttypeid, 
pm.FK_Docid, 
pm.DOCNAME, 
pm.Docdate, 
pm.FK_Companyid, 
pm.Isclosed, 
pm.FK_Ibid, 
pm.FK_Branchid, 
pm.FK_Modelid, 
pm.fk_contactid,
pm.Billeddatetime, 
pm.Usagereading, 
pm.DealerCode, 
pm.ASD_DealerCode
,String_AGG (Case When pm.is_pm_part <= pm.item_qty_jc  THEN im.code Else null end, ',') as PM_Parts_Replaced_code
,String_AGG (Case When pm.is_pm_part <= pm.item_qty_jc  THEN im.name Else null end, ',') as PM_Parts_Replaced_code_name
,String_AGG (Case When pm.is_pm_part <= pm.item_qty_jc OR (OL.OilReplaced = 1 AND O.ITEMID IS NOT NULL) OR pm.due = 0 THEN null Else im.code  end, ',') as PM_Parts_not_Replaced_code
,String_AGG (Case When pm.is_pm_part <= pm.item_qty_jc OR (OL.OilReplaced = 1 AND O.ITEMID IS NOT NULL) OR pm.due = 0 THEN null Else im.name  end, ',') as PM_Parts_not_Replaced_name
,pm.Itemgrouptype
,pm.IMPORTEDDATE
,GETDATE() AS Refresh_Date
,pm.servicetype
,IM.Code As ITEMCODE
,pm.partqty
,pm.due
,pm.item_qty_jc
from ASM_MC_SERVICE_PM_PARTS_STG pm
LEFT JOIN item_master im on im.itemid=pm.itemid
LEFT JOIN #OilFlag OL ON OL.DOCNAME = pm.DOCNAME
LEFT JOIN #OILS O ON O.ITEMID = PM.ITEMID
WHERE CAST(pm.IMPORTEDDATE AS DATE) >= CAST(DATEADD(D,-30,GETDATE()) AS DATE) 
AND pm.FK_Docid NOT IN (SELECT DISTINCT FK_DOCID FROM #JC_HEADER_MC2)
group by pm.FK_Contracttypeid, pm.FK_Docid, pm.DOCNAME, pm.Docdate, pm.FK_Companyid, pm.Isclosed, pm.FK_Ibid, pm.FK_Branchid,pm.fk_contactid, pm.FK_Modelid, pm.Billeddatetime, pm.Usagereading, pm.DealerCode, pm.ASD_DealerCode,pm.IMPORTEDDATE, Refresh_Date,pm.Itemgrouptype,pm.servicetype,IM.Code,pm.partqty,pm.partqty,pm.due,pm.item_qty_jc


----------------DeDup---------------------
print('report Dedup')
;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY FK_DOCID ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_MC_PM_PARTS_REPORT              
)          
DELETE FROM CTE                  
WHERE RNK<>1;

----------------------------------Audit Log Target

SELECT @TargetCount2 = COUNT(DISTINCT FK_docid) FROM ASM_MC_PM_PARTS_REPORT;
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
        'Service',
        'MC',
        @StartDate_utc2,
        @EndDate_utc2,
		@StartDate_ist2,
        @EndDate_ist2,
        @Duration2,  
        @SourceCount2,
        @TargetCount2,
        @Status2,
        @ErrorMessage2;


----------------Drop Tables------------------------
DROP TABLE #MC_SERVICE_STG
DROP TABLE #OILS
DROP TABLE #OilFlag
DROP TABLE #OILS_GULF
DROP TABLE #JC_HEADER_MC
DROP TABLE #JC_HEADER_MC2

END
GO

