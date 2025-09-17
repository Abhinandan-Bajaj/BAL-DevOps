SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_MC_SERVICE_SERVICE_INCLOAD] AS 

BEGIN

/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-06-09 	|	Sarvesh Kulkarni		| Added logic to identify repeat job cases and pdt pdc report logic*/
/*	2024-12-02 	|	Ashwini Ahire    		| Added ELF related columns */
/*	2025-02-17 	|	Sarvesh Kulkarni        | Optimised SP    and Added logic to populate Aggregare_fact table  */
/*	2025-07-14 	|	Dewang Makani    		| Added columns for KPI Custom line level report  */
/*  2025-07-28    |     Rashi Pradhan           | Updated 3rdFS_To_1stPS flag case to OR condition (CR) */
/*  2025-09-03    |     Rashi Pradhan           | Commented the filter condidtion in ASD dealer mapping update*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

PRINT 'Execution Started ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));
DECLARE @MAXDATESTG DATETIME2(7)= (SELECT MAX(IMPORTEDDATE) FROM ASM_MC_SERVICE_STG)

PRINT('LOADING DATA FROM BASE TABLE')
INSERT INTO ASM_MC_SERVICE_STG
(Type
,FK_Contracttypeid
,FK_PartContracttypeid
,Lineid
,FK_Docid
,DOCNAME
,Docdate
,FK_Companyid
,FK_Contactid
,Isclosed
,FK_Itemid
,FK_Ibid
,FK_Branchid
,FK_Modelid
,BU
,COMPANYTYPE
,TOTALTAX
,Isrevisited
,Isrepeated
,ReasonForDelay
,MechanicalSameDayFlag
,AccidentalFlag
,Mechanical3HrsFlag
,Pretaxrevenue
,Itemgrouptype
,PaidFlag
,ServiceType
,DealerCode
,ASD_DealerCode
,Importeddate
,Vehicleinvoicedatetime
,Billeddatetime
,READYFORBILLDATETIME
,ESTTIMEGIVENTOCUSTOMER
,TOTALAMOUNT
,TOTALOFESTIMATEDCOST
,PDC_deviation_perc
,PDT_deviation_perc
,Delete_Flag
,Service_Retail_TypeIdentifier
,Usagereading
,QtyAllocated 
,QtyReturned  
,DateOfFailure
,TAT_Days
,Tat_Delivery 
,Qty
,Rate
,TradeDiscount
,Surveyor
,Posttaxrevenue
,[3rdFS_To_1stPS]
,[1st_Ps_Date]
,[3rd_Fs_Date]
,Technician
,Service_Advisor
,Bgo_Category
,repeat_type
,repeated_from_lined
,repeated_from_docname
,repeated_from_docdate
,CANCELLATIONDATE
,DefectCode
,Job_Card_Source
,Insurance_Provider
,Campaign)

SELECT BASE.*
,Pretaxrevenue+BASE.Totaltax AS Posttaxrevenue
,CAST(NULL AS INT) [3rdFS_To_1stPS]
,CAST(NULL AS DATE) [1st_Ps_Date]
,CAST(NULL AS DATE) [3rd_Fs_Date]
,CAST(NULL AS VARCHAR(100)) Technician
,CAST(NULL AS VARCHAR(100)) Service_Advisor
,CAST(NULL AS VARCHAR(50)) Bgo_Category
,null as repeat_type
,null as repeated_from_lined
,null as repeated_from_docname
,null as repeated_from_docdate
,null as CANCELLATIONDATE
,SLE.DEFECTCODE AS DefectCode
,SHE.JOBCARDSOURCE AS Job_Card_Source
,SHE.InsuranceCompany
,SHE.Campaign

FROM
(SELECT DISTINCT 
  SL.Type
 ,SH.CONTRACTTYPEID AS [FK_Contracttypeid]
 ,SL.CONTRACTTYPEID as [FK_PartContracttypeid]
 ,SL.LINEID AS Lineid
 ,SH.HEADERID AS [FK_Docid]
 ,SH.DOCNAME
 ,CAST(SH.Docdate AS DATE) AS Docdate
 ,SH.COMPANYID AS [FK_Companyid]
 ,SH.CONTACTID AS FK_Contactid
 ,SH.Isclosed
 ,SL.ITEMID AS [FK_Itemid]
 ,SH.IBID AS [FK_Ibid]
 ,SH.BRANCHID AS [FK_Branchid]
 ,SH.MODELID AS [FK_Modelid]
 ,SH.BU
 ,CM.COMPANYTYPE
 ,SL.TOTALTAX
 ,SH.Isrevisited 
 ,0 as Isrepeated 
 ,CASE WHEN SH.READYFORINVDELAYREASON IS NULL THEN 'Reason not selected'
       WHEN SH.READYFORINVDELAYREASON IS NOT NULL THEN SH.READYFORINVDELAYREASON END AS ReasonForDelay
-- ,CASE WHEN SL.TYPE = 'Service' AND SL.ISREPEATED = 1 THEN 'Labour'
--	   WHEN SL.TYPE != 'Service' AND SL.ISREPEATED = 1 THEN SL.TYPE END AS Repeat_Type
,CASE WHEN CAST(SH.READYFORBILLDATETIME AS DATE)=CAST(SH.DOCDATE AS DATE) AND SH.CONTRACTTYPEID NOT IN (8,168,43) THEN 1 ELSE 0 END AS MechanicalSameDayFlag
 ,CASE WHEN DATEDIFF(DAY,CAST(SH.DOCDATE AS DATE),CAST(SH.READYFORBILLDATETIME AS DATE))<=5 AND SH.CONTRACTTYPEID IN (43,5) THEN 1 ELSE 0 END AS AccidentalFlag
 ,CASE WHEN CAST(SH.READYFORBILLDATETIME AS DATE)=CAST(SH.DOCDATE AS DATE) 
			AND SH.CONTRACTTYPEID NOT IN (8,168,43)
			AND DATEDIFF(Minute,SH.DOCDATE,SH.READYFORBILLDATETIME)<=180 THEN 1 
	ELSE 0 END AS Mechanical3HrsFlag 
 --,CASE WHEN SH.VEHICLEINVOICEDATETIME<=SH.PROMISEDDATE THEN 1 ELSE 0 END AS Pdt_Flag
 --,CASE WHEN SH.TOTALAMOUNT < = SH.TOTALOFESTIMATEDCOST THEN 1 ELSE 0 END AS Pdc_Flag
 ,CASE WHEN SL.QtyAllocated = 0 Then (((SL.Qty - SL.QtyCancelled) * SL.Rate)   - SL.TradeDiscount ) 
       Else (((SL.QtyAllocated - SL.QtyReturned) * SL.Rate ) - SL.TradeDiscount ) END AS Pretaxrevenue
 ,CAST(IG.Itemgrouptype AS NVARCHAR(225)) AS Itemgrouptype
 ,CASE  WHEN SH.CONTRACTTYPEID IN (2,13,41,42,177,178,179,192,193) THEN 1
        WHEN SH.CONTRACTTYPEID NOT IN (38,39,40,8,168) AND IM.CODE IN ('BMPS0001','BMSL0029','AMCBAL001','AMCBAL002','AMCBAL003','AMCBAL004','AMCBAL005','AMCBAL006','AMCBAL007'
          ,'AMCBAL008','AMCBAL009','AMCBAL010','AMCBAL011','AMCBAL012','AMCBAL013','AMCBAL014','AMCBAL015','AMCBAL016','AMCBAL017','AMCBAL018','AMCBAL019','AMCBAL020'
          ,'AMCBAL021','AMCBAL022','AMCBAL023','AMCBAL024','AMCBAL025','AMCBAL026','AMCBAL027','AMCBAL028','AMCBAL029') THEN 1
       ELSE 0 END AS 'PaidFlag'             
 ,SCM1.NAME AS ServiceType
 ,CM.CODE AS DealerCode
 ,CM.CODE AS ASD_DealerCode
 ,SH.Importeddate
 ,CAST(SH.Vehicleinvoicedatetime AS DATE) AS Vehicleinvoicedatetime
 ,CAST(SH.Billeddatetime AS DATE) AS Billeddatetime
 ,SH.READYFORBILLDATETIME
 ,SH.ESTTIMEGIVENTOCUSTOMER
 ,SH.TOTALAMOUNT
 ,SH.TOTALOFESTIMATEDCOST
 ,ROUND (Case
    when SH.TOTALOFESTIMATEDCOST=0 or SH.TOTALOFESTIMATEDCOST is null then (SH.TOTALAMOUNT-1)*100/1
    else (SH.TOTALAMOUNT-SH.TOTALOFESTIMATEDCOST)*100/SH.TOTALOFESTIMATEDCOST
end ,2) as PDC_deviation_perc
, Case
	WHEN DATEDIFF(Day,SH.DOCDATE,SH.ESTTIMEGIVENTOCUSTOMER)>45 then 76
    when DATEDIFF(Minute,SH.DOCDATE,SH.ESTTIMEGIVENTOCUSTOMER)=0 or SH.ESTTIMEGIVENTOCUSTOMER is null then (Cast(DATEDIFF(Minute,SH.DOCDATE,SH.READYFORBILLDATETIME) as float)-1)*100/1
  else (Cast(DATEDIFF(Minute,SH.DOCDATE,SH.READYFORBILLDATETIME) as float)-CAST(DATEDIFF(Minute,SH.DOCDATE,SH.ESTTIMEGIVENTOCUSTOMER) as float))*100/coalesce(cast(DATEDIFF(Minute,SH.DOCDATE,SH.ESTTIMEGIVENTOCUSTOMER)as float),1)
  end  as PDT_deviation_perc
 ,0 AS Delete_Flag
 ,101 AS Service_Retail_TypeIdentifier
 ,SH.Usagereading
 ,SL.QtyAllocated AS QTYALLOCATED
 ,SL.QtyReturned AS QTYRETURNED
 ,SH.FailureDate AS DateOfFailure
 ,DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime) AS TAT_Days
 ,CASE WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>=0 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=2 THEN '0-2hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>2 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=4 THEN '2-4hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>4 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=8 THEN '4-8hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>8 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=24 THEN '8-24hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)> 24 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=2 THEN '1-2days'
      WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>2 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=3 THEN '2-3days'
	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>3 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=5 THEN '3-5days'
	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>5 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=7 THEN '5-7days'
   	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>7 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=15 THEN '7-15days'
	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>15 THEN '>15days'
	END AS [Tat_Delivery]
,SL.Qty
,SL.Rate
,SL.TradeDiscount
,SH.SurveyorName
FROM SERVICE_HEADER SH
LEFT JOIN SERVICE_LINE SL ON (SL.DOCID = SH.HEADERID AND SL.IMPORTEDDATE = (SELECT MAX(SL1.IMPORTEDDATE) FROM SERVICE_LINE SL1 WHERE SL1.ITEMID = SL.ITEMID AND SL.DOCID = SL1.DOCID))
--INNER JOIN BAL_Cequity_JCData_Updated BCD ON BCD.LINEID=SL.LINEID
INNER JOIN SERVICE_CONTRACT_MASTER SCM1 ON SCM1.SERVICECONTRACTID=SH.CONTRACTTYPEID
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=SL.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
LEFT JOIN ITEM_MASTER IM ON IM.ITEMID=SL.ITEMID
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (1,8))
WHERE SH.IMPORTEDDATE > @MAXDATESTG
AND CM.CODE NOT IN ('0000028428')
AND SH.IBID IS NOT NULL
AND SH.CANCELLATIONDATE IS NULL
AND SL.ISCLOSED<>0
AND SL.QTYALLOCATED<>0)BASE
LEFT JOIN SERVICE_LINE_EXT SLE ON SLE.LINEID = BASE.LINEID
LEFT JOIN SERVICE_HEADER_EXT SHE ON SHE.HEADERID = BASE.FK_DOCID


PRINT 'STG TABLE LOADED ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))
PRINT('STG TABLE LOADED')

-------------------Storing unique headerids in Temp. Object

PRINT('LOADING JC HEADERID FROM STG TABLE IN TEMP OBJ')

SELECT DISTINCT FK_DOCID
INTO #JC_HEADER_MC
FROM ASM_MC_SERVICE_STG
PRINT '#JC_HEADER_MC TABLE LOADED ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

---------------------Checking for missed JC
PRINT('CHECKING FOR MISSED JC IN BASE TABLES')

INSERT INTO ASM_MC_SERVICE_STG
(Type
,FK_Contracttypeid
,FK_PartContracttypeid
,Lineid
,FK_Docid
,DOCNAME
,Docdate
,FK_Companyid
,FK_Contactid
,Isclosed
,FK_Itemid
,FK_Ibid
,FK_Branchid
,FK_Modelid
,BU
,COMPANYTYPE
,TOTALTAX
,Isrevisited
,Isrepeated
,ReasonForDelay
,MechanicalSameDayFlag
,AccidentalFlag
,Mechanical3HrsFlag
,Pretaxrevenue
,Itemgrouptype
,PaidFlag
,ServiceType
,DealerCode
,ASD_DealerCode
,Importeddate
,Vehicleinvoicedatetime
,Billeddatetime
,READYFORBILLDATETIME
,ESTTIMEGIVENTOCUSTOMER
,TOTALAMOUNT
,TOTALOFESTIMATEDCOST
,PDC_deviation_perc
,PDT_deviation_perc
,Delete_Flag
,Service_Retail_TypeIdentifier
,Usagereading
,QtyAllocated 
,QtyReturned  
,DateOfFailure
,TAT_Days
,Tat_Delivery
,Qty
,Rate
,TradeDiscount
,Surveyor
,Posttaxrevenue
,[3rdFS_To_1stPS]
,[1st_Ps_Date]
,[3rd_Fs_Date]
,Technician
,Service_Advisor
,Bgo_Category
,repeat_type
,repeated_from_lined
,repeated_from_docname
,repeated_from_docdate
,CANCELLATIONDATE
,DefectCode
,Job_Card_Source
,Insurance_Provider
,Campaign)

SELECT BASE.*
,Pretaxrevenue+BASE.Totaltax AS Posttaxrevenue
,CAST(NULL AS INT) [3rdFS_To_1stPS]
,CAST(NULL AS DATE) [1st_Ps_Date]
,CAST(NULL AS DATE) [3rd_Fs_Date]
,CAST(NULL AS VARCHAR(100)) Technician
,CAST(NULL AS VARCHAR(100)) Service_Advisor
,CAST(NULL AS VARCHAR(50)) Bgo_Category
,null as repeat_type
,null as repeated_from_lined
,null as repeated_from_docname
,null as repeated_from_docdate
,null as CANCELLATIONDATE
,SLE.DEFECTCODE AS DefectCode
,SHE.JOBCARDSOURCE AS Job_Card_Source
,SHE.InsuranceCompany
,SHE.Campaign

FROM
(SELECT DISTINCT 
  SL.Type
 ,SH.CONTRACTTYPEID AS [FK_Contracttypeid]
 ,SL.CONTRACTTYPEID as [FK_PartContracttypeid]
 ,SL.LINEID AS Lineid
 ,SH.HEADERID AS [FK_Docid]
 ,SH.DOCNAME
 ,CAST(SH.Docdate AS DATE) AS Docdate
 ,SH.COMPANYID AS [FK_Companyid]
 ,SH.CONTACTID AS FK_Contactid
 ,SH.Isclosed
 ,SL.ITEMID AS [FK_Itemid]
 ,SH.IBID AS [FK_Ibid]
 ,SH.BRANCHID AS [FK_Branchid]
 ,SH.MODELID AS [FK_Modelid]
 ,SH.BU
 ,CM.COMPANYTYPE
 ,SL.TOTALTAX
 ,SH.Isrevisited 
 ,0 as Isrepeated 
 ,CASE WHEN SH.READYFORINVDELAYREASON IS NULL THEN 'Reason not selected'
       WHEN SH.READYFORINVDELAYREASON IS NOT NULL THEN SH.READYFORINVDELAYREASON END AS ReasonForDelay
-- ,CASE WHEN SL.TYPE = 'Service' AND SL.ISREPEATED = 1 THEN 'Labour'
--	   WHEN SL.TYPE != 'Service' AND SL.ISREPEATED = 1 THEN SL.TYPE END AS Repeat_Type
,CASE WHEN CAST(SH.READYFORBILLDATETIME AS DATE)=CAST(SH.DOCDATE AS DATE) AND SH.CONTRACTTYPEID NOT IN (8,168,43) THEN 1 ELSE 0 END AS MechanicalSameDayFlag
 ,CASE WHEN DATEDIFF(DAY,CAST(SH.DOCDATE AS DATE),CAST(SH.READYFORBILLDATETIME AS DATE))<=5 AND SH.CONTRACTTYPEID IN (43,5) THEN 1 ELSE 0 END AS AccidentalFlag
  ,CASE WHEN CAST(SH.READYFORBILLDATETIME AS DATE)=CAST(SH.DOCDATE AS DATE) 
			AND SH.CONTRACTTYPEID NOT IN (8,168,43)
			AND DATEDIFF(Minute,SH.DOCDATE,SH.READYFORBILLDATETIME)<=180 THEN 1 
	ELSE 0 END AS Mechanical3HrsFlag
 --,CASE WHEN SH.VEHICLEINVOICEDATETIME<=SH.PROMISEDDATE THEN 1 ELSE 0 END AS Pdt_Flag
-- ,CASE WHEN SH.TOTALAMOUNT < = SH.TOTALOFESTIMATEDCOST THEN 1 ELSE 0 END AS Pdc_Flag
 ,CASE WHEN SL.QtyAllocated = 0 Then (((SL.Qty - SL.QtyCancelled) * SL.Rate)   - SL.TradeDiscount ) 
       Else (((SL.QtyAllocated - SL.QtyReturned) * SL.Rate ) - SL.TradeDiscount ) END AS Pretaxrevenue
 ,CAST(IG.Itemgrouptype AS NVARCHAR(225)) AS Itemgrouptype
 ,CASE  WHEN SH.CONTRACTTYPEID IN (2,13,41,42,177,178,179,192,193) THEN 1
        WHEN SH.CONTRACTTYPEID NOT IN (38,39,40,8,168) AND IM.CODE IN ('BMPS0001','BMSL0029','AMCBAL001','AMCBAL002','AMCBAL003','AMCBAL004','AMCBAL005','AMCBAL006','AMCBAL007'
          ,'AMCBAL008','AMCBAL009','AMCBAL010','AMCBAL011','AMCBAL012','AMCBAL013','AMCBAL014','AMCBAL015','AMCBAL016','AMCBAL017','AMCBAL018','AMCBAL019','AMCBAL020'
          ,'AMCBAL021','AMCBAL022','AMCBAL023','AMCBAL024','AMCBAL025','AMCBAL026','AMCBAL027','AMCBAL028','AMCBAL029') THEN 1
       ELSE 0 END AS 'PaidFlag'             
 ,SCM1.NAME AS ServiceType
 ,CM.CODE AS DealerCode
 ,CM.CODE AS ASD_DealerCode
 ,SH.Importeddate
 ,CAST(SH.Vehicleinvoicedatetime AS DATE) AS Vehicleinvoicedatetime
 ,CAST(SH.Billeddatetime AS DATE) AS Billeddatetime
  ,SH.READYFORBILLDATETIME
 ,SH.ESTTIMEGIVENTOCUSTOMER
 ,SH.TOTALAMOUNT
 ,SH.TOTALOFESTIMATEDCOST
 ,ROUND (Case
    when SH.TOTALOFESTIMATEDCOST=0 or SH.TOTALOFESTIMATEDCOST is null then (SH.TOTALAMOUNT-1)*100/1
    else (SH.TOTALAMOUNT-SH.TOTALOFESTIMATEDCOST)*100/SH.TOTALOFESTIMATEDCOST
end ,2) as PDC_deviation_perc
, Case
	WHEN DATEDIFF(Day,SH.DOCDATE,SH.ESTTIMEGIVENTOCUSTOMER)>45 then 76
    when DATEDIFF(Minute,SH.DOCDATE,SH.ESTTIMEGIVENTOCUSTOMER)=0 or SH.ESTTIMEGIVENTOCUSTOMER is null then (Cast(DATEDIFF(Minute,SH.DOCDATE,SH.READYFORBILLDATETIME) as float)-1)*100/1
  else (Cast(DATEDIFF(Minute,SH.DOCDATE,SH.READYFORBILLDATETIME) as float)-CAST(DATEDIFF(Minute,SH.DOCDATE,SH.ESTTIMEGIVENTOCUSTOMER) as float))*100/coalesce(cast(DATEDIFF(Minute,SH.DOCDATE,SH.ESTTIMEGIVENTOCUSTOMER)as float),1)
  end  as PDT_deviation_perc
 ,0 AS Delete_Flag
 ,101 AS Service_Retail_TypeIdentifier
 ,SH.Usagereading
 ,SL.QtyAllocated AS QTYALLOCATED
 ,SL.QtyReturned AS QTYRETURNED
 ,SH.FailureDate AS DateOfFailure
 ,DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime) AS TAT_Days
 ,CASE WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>=0 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=2 THEN '0-2hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>2 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=4 THEN '2-4hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>4 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=8 THEN '4-8hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>8 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=24 THEN '8-24hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)> 24 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=2 THEN '1-2days'
      WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>2 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=3 THEN '2-3days'
	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>3 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=5 THEN '3-5days'
	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>5 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=7 THEN '5-7days'
   	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>7 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=15 THEN '7-15days'
	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>15 THEN '>15days'
	END AS [Tat_Delivery]
,SL.Qty
,SL.Rate
,SL.TradeDiscount
,SH.SurveyorName

FROM SERVICE_HEADER SH
LEFT JOIN #JC_HEADER_MC tempSH ON tempSH.FK_DOCID = SH.HEADERID 
LEFT JOIN SERVICE_LINE SL ON (SL.DOCID = SH.HEADERID AND SL.IMPORTEDDATE = (SELECT MAX(SL1.IMPORTEDDATE) FROM SERVICE_LINE SL1 WHERE SL1.ITEMID = SL.ITEMID AND SL.DOCID = SL1.DOCID))
--INNER JOIN BAL_Cequity_JCData_Updated BCD ON BCD.LINEID=SL.LINEID
INNER JOIN SERVICE_CONTRACT_MASTER SCM1 ON SCM1.SERVICECONTRACTID=SH.CONTRACTTYPEID
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=SL.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
LEFT JOIN ITEM_MASTER IM ON IM.ITEMID=SL.ITEMID
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (1,8))
WHERE CAST(SH.DOCDATE AS DATE) >= CAST(DATEADD(D,-90,GETDATE()) AS DATE) --AND SH.HEADERID NOT IN (SELECT DISTINCT FK_DOCID FROM #JC_HEADER_MC)
AND tempSH.FK_DOCID is null
AND CM.CODE NOT IN ('0000028428')
AND SH.IBID IS NOT NULL
AND SH.CANCELLATIONDATE IS NULL
AND SL.ISCLOSED<>0
AND SL.QTYALLOCATED<>0)BASE
LEFT JOIN SERVICE_LINE_EXT SLE ON SLE.LINEID = BASE.LINEID
LEFT JOIN SERVICE_HEADER_EXT SHE ON SHE.HEADERID = BASE.FK_DOCID

PRINT 'MISSED JC DATA LOADED ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

PRINT('MISSED JC DATA LOADED')
---------------------------------------
PRINT('DELETING DATA FOR DOCDATE GREATER THAN D-1')

Delete from ASM_MC_SERVICE_STG Where DOCDATE>Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate()))) - 1 as date);
---------------------------------------DEDUPE
PRINT 'Deleted currentdate records ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY FK_DOCID ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_MC_SERVICE_STG              
)          
DELETE FROM CTE                  
WHERE RNK<>1;
PRINT 'Deduplication of  ASM_MC_SERVICE_STG table' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))
------------------------------UPDATE DELETED LINEITEMS
PRINT('UPDATING DELETED LINE ITEMS')

SELECT DISTINCT SLD.LineID
INTO #DeletedLineID
FROM SERVICE_LINE_DELETED SLD
JOIN ASM_MC_SERVICE_STG ASF ON ASF.LINEID=SLD.LINEID
PRINT '#DeletedLineID table loaded' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

UPDATE ASF
SET ASF.Delete_Flag=1
FROM ASM_MC_SERVICE_STG ASF 
JOIN #DeletedLineID DLI ON DLI.LINEID=ASF.LINEID

PRINT 'DELETED LINE ITEMS UPDATED' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

Delete FROM ASM_MC_SERVICE_STG where Delete_Flag=1 

PRINT 'DELETED LINE ITEMS Deleted' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))


PRINT('DELETED LINE ITEMS UPDATED')
------------------------------UPDATE Cancellation date
print('Updating Cancellation date in ASM_PB_SERVICE_STG table')

Update ASF 
SET ASF.CANCELLATIONDATE=sh.CANCELLATIONDATE
FROM ASM_MC_SERVICE_STG ASF
LEFT JOIN SERVICE_HEADER SH ON sh.HEADERID = asf.FK_Docid
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (1,8))
WHERE SH.IMPORTEDDATE > DATEADD(Day,-2,@MAXDATESTG)
AND SH.CANCELLATIONDATE IS NOT NULL
print('Cancellation date updated in ASM_MC_SERVICE_STG table');;
PRINT 'Cancellation date updated in ASM_MC_SERVICE_STG table' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

Delete from ASM_MC_SERVICE_STG where CANCELLATIONDATE is not null;
PRINT 'Cancellation date Delete in ASM_MC_SERVICE_STG table' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

-------------------------------UPDATE 3RD FREE TO 1ST PAID DATA
PRINT('UPDATING DATA FOR 3rdFS to 1stPS Conversion')

SELECT DISTINCT MAIN_BASE.FK_IBID,FREE_MAIN_BLOCK.FREE_DATE AS [3rd_Fs_Date],PAID_MAIN_BLOCK1.PAID_DATE AS [1st_Ps_Date],FREE_MAIN_BLOCK.USAGEREADING_FS3,PAID_MAIN_BLOCK1.USAGEREADING_PAID1
,ABS(PAID_MAIN_BLOCK1.USAGEREADING_PAID1-FREE_MAIN_BLOCK.USAGEREADING_FS3) AS DIFF
,CASE WHEN DATEDIFF(DAY,FREE_MAIN_BLOCK.FREE_DATE,PAID_MAIN_BLOCK1.PAID_DATE)<210
          OR ABS(PAID_MAIN_BLOCK1.USAGEREADING_PAID1-FREE_MAIN_BLOCK.USAGEREADING_FS3)<6000 THEN 1 ELSE 0 END AS [3rdFS_To_1stPS]
INTO #3rdFS_To_1stPS_Data
FROM
(SELECT DISTINCT FK_IBID FROM ASM_MC_SERVICE_STG) MAIN_BASE

LEFT JOIN

(SELECT * FROM
(SELECT DISTINCT FK_IBID,SS.BILLEDDATETIME AS FREE_DATE
,SS.USAGEREADING AS USAGEREADING_FS3
,ROW_NUMBER() OVER(PARTITION BY FK_IBID ORDER BY SS.BILLEDDATETIME) FREE_RNO
FROM ASM_MC_SERVICE_STG SS
--LEFT JOIN SERVICE_CONTRACT_MASTER SC ON SC.SERVICECONTRACTID=SS.FK_Contracttypeid
WHERE SS.FK_Contracttypeid IN (40)) FREE_BLOCK1
WHERE FREE_RNO=1)FREE_MAIN_BLOCK ON FREE_MAIN_BLOCK.FK_IBID=MAIN_BASE.FK_IBID

LEFT JOIN 
(SELECT FK_IBID,PAID_DATE,USAGEREADING_PAID1 FROM
(SELECT FK_IBID,PAID_DATE,USAGEREADING_PAID1
,ROW_NUMBER() OVER(PARTITION BY FK_IBID ORDER BY PAID_DATE ASC) PAID_RNO
FROM
(SELECT BASE.FK_IBID,FREE_BLOCK2.FREE_DATE,PAID_BLOCK.PAID_DATE
,FREE_BLOCK2.USAGEREADING_FS3
,PAID_BLOCK.USAGEREADING_PAID1
,CASE WHEN PAID_BLOCK.PAID_DATE<FREE_BLOCK2.FREE_DATE THEN 1
      WHEN PAID_BLOCK.PAID_DATE>FREE_BLOCK2.FREE_DATE THEN 0 END AS EXCLUDE_FLAG
FROM
(SELECT DISTINCT FK_IBID FROM ASM_MC_SERVICE_STG) BASE
LEFT JOIN

(SELECT * FROM
(SELECT DISTINCT FK_IBID,SS.BILLEDDATETIME AS FREE_DATE
,SS.USAGEREADING AS USAGEREADING_FS3
,ROW_NUMBER() OVER(PARTITION BY FK_IBID ORDER BY SS.BILLEDDATETIME) FREE_RNO
FROM ASM_MC_SERVICE_STG SS
WHERE SS.FK_Contracttypeid IN (40)) FREE_BLOCK1
WHERE FREE_RNO=1)FREE_BLOCK2 ON FREE_BLOCK2.FK_IBID=BASE.FK_IBID
LEFT JOIN
(SELECT DISTINCT FK_IBID
,SS.BILLEDDATETIME AS PAID_DATE
,SS.USAGEREADING AS USAGEREADING_PAID1
 FROM ASM_MC_SERVICE_STG SS
WHERE SS.FK_CONTRACTTYPEID IN (2,41,42,192,193,13))PAID_BLOCK ON BASE.FK_IBID=PAID_BLOCK.FK_IBID
) BASE
WHERE EXCLUDE_FLAG<>1)PAID_FINAL_BLOCK
WHERE PAID_RNO=1)PAID_MAIN_BLOCK1 ON PAID_MAIN_BLOCK1.FK_IBID=MAIN_BASE.FK_IBID
PRINT 'Identified 3rd Fs to 1st ps' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))
UPDATE B
SET B.[3rdFS_To_1stPS]=A.[3rdFS_To_1stPS]
,B.[3rd_Fs_Date]=A.[3rd_Fs_Date]
,B.[1st_Ps_Date]=A.[1st_Ps_Date]
FROM ASM_MC_SERVICE_STG B
JOIN #3rdFS_To_1stPS_Data A ON A.FK_IBID=B.FK_IBID
WHERE B.[3rdFS_To_1stPS] IS NULL
PRINT 'Updated 3rd Fs to 1st ps' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

PRINT('3rdFS To 1stPS DATA UPDATED')

-------------------------------UPDATE BGO CATEGORY FLAG

PRINT('UPDATING BGO CATEGORY FLAG')

SELECT DISTINCT DOCID,
CASE WHEN SUM(OIL_WEIGHT) <=0.5 THEN 'TOP-UP'
ELSE 'REPLACED' END AS Bgo_Category
INTO #ServiceOilsBgoCategory
FROM
(SELECT 
IM.NAME
,SL.DOCID
,SL.LINEID
,CASE WHEN IM.NAME LIKE '%100 ml%' OR IM.NAME LIKE '%100ml%' AND IM.ITEMID NOT IN (60796,692022,732646) THEN 0.25
ELSE 1 END AS 'OIL_WEIGHT'
FROM SERVICE_LINE SL
JOIN SERVICE_HEADER SH ON SL.DOCID = SH.HEADERID
JOIN ASM_MC_SERVICE_STG stg on stg.lineid=Sl.lineid
JOIN COMPANY_MASTER CM ON (CM.COMPANYID = SH.COMPANYID AND CM.COMPANYTYPE IN (1,8))
INNER JOIN ITEM_MASTER IM ON IM.ITEMID=SL.ITEMID
INNER JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=SL.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
WHERE IG.ITEMGROUPTYPE='OILS'
AND CAST(SH.DOCDATE AS DATE) >= '2022-04-01'
AND SL.QTYALLOCATED<>0
AND SL.QTYRETURNED = 0
AND stg.Bgo_Category is NULL
) BASE
GROUP BY DOCID
PRINT 'BGO CATEGORY FLAG Identified' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))
UPDATE B 
SET B.Bgo_Category=A.Bgo_Category 
FROM ASM_MC_SERVICE_STG B
INNER JOIN #ServiceOilsBgoCategory A ON B.FK_DOCID=A.DOCID
WHERE B.Bgo_Category IS NULL
PRINT 'BGO CATEGORY UPDATED' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))
PRINT('BGO CATEGORY UPDATED')
----------------------------UPDATE ASD DEALERCODE MAPPING
PRINT('UPDATING DEALER ASD MAPPING')

SELECT * INTO #ServiceDealerMapping FROM
(SELECT DISTINCT ZF_ASC ASD_DEALERCODE,DEALER_CODE DEALERCODE
FROM SAP_ZSD_ASC_DETAIL
WHERE SER_STATUS = 'OPERATIONAL')T

UPDATE B
SET B.Dealercode=A.DEALERCODE
FROM ASM_MC_SERVICE_STG B
INNER JOIN #ServiceDealerMapping A ON B.ASD_DealerCode=A.ASD_DEALERCODE
--WHERE B.DEALERCODE>'0000020000'

--2025-09-03 (RP) Commenting the where condition as its just updating the ASD dealercodes. This change is added to resolve ASD mapping issue.

PRINT('DEALER ASD MAPPING UPDATED')
PRINT 'DEALER ASD MAPPING UPDATED' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

-------------------------------UPDATE TECHNICIAN AND SERVICE ADVISOR

UPDATE stg 
set stg.Service_Advisor=CM1.NAME
,stg.Technician=CM2.NAME
FROM ASM_MC_SERVICE_STG stg 
JOIN SERVICE_HEADER SH ON stg.FK_DOCID = SH.HEADERID
LEFT JOIN CONTACT_MASTER CM1 ON CM1.CONTACTID=SH.SALESPERSONID AND CM1.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CM1.CONTACTID = CN1.CONTACTID)
LEFT JOIN CONTACT_MASTER CM2 ON CM2.CONTACTID=SH.MECHANICID AND CM2.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CM2.CONTACTID = CN1.CONTACTID)
WHERE --SH.ISCLOSED=0
stg.Technician is null
AND CAST(SH.DOCDATE AS DATE) >='2022-04-01'
AND SH.CANCELLATIONDATE IS NULL

PRINT 'TECHNICIAN AND SERVICE ADVISOR UPDATED' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

/*
UPDATE B set B.Service_Advisor=A.Service_Advisor
,B.Technician=A.Technician
FROM ASM_MC_SERVICE_STG B
INNER JOIN #OpenJC_ManPowerData A ON B.FK_Docid=A.HEADERID
--WHERE B.ISCLOSED=0
WHERE B.Technician IS NULL
*/
------------------------------Identify Repeat Cases
select
	Lineid
	,[FK_Docid]
	,[FK_Itemid]
	,[FK_Ibid]
	,docdate
	,Isrevisited
	,type
