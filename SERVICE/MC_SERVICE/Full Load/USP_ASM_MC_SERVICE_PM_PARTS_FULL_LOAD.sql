SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[USP_ASM_MC_SERVICE_PM_PARTS_FULL_LOAD] AS 
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	14-11-2024  |Sarvesh K & Richa M		    |	Initial SP creation                                   */
/*  20-05-2025  |Rashi P                    |       Item code addition                              */
/*	03-09-2025  |Rashi P                    |  CR- Aging logic update, Oils exclusion               */
/*	30-09-2025  |Rashi P                    |  updated aging logic and removed hardcoding for oils               */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
Begin
print('Truncating table ASM_MC_SERVICE_PM_PARTS_STG')
TRUNCATE TABLE ASM_MC_SERVICE_PM_PARTS_STG
 
-------------------------------MC Service STG TEMP-----------------------------------------
print('Inserting data in #MC_SERVICE_STG temp table')
 
;with CTE AS(
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
WHERE ft.CANCELLATIONDATE is null)

SELECT * 
INTO #MC_SERVICE_STG
FROM CTE
WHERE RNK = 1
---------------------------Oils------------------------------------
print('Inserting Oil codes in #OILS temp table')

SELECT CAST(CODE AS INT) AS ITEMID
INTO #OILS 
FROM DM_CodeInclusionExclusion_Master 
WHERE typeflag IN ('itemid_002','itemid_003')

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
----------DeDup----------------
print('Stg Dedup')
;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY FK_DOCID ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_MC_SERVICE_PM_PARTS_STG              
)          
DELETE FROM CTE                  
WHERE RNK<>1;
 
------Updates--------------------------
 
UPDATE PM 
set pm.is_pm_part= CASE WHEN stg.lineid is NOT null THEN 1 ELSE 0 END
,pm.lineid=stg.lineid
--,item_qty_jc=coalesce(stg.)
from ASM_MC_SERVICE_PM_PARTS_STG pm
inner JOIN  asm_mc_service_stg stg
on pm.fk_docid=stg.fk_docid
and pm.itemid=stg.fk_itemid
 
update pm
set pm.item_qty_jc= CASE WHEN COALESCE(SL.QtyAllocated,0) = 0 Then (SL.Qty - SL.QtyCancelled)  
       Else (SL.QtyAllocated - SL.QtyReturned) END
from ASM_MC_SERVICE_PM_PARTS_STG pm
INNER JOIN Service_line sl
on sl.lineid=pm.lineid
where pm.lineid is not null
and sl.docdate>'2022-04-01'
 
----------------------Oil Replaced Flag----------
SELECT fct.DOCNAME,
MAX(CASE WHEN (fct.is_pm_part <= fct.item_qty_jc OR fct.item_qty_jc <> 0) AND O.ITEMID IS NOT NULL
THEN 1 ELSE 0 END) AS OilReplaced
INTO #OilFlag
FROM ASM_MC_SERVICE_PM_PARTS_STG fct LEFT JOIN
#OILS O ON fct.ITEMID = O.ITEMID
GROUP BY fct.DOCNAME
--------------------Update Due Count 
--due count to exclude gulf codes

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
 
------Insert INTO ASM_MC_PM_PARTS_REPORT-----------
print('Truncating table ASM_MC_PM_PARTS_REPORT')
TRUNCATE TABLE ASM_MC_PM_PARTS_REPORT
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
----------------Drop Tables------------------------
DROP TABLE #MC_SERVICE_STG
DROP TABLE #OILS
DROP TABLE #OilFlag
DROP TABLE #OILS_GULF
END
GO