SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_PB_SERVICE_PM_PARTS_INCLOAD] AS 
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	14-11-2024  |Richa M		|	Initial SP creation									*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

Begin


DECLARE @MAXDATESTG DATETIME2(7)= (SELECT MAX(IMPORTEDDATE) FROM ASM_PB_SERVICE_PM_PARTS_STG)
DECLARE @MAXDATESTG2 DATETIME2(7)= (SELECT MAX(IMPORTEDDATE) FROM ASM_PB_PM_PARTS_REPORT)



print('Inserting data in ASM_PB_SERVICE_PM_PARTS_STG table')

INSERT INTO ASM_PB_SERVICE_PM_PARTS_STG
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
--,stg.DealerCode
,pm.ItemID
,pm.PartQty
,stg.importeddate
,null as is_pm_part
,null as lineid
,null as item_qty_jc
,fk_contactid
,IG.Itemgrouptype
,GETDATE() AS Refresh_Date
,SCM.NAME as servicetype
,IM.Code As ItemCode
from CDMS_MENU_SERVICING_PART pm 
inner JOIN  asm_pb_service_stg stg
on pm.modelid=stg.FK_Modelid
and pm.ServiceType=stg.FK_Contracttypeid
and Usagereading between FromKM	and ToKM
left join ITEM_MASTER IM ON pm.ItemID = IM.ItemID
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=pm.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
INNER JOIN SERVICE_CONTRACT_MASTER SCM ON SCM.SERVICECONTRACTID = stg.FK_Contracttypeid
where CANCELLATIONDATE is null
and stg.importeddate > @MAXDATESTG



----------DeDup----------------

;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY FK_DOCID ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_PB_SERVICE_PM_PARTS_STG              
)          
DELETE FROM CTE                  
WHERE RNK<>1;




------Updates--------------------------

UPDATE PM 
set pm.is_pm_part= CASE WHEN stg.lineid is NOT null THEN 1 ELSE 0 END
,pm.lineid=stg.lineid
--,item_qty_jc=coalesce(stg.)
from ASM_PB_SERVICE_PM_PARTS_STG pm
inner JOIN  asm_pb_service_stg stg
on pm.fk_docid=stg.fk_docid
and pm.itemid=stg.fk_itemid


update pm
set pm.item_qty_jc= CASE WHEN COALESCE(SL.QtyAllocated,0) = 0 Then (SL.Qty - SL.QtyCancelled)  
       Else (SL.QtyAllocated - SL.QtyReturned) END
from ASM_PB_SERVICE_PM_PARTS_STG pm
INNER JOIN Service_line sl
on sl.lineid=pm.lineid
where pm.lineid is not null
and sl.docdate>'2022-04-01'



------Insert INTO ASM_MC_PM_PARTS_REPORT-----------

print('Inserting data in ASM_PB_PM_PARTS_REPORT table')


INSERT INTO ASM_PB_PM_PARTS_REPORT
select 
FK_Contracttypeid, 
FK_Docid, 
DOCNAME, 
Docdate, 
FK_Companyid, 
Isclosed, 
FK_Ibid, 
FK_Branchid, 
FK_Modelid, 
fk_contactid,
Billeddatetime, 
Usagereading, 
DealerCode, 
--ASD_DealerCode,
String_AGG (Case When is_pm_part <=item_qty_jc THEN im.code Else null end, ',') as PM_Parts_Replaced_code
,String_AGG (Case When is_pm_part <=item_qty_jc THEN im.name Else null end, ',') as PM_Parts_Replaced_code_name
,String_AGG (Case When is_pm_part <=item_qty_jc THEN null Else im.code  end, ',') as PM_Parts_not_Replaced_code
,String_AGG (Case When is_pm_part <=item_qty_jc THEN null Else im.name  end, ',') as PM_Parts_not_Replaced_name
,pm.Itemgrouptype
,pm.IMPORTEDDATE
,GETDATE() AS Refresh_Date
,pm.servicetype
,pm.Itemcode

from ASM_PB_SERVICE_PM_PARTS_STG pm
LEFT JOIN item_master im on im.itemid=pm.itemid
where   pm.IMPORTEDDATE > @MAXDATESTG2
group by FK_Contracttypeid, FK_Docid, DOCNAME, Docdate, FK_Companyid, Isclosed, FK_Ibid, FK_Branchid,fk_contactid, FK_Modelid, Billeddatetime, Usagereading, DealerCode,pm.IMPORTEDDATE, Refresh_Date,pm.Itemgrouptype,servicetype, Itemcode


----------------DeDup---------------------

;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY FK_DOCID ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_PB_PM_PARTS_REPORT              
)          
DELETE FROM CTE                  
WHERE RNK<>1;




END
GO