into #revist_JC
from ASM_MC_SERVICE_STG
where Isrevisited =1
and docdate >  CAST(DATEADD(D,-60,GETDATE()) AS DATE)
;

SELECT
      t1.Lineid
	,t1.[FK_Docid]
	,t1.[FK_Itemid]
	,t1.[FK_Ibid]
	,t1.docdate
	,t1.Isrevisited
	,t1.[type]
    ,t2.lineid repeated_from_lined
    ,t2.docname repeated_from_docname
    ,t2.docdate repeated_from_docdate
	,count(t2.lineid) OVER (Partition BY  t1.Lineid,t1.[FK_Docid],t1.[FK_Itemid],t1.[FK_Ibid]) as cnt
into #repeatcases
from #revist_JC t1
LEFT JOIN ASM_MC_SERVICE_STG t2
on t2.docdate >= DATEADD(DAY, -30, t1.docdate)  AND t2.docdate < t1.docdate
and t1.[FK_Itemid] = t2.[FK_Itemid]
 and t1.[FK_Ibid] = t2.[FK_Ibid]
where  t2.docdate >  CAST(DATEADD(D,-120,GETDATE()) AS DATE)


SELECT
	t1.Lineid
	,Case when t1.[type] = 'Service' THEN 'Labour' else t1.[type] end as [type]
	,STRING_AGG(repeated_from_lined,',') repeated_from_lined
	,STRING_AGG(repeated_from_docname,',') repeated_from_docname
	,STRING_AGG(repeated_from_docdate,',') repeated_from_docdate
into #repeatcases_line_agg
from #repeatcases t1
where cnt>0
group by t1.Lineid,t1.[type]


UPDATE A
SET A.Repeat_Type = B.Type
, A.ISREPEATED = 1
,A.repeated_from_lined=B.repeated_from_lined
,A.repeated_from_docname = B.repeated_from_docname
,A.repeated_from_docdate = B.repeated_from_docdate
FROM ASM_MC_SERVICE_STG A
JOIN #repeatcases_line_agg B ON B.lineid = A.lineid
PRINT 'Repeat Cases identified' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

-------------------------------------------
SELECT
	t1.FK_DOCID
	,STRING_AGG(repeated_from_docname,',') repeated_from_docname
	,STRING_AGG(repeated_from_docdate,',') repeated_from_docdate
into #MUL_REPEAT_TYPE
from #repeatcases t1
where cnt>0
group by t1.FK_DOCID
having Count(distinct t1.[type])>1

UPDATE A
SET A.Repeat_Type = 'Part,Labour',
A.repeated_from_docname = B.repeated_from_docname,
A.repeated_from_docdate = B.repeated_from_docdate
FROM ASM_MC_SERVICE_STG A
JOIN #MUL_REPEAT_TYPE B ON B.FK_DOCID = A.FK_DOCID
WHERE A.ISREPEATED = 1
PRINT 'Repeat Cases updated' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

-----------------------------------------------------Closed_JC_Bucket
print('Updating data into closeJC_Buckets_MC')
UPDATE SH
SET SH.closeJC_Buckets_MC= CASE WHEN DATEDIFF(DAY,CAST(SH.DOCDATE AS DATE),CAST(SH.Billeddatetime AS DATE))<=3 THEN '<3 Days'
      WHEN DATEDIFF(DAY,CAST(SH.DOCDATE AS DATE),CAST(SH.Billeddatetime AS DATE)) < 7 THEN '3-7 Days'
      WHEN DATEDIFF(DAY,CAST(SH.DOCDATE AS DATE),CAST(SH.Billeddatetime AS DATE)) < 15 THEN '7-15 Days'
      WHEN DATEDIFF(DAY,CAST(SH.DOCDATE AS DATE),CAST(SH.Billeddatetime AS DATE)) < 30 THEN '15-30 Days'
      WHEN DATEDIFF(DAY,CAST(SH.DOCDATE AS DATE),CAST(SH.Billeddatetime AS DATE)) < 60 THEN '30-60 Days'
      WHEN DATEDIFF(DAY,CAST(SH.DOCDATE AS DATE),CAST(SH.Billeddatetime AS DATE)) < 90 THEN '60-90 Days'
      WHEN DATEDIFF(DAY,CAST(SH.DOCDATE AS DATE),CAST(SH.Billeddatetime AS DATE)) < 120 THEN '90-120 Days'
      WHEN DATEDIFF(DAY,CAST(SH.DOCDATE AS DATE),CAST(SH.Billeddatetime AS DATE)) >= 120 THEN '>= 120 Days' END
FROM ASM_MC_SERVICE_STG SH
where SH.ISCLOSED=1
and closeJC_Buckets_MC is null
PRINT 'closeJC_Buckets_MC updated' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

-----------------------------------------------------

---------------------INSERT SERVICE DATA IN FACT TABLE
PRINT('INSERTING DATA INTO FACT TABLE')

DELETE FROM ASM_MC_SERVICE_FACT WHERE SERVICE_RETAIL_TYPEIDENTIFIER=101
PRINT 'Data deleted from ASM_MC_SERVICE_FACT' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

INSERT INTO ASM_MC_SERVICE_FACT(Type,
FK_Contracttypeid,
FK_PartContracttypeid,
Lineid,
FK_Docid,
DOCNAME,
Docdate,
FK_Companyid,
FK_Contactid,
Isclosed,
FK_Itemid,
FK_Ibid,
FK_Branchid,
FK_Modelid,
COMPANYTYPE,
Isrevisited,
Isrepeated,
ReasonForDelay,
Repeat_Type,
MechanicalSameDayFlag,
AccidentalFlag,
Mechanical3HrsFlag,
Pdt_Flag,
Pdc_Flag,
TAT_Days,
Tat_Delivery,
Pretaxrevenue,
Itemgrouptype,
Bgo_Category,
PaidFlag,
ServiceType,
DealerCode,
Importeddate,
Vehicleinvoicedatetime,
Billeddatetime,
[READYFORBILLDATETIME],
[ESTTIMEGIVENTOCUSTOMER],
[TOTALAMOUNT],
[TOTALOFESTIMATEDCOST],
Service_Retail_TypeIdentifier,
Posttaxrevenue,
ASD_DealerCode,
OpenJC_Buckets_MC,
closeJC_Buckets_MC,
[3rdFS_To_1stPS],
Technician,
Service_Advisor,
Refresh_Date,
PDC_deviation_perc,
PDT_deviation_perc,
PDC_deviation_buckets,
PDT_deviation_buckets,
repeated_from_lined,
repeated_from_docname,
repeated_from_docdate,
DefectCode,
Job_Card_Source,
Usagereading,
Qty,
Rate,
TradeDiscount,
TOTALTAX,
Surveyor,
Insurance_Provider,
Campaign,
KM_Range

)

SELECT Type,
FK_Contracttypeid,
FK_PartContracttypeid,
Lineid,
FK_Docid,
DOCNAME,
Docdate,
FK_Companyid,
FK_Contactid,
Isclosed,
FK_Itemid,
FK_Ibid,
FK_Branchid,
FK_Modelid,
COMPANYTYPE,
Isrevisited,
Isrepeated,
ReasonForDelay,
Repeat_Type,
MechanicalSameDayFlag,
AccidentalFlag,
Mechanical3HrsFlag,
CASE WHEN READYFORBILLDATETIME <= ESTTIMEGIVENTOCUSTOMER THEN 1 ELSE 0 END AS Pdt_Flag,
CASE WHEN -10<=PDC_deviation_perc and PDC_deviation_perc<= 10 THEN 1 ELSE 0 END AS Pdc_Flag,
TAT_Days,
Tat_Delivery,
Pretaxrevenue,
Itemgrouptype,
Bgo_Category,
PaidFlag,
ServiceType,
DealerCode,
Importeddate,
Vehicleinvoicedatetime,
Billeddatetime,
[READYFORBILLDATETIME],
[ESTTIMEGIVENTOCUSTOMER],
[TOTALAMOUNT],
[TOTALOFESTIMATEDCOST],
Service_Retail_TypeIdentifier,
Posttaxrevenue,
ASD_DealerCode,
CASE WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE())<=3 THEN '<3 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 7 THEN '3-7 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 15 THEN '7-15 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 30 THEN '15-30 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 60 THEN '30-60 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 90 THEN '60-90 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 120 THEN '90-120 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) >= 120 THEN '>= 120 Days' END AS OpenJC_Buckets_MC,
closeJC_Buckets_MC,
[3rdFS_To_1stPS],
Technician,
Service_Advisor,
GETDATE() AS Refresh_Date,
PDC_deviation_perc,
PDT_deviation_perc,
CASE
    WHEN PDC_deviation_perc<-25 THEN '<-25%'
    WHEN -25 <= PDC_deviation_perc AND PDC_deviation_perc <-10 THEN '-25% to -10%'
    WHEN -10 <= PDC_deviation_perc AND PDC_deviation_perc < 0 THEN '-10% to 0%'
    WHEN  0 <= PDC_deviation_perc AND PDC_deviation_perc <= 10 THEN '0% to 10%'
    WHEN  10 < PDC_deviation_perc AND PDC_deviation_perc <= 25 THEN '10% to 25%'
    WHEN  25 <=PDC_deviation_perc THEN '>25%'
END as 'PDC_deviation_buckets',
CASE
    WHEN abs(PDT_deviation_perc)<= 10 THEN '<10%'
    WHEN -10 < abs(PDT_deviation_perc) AND abs(PDT_deviation_perc) <=25 THEN '10% to 25%'
    WHEN 25 < abs(PDT_deviation_perc) AND abs(PDT_deviation_perc) <= 50 THEN '25% to 50%'
    WHEN 50 < abs(PDT_deviation_perc) AND abs(PDT_deviation_perc) <= 75 THEN '50% to 75%'
    WHEN 75 <abs(PDT_deviation_perc) THEN '>75%'
END as 'PDT_deviation_buckets',
repeated_from_lined,
repeated_from_docname,
repeated_from_docdate,
DefectCode,
Job_Card_Source,
Usagereading,
Qty,
Rate,
TradeDiscount,
TOTALTAX,
Surveyor,
Insurance_Provider,
Campaign,
CASE
    WHEN ARS.Usagereading <= 100 THEN '<= 100'
    WHEN ARS.Usagereading >100 and ARS.Usagereading <=500 THEN '101-500'
    WHEN ARS.Usagereading >500 and ARS.Usagereading <=1000 THEN '501-1000'
    WHEN ARS.Usagereading >1000 and ARS.Usagereading <=3000 THEN '1001-3000'
    WHEN ARS.Usagereading >3000 and ARS.Usagereading <=5000 THEN '3001-5000'
    WHEN ARS.Usagereading >5000 and ARS.Usagereading <=10000 THEN '5001-10000'
    WHEN ARS.Usagereading >10000 and ARS.Usagereading <=20000 THEN '10001-20000'
    WHEN ARS.Usagereading >20000 and ARS.Usagereading <=30000 THEN '20001-30000'
    WHEN ARS.Usagereading >30000 THEN '> 30000'
END as KM_Range

FROM ASM_MC_SERVICE_STG ARS
WHERE ARS.DELETE_FLAG<>1
and ARS.CANCELLATIONDATE is null
PRINT 'Service Data inserted into fact table' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

print('Service Data inserted into fact table');

DELETE FROM ASM_MC_SERVICE_FACT_AGR WHERE SERVICE_RETAIL_TYPEIDENTIFIER=101
PRINT 'Data deleted from ASM_MC_SERVICE_FACT_AGR' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

INSERT INTO ASM_MC_SERVICE_FACT_AGR(Type,
FK_Contracttypeid,
FK_PartContracttypeid,
FK_Docid,
DOCNAME,
Docdate,
FK_Contactid,
Isclosed,
FK_Ibid,
FK_Branchid,
FK_Modelid,
Isrevisited,
Isrepeated,
ReasonForDelay,
Repeat_Type,
MechanicalSameDayFlag,
AccidentalFlag,
Mechanical3HrsFlag,
Pdt_Flag,
Pdc_Flag,
TAT_Days,
Tat_Delivery,
Pretaxrevenue,
Itemgrouptype,
Bgo_Category,
PaidFlag,
ServiceType,
[Dealercode],
Vehicleinvoicedatetime,
Billeddatetime,
Service_Retail_TypeIdentifier,
Posttaxrevenue,
OpenJC_Buckets_MC,
closeJC_Buckets_MC,
[3rdFS_To_1stPS],
Technician,
Service_Advisor,
Refresh_Date,
ASD_Dealercode,
PDC_deviation_buckets,
PDT_deviation_buckets
)

SELECT 
Type,
FK_Contracttypeid,
FK_PartContracttypeid,
FK_Docid,
DOCNAME,
Docdate,
FK_Contactid,
Isclosed,
FK_Ibid,
FK_Branchid,
FK_Modelid,
Isrevisited,
MAX(Isrepeated) AS Isrepeated,
ReasonForDelay,
Repeat_Type,
MechanicalSameDayFlag,
AccidentalFlag,
Mechanical3HrsFlag,
Pdt_Flag,
Pdc_Flag,
TAT_Days,
Tat_Delivery,
SUM(Pretaxrevenue) AS Pretaxrevenue,
Itemgrouptype,
Bgo_Category,
PaidFlag,
ServiceType,
Dealercode,
Vehicleinvoicedatetime,
Billeddatetime,
Service_Retail_TypeIdentifier,
SUM(Posttaxrevenue) AS Posttaxrevenue,
OpenJC_Buckets_MC,
closeJC_Buckets_MC,
[3rdFS_To_1stPS],
Technician,
Service_Advisor,
GETDATE() AS Refresh_Date,
ASD_Dealercode,
PDC_deviation_buckets,
PDT_deviation_buckets
FROM ASM_MC_SERVICE_FACT ARS
where Service_Retail_TypeIdentifier=101
GROUP BY
Type,
FK_Contracttypeid,
FK_PartContracttypeid,
FK_Docid,
DOCNAME,
Docdate,
FK_Contactid,
Isclosed,
FK_Ibid,
FK_Branchid,
FK_Modelid,
Isrevisited,
ReasonForDelay,
Repeat_Type,
MechanicalSameDayFlag,
AccidentalFlag,
Mechanical3HrsFlag,
Pdt_Flag,
Pdc_Flag,
TAT_Days,
Tat_Delivery,
Itemgrouptype,
Bgo_Category,
PaidFlag,
ServiceType,
Dealercode,
Vehicleinvoicedatetime,
Billeddatetime,
Service_Retail_TypeIdentifier,
[3rdFS_To_1stPS],
Technician,
Service_Advisor,
ASD_Dealercode,
PDC_deviation_buckets,
PDT_deviation_buckets,
OpenJC_Buckets_MC,
closeJC_Buckets_MC;
PRINT 'Service Data inserted into aggregate fact table' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))


print('Dropping temporary tables');

DROP TABLE #ServiceDealerMapping
Drop TABLE #JC_HEADER_MC
Drop TABLE #DeletedLineID 
Drop TABLE #3rdFS_To_1stPS_Data
Drop TABLE #ServiceOilsBgoCategory
drop table #MUL_REPEAT_TYPE
drop table #repeatcases
drop table #revist_JC
drop table #repeatcases_line_agg
print('Temporary tables dropped');
PRINT 'Script Execution completed' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

END
GO