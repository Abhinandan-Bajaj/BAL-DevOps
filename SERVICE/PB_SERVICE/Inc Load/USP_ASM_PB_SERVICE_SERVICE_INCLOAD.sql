SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_PB_SERVICE_SERVICE_INCLOAD] AS 
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-12-09 	|	Sarvesh Kulkarni		| Added Oil item ids in paid flag calculation*/
/*	2024-10-24 	|	Sarvesh Kulkarni		| Added Bigbike Paid Service Labour Codes*/
/*	2024-10-07 	|	Sarvesh Kulkarni		| Changes for retail & fiscal year changes*/
/*	2024-08-02 	|	Sarvesh Kulkarni		| Changes for Triumph TAT and 2ndfs_to_1stps*/
/*	2024-07-15 	|	Sarvesh Kulkarni		| Changes for Open JC */
/*	2024-06-24 	|	Sarvesh Kulkarni		| Part repair contract typeid, service_advisor, techician */
/*	2024-06-17 	|	Sarvesh Kulkarni		| First deployment for Service data for Padi Service, Revenue, TAT and Rv/RJ screen */
/*	2024-01-07 	|	Ashwini Ahire   		| Parts Failure Screen first deployment  
    2025-04-01 	|	Richa Mishra  		| TAT columns addition  */
/*	2025-04-10 	|	Dewang Makani		    | Addition of new columns for PB reports */
/*	2025-07-01 	|	Dewang Makani		| Updated SDD due and done logic */
/*  2025-07-25  |   Rashi Pradhan       | Addition of assure AMC labour code to paid flag logic */
/*  2025-10-13  | Rashi Pradhan   | Updated other to Null for PartRepairType for part failure prod issue fix and added audit log */
/*  2025-10-27  | Rashi Pradhan   | Updated missing SDD code and NOLOCK for COMPANY_MASTER/BRANCH_MASTER/ZSD_DEALER_REPOS per Dhanraj suggestion */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

Begin
DECLARE @MAXDATESTG DATETIME2(7)= (SELECT MAX(IMPORTEDDATE) FROM ASM_PB_SERVICE_STG)

--------------AUdit table --------------------------
PRINT 'Audit Execution Started ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_PB_SERVICE_SERVICE_INCLOAD';
		

DECLARE @StartDate_utc DATETIME = GETDATE(),
            @EndDate_utc DATETIME,
			@StartDate_ist DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist DATETIME,
            @Duration_sec bigint,
			@Duration varchar(15),
			 @table_name VARCHAR(128) = 'ASM_PB_SERVICE_STG',
            @SourceCount BIGINT,  
            @TargetCount BIGINT, 			
            @Status VARCHAR(10),
            @ErrorMessage VARCHAR(MAX),
			
			---For update----
			@StartDate_utc2 DATETIME,
            @EndDate_utc2 DATETIME,
			@StartDate_ist2 DATETIME,
            @EndDate_ist2 DATETIME,
            @Duration_sec2 bigint,
			@Duration2 varchar(15),
			@table_name2 VARCHAR(128) = 'All updates'
			


 BEGIN TRY			
			
			SELECT @SourceCount = COUNT(1)
        from (select SH.HEADERID AS FK_DOCID, SL.LINEID  from SERVICE_HEADER SH
LEFT JOIN SERVICE_LINE SL ON (SL.DOCID = SH.HEADERID AND SL.IMPORTEDDATE = (SELECT MAX(SL1.IMPORTEDDATE) FROM SERVICE_LINE SL1 WHERE SL1.ITEMID = SL.ITEMID AND SL.DOCID = SL1.DOCID))
INNER JOIN SERVICE_CONTRACT_MASTER SCM1 ON SCM1.SERVICECONTRACTID=SH.CONTRACTTYPEID
LEFT JOIN SERVICE_LINE_EXT SLE ON SLE.LINEID = SL.LINEID
LEFT JOIN INSTALL_BASE_MASTER IBM ON IBM.IBID=SH.IBID
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=SL.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
LEFT JOIN ITEM_MASTER IM WITH (NOLOCK) ON IM.ITEMID=SL.ITEMID
INNER JOIN COMPANY_MASTER CM WITH (NOLOCK) ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WITH (NOLOCK) WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (2))
WHERE SH.IMPORTEDDATE > @MAXDATESTG
AND SH.IBID IS NOT NULL
AND SH.CANCELLATIONDATE IS NULL
)BASE
LEFT join SERVICE_HEADER_EXT ext 
on base.fk_docid =ext.headerid 

PRINT 'Audit Source count execution completed' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

----------------------------SP Logic-----------------------------------------------------------------------

PRINT 'Execution Started ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));


INSERT INTO ASM_PB_SERVICE_STG
(Type, FK_Contracttypeid	,FK_PartContracttypeid	,Lineid	,FK_Docid	,DOCNAME	,Docdate	,FK_Companyid	,FK_Contactid	,Isclosed	,FK_Itemid	,Qty	
,Qtyallocated	,Qtycancelled	,Qtyreturned	,Rate	,Totaltax	,Tradediscount	,FK_Ibid	,Usagereading	,Totalamount	,FK_Branchid	,FK_Modelid	,BU	,COMPANYTYPE,Isrevisited, Isrepeated,[2HrsTat_Delivery]	,[7DaysTat_Delivery],Jcvaluebracket	,TAT_Days,Pdt_Flag, Pdc_Flag,Pretaxrevenue,Itemgrouptype,PaidFlag,ServiceType, DealerCode,Importeddate	,InvoiceDate,Vehicleinvoicedatetime	,Billeddatetime	,Delete_Flag, Service_Retail_TypeIdentifier	, ReasonForDelay,retail_fiscal_year, service_fiscal_year, DefectCode, PartRepairType, JobCardStatus, PDIOK, PDINOTOK, PDINOWOK, CUSTOMERVOICECODEWARRANTY, CUSTOMERVOICENAMEWARRANTY,SDD_DUE,SDD_BILL,SDD_READY, CustomerVoiceDetails, CausalFlag, CausalPartCode, SA_WM_Observation, Part_Repeat_Count,Posttaxrevenue,[3rdFS_To_1stPS],[1st_Ps_Date], [3rd_Fs_Date],JOBCARDSOURCE,Service_Advisor,Technician	,CANCELLATIONDATE,ReasonOfRepeatVisit,ReadyForInvDelayReason,ReadyForInvDelayReasonOther,[2ndFS_To_1stPS], [2nd_Fs_Date], [1st_Ps_Date_2], CustomerVoice)
SELECT BASE.*
,NULL AS Part_Repeat_Count
,Pretaxrevenue+Totaltax AS Posttaxrevenue
,CAST(NULL AS INT) [3rdFS_To_1stPS]
,CAST(NULL AS DATE) [1st_Ps_Date]
,CAST(NULL AS DATE) [3rd_Fs_Date]
,ext.JOBCARDSOURCE
,CAST(NULL AS VARCHAR(100)) Technician
,CAST(NULL AS VARCHAR(100)) Service_Advisor
,null as CANCELLATIONDATE
,ext.ReasonOfRepeatVisit
,ext.ReadyForInvDelayReason
,ext.ReadyForInvDelayReasonOther
,null as [2ndFS_To_1stPS]
,null as [2nd_Fs_Date]
,null as [1st_Ps_Date_2]
,concat(ext.customervoice, '; ', base.CustomerVoiceDetails) as CustomerVoice

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
 ,SL.Qty
 ,SL.Qtyallocated
 ,SL.Qtycancelled
 ,SL.Qtyreturned
 ,SL.Rate
 ,SL.Totaltax
 ,SL.Tradediscount
 ,SH.IBID AS [FK_Ibid]
 ,SH.Usagereading
 ,SH.Totalamount
 ,SH.BRANCHID AS [FK_Branchid]
 ,SH.MODELID AS [FK_Modelid]
 ,SH.BU
 ,CM.COMPANYTYPE
 ,SH.Isrevisited 
 ,SL.Isrepeated
,CASE WHEN DATEDIFF(MI,SH.DOCDATE,SH.Billeddatetime)>=0 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<2 THEN '<2hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>=2 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<24 THEN '<24hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>=24 AND DATEDIFF(Day,SH.DOCDATE,SH.Billeddatetime)<=2 THEN '<=2days'
      WHEN DATEDIFF(Day,SH.DOCDATE,SH.Billeddatetime)>2 AND DATEDIFF(Day,SH.DOCDATE,SH.Billeddatetime)<=7 THEN '<=7days'
      WHEN DATEDIFF(Day,SH.DOCDATE,SH.Billeddatetime)>7 THEN '>7days' END AS [2HrsTat_Delivery]
,CASE WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>=0 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=2 THEN '0-2hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>2 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=4 THEN '2-4hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>4 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=8 THEN '4-8hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>8 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=24 THEN '8-24hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)< 24 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=2 THEN '1-2days'
      WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>2 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=3 THEN '2-3days'
	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>3 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=5 THEN '3-5days'
	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>5 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=7 THEN '5-7days'
   	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>7 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=15 THEN '7-15days'
	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>15 THEN '>15days'
	  END AS [7DaysTat_Delivery]   
,CASE WHEN SH.TOTALAMOUNT>=0 AND SH.TOTALAMOUNT<20 THEN '<20'
      WHEN SH.TOTALAMOUNT>=20 AND SH.TOTALAMOUNT<50 THEN '20-50'
      WHEN SH.TOTALAMOUNT>=50 AND SH.TOTALAMOUNT<100 THEN '50-100'
      WHEN SH.TOTALAMOUNT>=100 AND SH.TOTALAMOUNT<250 THEN '100-250'
      WHEN SH.TOTALAMOUNT>=250 AND SH.TOTALAMOUNT<500 THEN '250-500'
      WHEN SH.TOTALAMOUNT>=500 THEN '>500' END AS Jcvaluebracket 
,DATEDIFF(DAY,SH.DOCDATE,SH.VEHICLEINVOICEDATETIME) AS TAT_Days
 ,CASE WHEN SH.VEHICLEINVOICEDATETIME<=SH.PROMISEDDATE THEN 1 ELSE 0 END AS Pdt_Flag
 ,CASE WHEN SH.TOTALAMOUNT < = SH.TOTALOFESTIMATEDCOST THEN 1 ELSE 0 END AS Pdc_Flag
 ,CASE WHEN SL.QtyAllocated = 0 Then (((SL.Qty - SL.QtyCancelled) * SL.Rate)   - SL.TradeDiscount ) 
       Else (((SL.QtyAllocated - SL.QtyReturned) * SL.Rate ) - SL.TradeDiscount ) END AS Pretaxrevenue
 ,CAST(IG.Itemgrouptype AS NVARCHAR(225)) AS Itemgrouptype
 ,CASE WHEN IM.CODE IN ('KTMSL0001','KTMSL0002','KTMSL0003','KTMSL0004','KTMSL0005','HSQSL0001 ','HSQSL0002','HSQSL0003','HSQSL0004','HSQSL0005','TRISL0263') THEN 1
      WHEN SL.ITEMID IN (1177061,1177062,1177063,1177064,1177065,1177066,1177067,1177068,1177069,1177070,1177071,1177072,1177073,1177074,1177075,1177076,1177077,1177078,1177079,1177082) THEN 1 -- BigBike Paid Service labor ids
      WHEN SL.ITEMID IN (83010498,489345,50233,1208163,1107952,1178989) THEN 1  -- KTM & TRM OIL itemids
      WHEN SL.ITEMID IN (1226151,1226150,1226149) THEN 1 ---Assure AMC Labour Codes (CR)
       ELSE 0 END AS 'PaidFlag'                            
 ,SCM1.NAME AS ServiceType
 ,CM.CODE AS DealerCode
 ,SH.Importeddate
 ,IBM.INVOICEDATE AS InvoiceDate
 ,CAST(SH.Vehicleinvoicedatetime AS DATE) AS Vehicleinvoicedatetime
 ,CAST(SH.Billeddatetime AS DATE) AS Billeddatetime
 ,0 AS Delete_Flag
 ,101 AS Service_Retail_TypeIdentifier
 ,CASE WHEN SH.ISCLOSED=0 AND SH.READYFORINVDELAYREASON IS NULL THEN 'Reason not selected'
       WHEN SH.ISCLOSED=0 AND SH.READYFORINVDELAYREASON IS NOT NULL THEN READYFORINVDELAYREASON END AS ReasonForDelay
,CASE    WHEN ISNULL(IBM.INVOICEDATE, '') = '' THEN NULL
        WHEN MONTH(IBM.INVOICEDATE) >= 4 THEN Concat('FY ',Cast(YEAR(IBM.INVOICEDATE)+1 as varchar))
        ELSE Concat('FY ',Cast(YEAR(IBM.INVOICEDATE) as varchar))
END retail_fiscal_year
,CASE WHEN MONTH(SH.Docdate) >= 4 THEN Concat('FY ',Cast(YEAR(SH.Docdate)+1 as varchar)) ELSE Concat('FY ',Cast(YEAR(SH.Docdate) as varchar)) END service_fiscal_year
,SLE.DefectCode AS DefectCode
,NULL AS PartRepairType
,CASE
       WHEN SH.ISREADYFORINVOICE= 1 and  SH.ISCLOSED = 0 THEN 'Ready_For_Invoice'
       WHEN SH.ISCLOSED = 0 AND (SH.READYFORBILLDATETIME IS NULL AND SH.BILLEDDATETIME IS  NULL) THEN 'Open'
       WHEN SH.ISCLOSED = 1 AND SH.READYFORBILLDATETIME IS NOT NULL AND SH.BILLEDDATETIME IS NOT NULL THEN 'Delivered/Closed'
END AS JobCardStatus
,SH.PDIOK AS PDIOK
,SH.PDINOTOK AS PDINOTOK
,SH.PDINOWOK AS PDINOWOK
,SLE.CUSTOMERVOICECODEWARRANTY AS CUSTOMERVOICECODEWARRANTY
,SLE.CUSTOMERVOICENAMEWARRANTY AS CUSTOMERVOICENAMEWARRANTY
,CASE 
	WHEN ((datepart(hour, sh.docdate)>= 0 and datepart(hour,sh.docdate)<16) OR (cast(sh.docdate as date) = cast(sh.billeddatetime as date))) and SH.CONTRACTTYPEID NOT IN (8,168,43)
	THEN 1
	ELSE 0
END AS 'SDD_DUE'
,CASE 
      WHEN cast(sh.docdate as date) = cast(sh.billeddatetime as date) AND SH.CONTRACTTYPEID NOT IN (8,168,43)
      THEN 1 
      ELSE 0 
END AS 'SDD_BILL'
,CASE WHEN DATEPART(HOUR, SH.DOCDATE) >= 0 AND DATEPART(HOUR, SH.DOCDATE) <= 16 AND CAST(SH.READYFORBILLDATETIME AS DATE)=CAST(SH.DOCDATE AS DATE) AND SH.CONTRACTTYPEID NOT IN (8,168,43) THEN 1 ELSE 0 END AS 'SDD_READY'
,SH.CustomerVoiceDetails AS CustomerVoiceDetails
,SLE.CAUSALFLAG AS CausalFlag
,SLE.CAUSALPARTCODE AS CausalPartCode
,SLE.REMARKS AS SA_WM_Observation

FROM SERVICE_HEADER SH
LEFT JOIN SERVICE_LINE SL ON (SL.DOCID = SH.HEADERID AND SL.IMPORTEDDATE = (SELECT MAX(SL1.IMPORTEDDATE) FROM SERVICE_LINE SL1 WHERE SL1.ITEMID = SL.ITEMID AND SL.DOCID = SL1.DOCID))
INNER JOIN SERVICE_CONTRACT_MASTER SCM1 ON SCM1.SERVICECONTRACTID=SH.CONTRACTTYPEID
LEFT JOIN SERVICE_LINE_EXT SLE ON SLE.LINEID = SL.LINEID
LEFT JOIN INSTALL_BASE_MASTER IBM ON IBM.IBID=SH.IBID
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=SL.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
LEFT JOIN ITEM_MASTER IM WITH (NOLOCK) ON IM.ITEMID=SL.ITEMID
INNER JOIN COMPANY_MASTER CM WITH (NOLOCK) ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WITH (NOLOCK) WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (2))
WHERE SH.IMPORTEDDATE > @MAXDATESTG
AND SH.IBID IS NOT NULL
AND SH.CANCELLATIONDATE IS NULL
--AND SL.ISCLOSED<>0
--AND SL.QTYALLOCATED<>0
)BASE
LEFT join SERVICE_HEADER_EXT ext 
on base.fk_docid =ext.headerid 
------------------------------------------------------------------------------------------------------
-------------------Storing unique headerids in Temp. Object

PRINT('LOADING JC HEADERID FROM STG TABLE IN TEMP OBJ')

SELECT DISTINCT FK_DOCID
INTO #JC_HEADER_PB
FROM ASM_PB_SERVICE_STG

---------------------Checking for missed JC
PRINT('CHECKING FOR MISSED JC IN BASE TABLES')


INSERT INTO ASM_PB_SERVICE_STG
(Type, FK_Contracttypeid	,FK_PartContracttypeid	,Lineid	,FK_Docid	,DOCNAME	,Docdate	,FK_Companyid	,FK_Contactid	,Isclosed	,FK_Itemid	,Qty	
,Qtyallocated	,Qtycancelled	,Qtyreturned	,Rate	,Totaltax	,Tradediscount	,FK_Ibid	,Usagereading	,Totalamount	,FK_Branchid	,FK_Modelid	,BU	,COMPANYTYPE,Isrevisited, Isrepeated,[2HrsTat_Delivery]	,[7DaysTat_Delivery],Jcvaluebracket	,TAT_Days,Pdt_Flag, Pdc_Flag,Pretaxrevenue,Itemgrouptype,PaidFlag,ServiceType, DealerCode,Importeddate	,InvoiceDate,Vehicleinvoicedatetime	,Billeddatetime	,Delete_Flag, Service_Retail_TypeIdentifier	, ReasonForDelay,retail_fiscal_year, service_fiscal_year, DefectCode, PartRepairType, JobCardStatus, PDIOK, PDINOTOK, PDINOWOK, CUSTOMERVOICECODEWARRANTY, CUSTOMERVOICENAMEWARRANTY,SDD_DUE,SDD_BILL,SDD_READY, CustomerVoiceDetails, CausalFlag, CausalPartCode, SA_WM_Observation, Part_Repeat_Count,Posttaxrevenue,[3rdFS_To_1stPS],[1st_Ps_Date], [3rd_Fs_Date],JOBCARDSOURCE,Service_Advisor,Technician	,CANCELLATIONDATE,ReasonOfRepeatVisit,ReadyForInvDelayReason,ReadyForInvDelayReasonOther,[2ndFS_To_1stPS], [2nd_Fs_Date], [1st_Ps_Date_2], CustomerVoice)
SELECT BASE.*
,NULL AS Part_Repeat_Count
,Pretaxrevenue+Totaltax AS Posttaxrevenue
,CAST(NULL AS INT) [3rdFS_To_1stPS]
,CAST(NULL AS DATE) [1st_Ps_Date]
,CAST(NULL AS DATE) [3rd_Fs_Date]
,ext.JOBCARDSOURCE
,CAST(NULL AS VARCHAR(100)) Technician
,CAST(NULL AS VARCHAR(100)) Service_Advisor
,null as CANCELLATIONDATE
,ext.ReasonOfRepeatVisit
,ext.ReadyForInvDelayReason
,ext.ReadyForInvDelayReasonOther
,null as [2ndFS_To_1stPS]
,null as [2nd_Fs_Date]
,null as [1st_Ps_Date_2]
,concat(ext.customervoice, '; ', base.CustomerVoiceDetails) as CustomerVoice

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
 ,SL.Qty
 ,SL.Qtyallocated
 ,SL.Qtycancelled
 ,SL.Qtyreturned
 ,SL.Rate
 ,SL.Totaltax
 ,SL.Tradediscount
 ,SH.IBID AS [FK_Ibid]
 ,SH.Usagereading
 ,SH.Totalamount
 ,SH.BRANCHID AS [FK_Branchid]
 ,SH.MODELID AS [FK_Modelid]
 ,SH.BU
 ,CM.COMPANYTYPE
 ,SH.Isrevisited 
 ,SL.Isrepeated 
,CASE WHEN DATEDIFF(MI,SH.DOCDATE,SH.Billeddatetime)>=0 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<2 THEN '<2hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>=2 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<24 THEN '<24hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>=24 AND DATEDIFF(Day,SH.DOCDATE,SH.Billeddatetime)<=2 THEN '<=2days'
      WHEN DATEDIFF(Day,SH.DOCDATE,SH.Billeddatetime)>2 AND DATEDIFF(Day,SH.DOCDATE,SH.Billeddatetime)<=7 THEN '<=7days'
      WHEN DATEDIFF(Day,SH.DOCDATE,SH.Billeddatetime)>7 THEN '>7days' END AS [2HrsTat_Delivery]
,CASE WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>=0 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=2 THEN '0-2hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>2 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=4 THEN '2-4hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>4 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=8 THEN '4-8hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)>8 AND DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)<=24 THEN '8-24hrs'
      WHEN DATEDIFF(HH,SH.DOCDATE,SH.Billeddatetime)< 24 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=2 THEN '1-2days'
      WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>2 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=3 THEN '2-3days'
	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>3 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=5 THEN '3-5days'
	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>5 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=7 THEN '5-7days'
   	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>7 AND DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)<=15 THEN '7-15days'
	WHEN DATEDIFF(DAY,SH.DOCDATE,SH.Billeddatetime)>15 THEN '>15days'
	  END AS [7DaysTat_Delivery]   
,CASE WHEN SH.TOTALAMOUNT>=0 AND SH.TOTALAMOUNT<20 THEN '<20'
      WHEN SH.TOTALAMOUNT>=20 AND SH.TOTALAMOUNT<50 THEN '20-50'
      WHEN SH.TOTALAMOUNT>=50 AND SH.TOTALAMOUNT<100 THEN '50-100'
      WHEN SH.TOTALAMOUNT>=100 AND SH.TOTALAMOUNT<250 THEN '100-250'
      WHEN SH.TOTALAMOUNT>=250 AND SH.TOTALAMOUNT<500 THEN '250-500'
      WHEN SH.TOTALAMOUNT>=500 THEN '>500' END AS Jcvaluebracket 
,DATEDIFF(DAY,SH.DOCDATE,SH.VEHICLEINVOICEDATETIME) AS TAT_Days
 ,CASE WHEN SH.VEHICLEINVOICEDATETIME<=SH.PROMISEDDATE THEN 1 ELSE 0 END AS Pdt_Flag
 ,CASE WHEN SH.TOTALAMOUNT < = SH.TOTALOFESTIMATEDCOST THEN 1 ELSE 0 END AS Pdc_Flag
 ,CASE WHEN SL.QtyAllocated = 0 Then (((SL.Qty - SL.QtyCancelled) * SL.Rate)   - SL.TradeDiscount ) 
       Else (((SL.QtyAllocated - SL.QtyReturned) * SL.Rate ) - SL.TradeDiscount ) END AS Pretaxrevenue
 ,CAST(IG.Itemgrouptype AS NVARCHAR(225)) AS Itemgrouptype
 ,CASE WHEN IM.CODE IN ('KTMSL0001','KTMSL0002','KTMSL0003','KTMSL0004','KTMSL0005','HSQSL0001 ','HSQSL0002','HSQSL0003','HSQSL0004','HSQSL0005','TRISL0263') THEN 1
      WHEN SL.ITEMID IN (1177061,1177062,1177063,1177064,1177065,1177066,1177067,1177068,1177069,1177070,1177071,1177072,1177073,1177074,1177075,1177076,1177077,1177078,1177079,1177082) THEN 1  -- BigBike Paid Service labor ids
      WHEN SL.ITEMID IN (83010498,489345,50233,1208163,1107952,1178989) THEN 1  -- KTM & TRM OIL itemids
      WHEN SL.ITEMID IN (1226151,1226150,1226149) THEN 1 ---Assure AMC Labour Codes (CR)
       ELSE 0 END AS 'PaidFlag'             
 ,SCM1.NAME AS ServiceType
 ,CM.CODE AS DealerCode
 ,SH.Importeddate
 ,IBM.INVOICEDATE AS InvoiceDate
 ,CAST(SH.Vehicleinvoicedatetime AS DATE) AS Vehicleinvoicedatetime
 ,CAST(SH.Billeddatetime AS DATE) AS Billeddatetime
 ,0 AS Delete_Flag
 ,101 AS Service_Retail_TypeIdentifier
 ,CASE WHEN SH.ISCLOSED=0 AND SH.READYFORINVDELAYREASON IS NULL THEN 'Reason not selected'
       WHEN SH.ISCLOSED=0 AND SH.READYFORINVDELAYREASON IS NOT NULL THEN READYFORINVDELAYREASON END AS ReasonForDelay
,CASE    WHEN ISNULL(IBM.INVOICEDATE, '') = '' THEN NULL
        WHEN MONTH(IBM.INVOICEDATE) >= 4 THEN Concat('FY ',Cast(YEAR(IBM.INVOICEDATE)+1 as varchar))
        ELSE Concat('FY ',Cast(YEAR(IBM.INVOICEDATE) as varchar))
END retail_fiscal_year
,CASE WHEN MONTH(SH.Docdate) >= 4 THEN Concat('FY ',Cast(YEAR(SH.Docdate)+1 as varchar)) ELSE Concat('FY ',Cast(YEAR(SH.Docdate) as varchar)) END service_fiscal_year
,SLE.DefectCode AS DefectCode
,NULL AS PartRepairType
,CASE
       WHEN SH.ISREADYFORINVOICE= 1 and  SH.ISCLOSED = 0 THEN 'Ready_For_Invoice'
       WHEN SH.ISCLOSED = 0 AND (SH.READYFORBILLDATETIME IS NULL AND SH.BILLEDDATETIME IS  NULL) THEN 'Open'
       WHEN SH.ISCLOSED = 1 AND SH.READYFORBILLDATETIME IS NOT NULL AND SH.BILLEDDATETIME IS NOT NULL THEN 'Delivered/Closed'
END AS JobCardStatus
,SH.PDIOK AS PDIOK
,SH.PDINOTOK AS PDINOTOK
,SH.PDINOWOK AS PDINOWOK
,SLE.CUSTOMERVOICECODEWARRANTY AS CUSTOMERVOICECODEWARRANTY
,SLE.CUSTOMERVOICENAMEWARRANTY AS CUSTOMERVOICENAMEWARRANTY
,CASE 
	WHEN ((datepart(hour, sh.docdate)>= 0 and datepart(hour,sh.docdate)<16) OR (cast(sh.docdate as date) = cast(sh.billeddatetime as date))) and SH.CONTRACTTYPEID NOT IN (8,168,43)
	THEN 1
	ELSE 0
END AS 'SDD_DUE'
,CASE 
      WHEN cast(sh.docdate as date) = cast(sh.billeddatetime as date) AND SH.CONTRACTTYPEID NOT IN (8,168,43)
      THEN 1 
      ELSE 0 
END AS 'SDD_BILL'
,CASE WHEN DATEPART(HOUR, SH.DOCDATE) >= 0 AND DATEPART(HOUR, SH.DOCDATE) <= 16 AND CAST(SH.READYFORBILLDATETIME AS DATE)=CAST(SH.DOCDATE AS DATE) AND SH.CONTRACTTYPEID NOT IN (8,168,43) THEN 1 ELSE 0 END AS 'SDD_READY'
,SH.CustomerVoiceDetails AS CustomerVoiceDetails
,SLE.CAUSALFLAG AS CausalFlag
,SLE.CAUSALPARTCODE AS CausalPartCode
,SLE.REMARKS AS SA_WM_Observation

FROM SERVICE_HEADER SH
LEFT JOIN SERVICE_LINE SL ON (SL.DOCID = SH.HEADERID AND SL.IMPORTEDDATE = (SELECT MAX(SL1.IMPORTEDDATE) FROM SERVICE_LINE SL1 WHERE SL1.ITEMID = SL.ITEMID AND SL.DOCID = SL1.DOCID))
INNER JOIN SERVICE_CONTRACT_MASTER SCM1 ON SCM1.SERVICECONTRACTID=SH.CONTRACTTYPEID
LEFT JOIN SERVICE_LINE_EXT SLE ON SLE.LINEID = SL.LINEID
LEFT JOIN INSTALL_BASE_MASTER IBM ON IBM.IBID=SH.IBID
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=SL.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
LEFT JOIN ITEM_MASTER IM WITH (NOLOCK) ON IM.ITEMID=SL.ITEMID
INNER JOIN COMPANY_MASTER CM WITH (NOLOCK) ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WITH (NOLOCK) WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (2))
WHERE CAST(SH.DOCDATE AS DATE) >= CAST(DATEADD(D,-90,GETDATE()) AS DATE) AND SH.HEADERID NOT IN (SELECT DISTINCT FK_DOCID FROM #JC_HEADER_PB)
AND SH.IBID IS NOT NULL
AND SH.CANCELLATIONDATE IS NULL
--AND SL.ISCLOSED<>0
--AND SL.QTYALLOCATED<>0
)BASE
LEFT join SERVICE_HEADER_EXT ext 
on base.fk_docid =ext.headerid

print('Inserted data in ASM_PB_SERVICE_STG table')

-------------------------------------------------------------------------------------------------------
PRINT('DELETING DATA FOR DOCDATE GREATER THAN D-1')

Delete from ASM_PB_SERVICE_STG Where DOCDATE>Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate()))) - 1 as date);
---------------------------------------DEDUPE
;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY FK_DOCID ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_PB_SERVICE_STG              
)          
DELETE FROM CTE                  
WHERE RNK<>1;

--------------------Updates Audit Start

PRINT('Updates')

    SET @StartDate_utc2 = GETDATE();
	SET @StartDate_ist2 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));

------------------------------UPDATE DELETE FLAG
print('Updating delete flag in ASM_PB_SERVICE_STG table')

SELECT DISTINCT SLD.LineID
INTO #DeletedLineID
FROM SERVICE_LINE_DELETED SLD
JOIN ASM_PB_SERVICE_STG ASF ON ASF.LINEID=SLD.LINEID

UPDATE ASF
SET ASF.Delete_Flag=1
FROM ASM_PB_SERVICE_STG ASF 
JOIN #DeletedLineID DLI ON DLI.LINEID=ASF.LINEID

print('Delete flag updated in ASM_PB_SERVICE_STG table')
------------------------------UPDATE Cancellation date
print('Updating Cancellation date in ASM_PB_SERVICE_STG table')

Update ASF 
SET ASF.CANCELLATIONDATE=sh.CANCELLATIONDATE
FROM ASM_PB_SERVICE_STG ASF
LEFT JOIN SERVICE_HEADER SH ON sh.HEADERID = asf.FK_Docid
INNER JOIN COMPANY_MASTER CM WITH (NOLOCK) ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WITH (NOLOCK) WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (2))
WHERE SH.IMPORTEDDATE > DATEADD(Day,-2,@MAXDATESTG)
AND SH.CANCELLATIONDATE IS NOT NULL
print('Cancellation date updated in ASM_PB_SERVICE_STG table');;
-------------------------------UPDATE 3RD FREE TO 1ST PAID DATA

print('Updating 3rd Fs to 1st PS in ASM_PB_SERVICE_STG table')

;;WITH MAIN_BASE as (
    SELECT DISTINCT FK_IBID
    FROM ASM_PB_SERVICE_STG
),
FREE_BLOCK as (
    SELECT *
    FROM (
            SELECT DISTINCT FK_IBID,
                SS.DOCDATE AS FREE_DATE,
                SS.USAGEREADING AS USAGEREADING_FS3,
                ROW_NUMBER() OVER(
                    PARTITION BY FK_IBID
                    ORDER BY SS.DOCDATE
                ) FREE_RNO
            FROM ASM_PB_SERVICE_STG SS
            WHERE SS.FK_Contracttypeid IN (40)
        ) FREE_BLOCK1
    WHERE FREE_RNO = 1
),
FREE_BLOCK2 as (
    SELECT *
    FROM (
            SELECT DISTINCT FK_IBID,
                SS.DOCDATE AS FREE_DATE,
                SS.USAGEREADING AS USAGEREADING_FS2,
                ROW_NUMBER() OVER(
                    PARTITION BY FK_IBID
                    ORDER BY SS.DOCDATE
                ) FREE_RNO
            FROM ASM_PB_SERVICE_STG SS
            WHERE SS.FK_Contracttypeid IN (39)
        ) FREE_BLOCK1
    WHERE FREE_RNO = 1
),
PAID_BLOCK as (
    SELECT DISTINCT FK_IBID,
        BU,
        SS.DOCDATE AS PAID_DATE,
        SS.USAGEREADING AS USAGEREADING_PAID1
    FROM ASM_PB_SERVICE_STG SS
    WHERE SS.PAIDFLAG = 1
)
select mb.FK_IBID,
    [3rd_Fs_Date],
    [2nd_Fs_Date],
    [1st_Ps_Date],
    [1st_Ps_Date_2],
    USAGEREADING_FS3,
    USAGEREADING_FS2,
    USAGEREADING_PAID1,
    USAGEREADING_PAID2,
    DIFF3rd_fs_ps,
    DIFF2nd_fs_ps,
CASE
        WHEN DATEDIFF(DAY, [3rd_Fs_Date], [1st_Ps_Date]) < 210
        AND ABS(USAGEREADING_PAID1 - USAGEREADING_FS3) < 8000 THEN 1
        ELSE 0
    END AS [3rdFS_To_1stPS],
CASE
        WHEN DATEDIFF(DAY, [2nd_Fs_Date], [1st_Ps_Date_2]) < 395
        AND ABS(USAGEREADING_PAID2 - USAGEREADING_FS2) < 17000 THEN 1
        ELSE 0
    END AS [2ndFS_To_1stPS]
into #3rdFS_To_1stPS_Data
from MAIN_BASE mb
    LEFT JOIN (
        select DISTINCT MAIN_BASE.FK_IBID,
            FREE_BLOCK.FREE_DATE AS [3rd_Fs_Date],
            FREE_BLOCK2.FREE_DATE AS [2nd_Fs_Date],
            PAID_BLOCK.PAID_DATE AS [1st_Ps_Date],
            PAID_BLOCK2.PAID_DATE AS [1st_Ps_Date_2],
            FREE_BLOCK.USAGEREADING_FS3,
            FREE_BLOCK2.USAGEREADING_FS2,
            PAID_BLOCK.USAGEREADING_PAID1,
            PAID_BLOCK2.USAGEREADING_PAID1 as USAGEREADING_PAID2,
            ABS(
                PAID_BLOCK.USAGEREADING_PAID1 - FREE_BLOCK.USAGEREADING_FS3
            ) AS DIFF3rd_fs_ps,
            ABS(
                PAID_BLOCK2.USAGEREADING_PAID1 - FREE_BLOCK2.USAGEREADING_FS2
            ) AS DIFF2nd_fs_ps,
            ROW_NUMBER() OVER(
                PARTITION BY MAIN_BASE.FK_IBID
                ORDER BY PAID_BLOCK.PAID_DATE ASC
            ) PAID_RNO,
            ROW_NUMBER() OVER(
                PARTITION BY MAIN_BASE.FK_IBID
                ORDER BY PAID_BLOCK.PAID_DATE ASC
            ) PAID_RNO1
        from MAIN_BASE
            LEFT JOIN FREE_BLOCK ON FREE_BLOCK.FK_IBID = MAIN_BASE.FK_IBID
            LEFT JOIN FREE_BLOCK2 ON FREE_BLOCK2.FK_IBID = MAIN_BASE.FK_IBID
            LEFT JOIN PAID_BLOCK ON PAID_BLOCK.FK_IBID = MAIN_BASE.FK_IBID
            and (
                PAID_BLOCK.PAID_DATE > FREE_BLOCK.FREE_DATE
                OR PAID_BLOCK.PAID_DATE is null
            )
            LEFT JOIN PAID_BLOCK PAID_BLOCK2 ON PAID_BLOCK2.FK_IBID = MAIN_BASE.FK_IBID
            and (
                PAID_BLOCK2.PAID_DATE > FREE_BLOCK2.FREE_DATE
                OR PAID_BLOCK2.PAID_DATE is null
            )
    ) t on mb.FK_IBID = t.FK_IBID
    and PAID_RNO = 1
    and PAID_RNO1 = 1


UPDATE B
SET B.[3rdFS_To_1stPS]=A.[3rdFS_To_1stPS]
,B.[3rd_Fs_Date]=A.[3rd_Fs_Date]
,B.[1st_Ps_Date]=A.[1st_Ps_Date]
,B.[2ndFS_To_1stPS]=A.[2ndFS_To_1stPS]
,B.[2nd_Fs_Date]=A.[2nd_Fs_Date]
,B.[1st_Ps_Date_2]=A.[1st_Ps_Date_2]
FROM ASM_PB_SERVICE_STG B
JOIN #3rdFS_To_1stPS_Data A ON A.FK_IBID=B.FK_IBID

print('Updated 3rd Fs to 1st PS flag in ASM_PB_SERVICE_STG table')
--------------------UPDATE TECHNICIAN AND SERVICE ADVISOR

SELECT DISTINCT SH.HEADERID, CM1.NAME AS Service_Advisor, CM2.NAME AS Technician
INTO #OpenJC_ManPowerData
FROM SERVICE_HEADER SH
LEFT JOIN CONTACT_MASTER CM1 ON CM1.CONTACTID=SH.SALESPERSONID AND CM1.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CM1.CONTACTID = CN1.CONTACTID)
LEFT JOIN CONTACT_MASTER CM2 ON CM2.CONTACTID=SH.MECHANICID AND CM2.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CM2.CONTACTID = CN1.CONTACTID)
WHERE 
1=1
and SH.IMPORTEDDATE > @MAXDATESTG
--AND CAST(SH.DOCDATE AS DATE) >='2022-04-01'
AND SH.CANCELLATIONDATE IS NULL


UPDATE B set B.Service_Advisor=A.Service_Advisor
,B.Technician=A.Technician
FROM ASM_PB_SERVICE_STG B
INNER JOIN #OpenJC_ManPowerData A ON B.FK_Docid=A.HEADERID;
--WHERE B.ISCLOSED=0


-----------------------------UPDATE FOR PART REPAIR TYPE---------------------------------------
PRINT('UPDATING PART REPAIRTYPE')

UPDATE STG
SET PartRepairType = 
                  CASE 
                        WHEN STG.FK_PartContractTypeID = 1 THEN 'Warranty'
                        WHEN STG.FK_PartContractTypeID = 8 THEN 'PDI'
                        WHEN STG.FK_PartContractTypeID IN (170, 199) THEN '5 Year Warranty'
                        WHEN STG.FK_PartContractTypeID IN (3, 6) THEN 'Special Sanction'
                        WHEN STG.FK_PartContractTypeID IN (2, 13, 23, 41, 45, 167, 216, 217) THEN 'Paid'
						ELSE 'Others'
                    END 
FROM ASM_PB_SERVICE_STG STG
INNER JOIN ITEM_MASTER IM WITH (NOLOCK) ON im.itemid = STG.fk_itemid
WHERE STG.Type = 'Part'
  AND STG.ItemGroupType in ('BAL Parts', 'OILS', 'TRM BB ACC', 'TRM BB CLO', 'TRM BB MAR MAT', 'TRM BB SPARE PARTS', 'TRM TB ACC', 'TRM TB SPARE PARTS') 
AND STG.PartRepairType IS NULL;

PRINT('PART REPAIRTYPE UPDATED');
--------------------------------------------

--PB STG Part Repeat--

WITH PartitionedData AS (
   SELECT 
       STG.FK_Ibid,
       STG.FK_Itemid,
       STG.PartRepairType,
       STG.FK_docid,
       ROW_NUMBER() OVER (PARTITION BY STG.FK_Ibid, STG.FK_Itemid, STG.PartRepairType ORDER BY STG.FK_docid) AS RowNum
   FROM 
       ASM_PB_SERVICE_STG STG
LEFT JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON IBM.PK_Ibid = STG.FK_Ibid
WHERE DATEDIFF(YEAR, STG.DOCDATE, IBM.ProductionDate) <= 5 AND STG.TYPE = 'Part'
)
 
UPDATE OriginalData
SET Part_Repeat_Count = CASE
   WHEN PartitionedData.RowNum = 1 THEN 0
   ELSE 1
END
FROM 
   ASM_PB_SERVICE_STG AS OriginalData
JOIN 
   PartitionedData
ON 
   OriginalData.FK_docid = PartitionedData.FK_docid and
   OriginalData.FK_ibid = PartitionedData.FK_ibid and
   OriginalData.FK_itemid = PartitionedData.FK_itemid;

PRINT('PB STG DATA LOADED')

---------------------------update Audit End

SET @EndDate_utc2 = GETDATE();
	SET @EndDate_ist2 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));
    SET @Duration_sec2 = DATEDIFF(SECOND, @StartDate_ist2, @EndDate_ist2);
	SET @Duration2 = CONVERT(VARCHAR(8), DATEADD(SECOND, @Duration_sec2, 0), 108);
    EXEC [USP_Audit_Balance_Control_Logs] 
	     @SPID,
        @sp_name,
		@table_name2,
        'Service',
        'PB',
        @StartDate_utc2,
        @EndDate_utc2,
		@StartDate_ist2,
        @EndDate_ist2,
        @Duration2,  
        NULL,
        NULL,
        'NA',
        'NA';

---------------------INSERT INTO FACT TABLE

print('Deleteing service data from ASM_PB_SERVICE_FACT table')

DELETE FROM ASM_PB_SERVICE_FACT WHERE SERVICE_RETAIL_TYPEIDENTIFIER=101
print('Deleted service data from ASM_PB_SERVICE_FACT table')

print('Inserting service data in ASM_PB_SERVICE_FACT table')

INSERT INTO ASM_PB_SERVICE_FACT(Type,
FK_Contracttypeid,
Lineid,
FK_Docid,
DOCNAME,
Docdate,
FK_Companyid,
FK_Contactid,
Isclosed,
FK_Itemid,
Qty,
Qtyallocated,
Qtycancelled,
Qtyreturned,
Rate,
Totaltax,
Tradediscount,
FK_Ibid,
Usagereading,
Totalamount,
FK_Branchid,
FK_Modelid,
BU,
COMPANYTYPE,
Isrevisited,
Isrepeated,
[2HrsTat_Delivery],
[7DaysTat_Delivery],
Jcvaluebracket,
Pdt_Flag,
Pdc_Flag,
Pretaxrevenue,
Itemgrouptype,
PaidFlag,
ServiceType,
DealerCode,
Importeddate,
InvoiceDate,
Vehicleinvoicedatetime,
Billeddatetime,
Service_Retail_TypeIdentifier,
Posttaxrevenue,
LastServiceDate,
LastServiceName,
LastKmReading,
VehicleAging,
[3rdFS_To_1stPS],
[1st_Ps_Date],
[3rd_Fs_Date],
TAT_Days,
Refresh_Date,
JOBCARDSOURCE,
ReasonForDelay,
Service_Advisor,
Technician,
[FK_PartContracttypeid],
ReasonOfRepeatVisit,
ReadyForInvDelayReason,
ReadyForInvDelayReasonOther,
[2ndFS_To_1stPS],
[2nd_Fs_Date],
[1st_Ps_Date_2],
retail_fiscal_year,
service_fiscal_year,
DefectCode,
PartRepairType,
JobCardStatus,
PDIOK, 
PDINOTOK,
PDINOWOK,
CUSTOMERVOICECODEWARRANTY,
CUSTOMERVOICENAMEWARRANTY,
Part_Repeat_Count,
SDD_DUE,
SDD_BILL,
SDD_READY,
Service_Revenue_Type,
CustomerVoiceDetails,
CausalFlag, 
CausalPartCode, 
SA_WM_Observation
)

SELECT Type,
FK_Contracttypeid,
Lineid,
FK_Docid,
DOCNAME,
Docdate,
FK_Companyid,
FK_Contactid,
Isclosed,
FK_Itemid,
Qty,
Qtyallocated,
Qtycancelled,
Qtyreturned,
Rate,
Totaltax,
Tradediscount,
FK_Ibid,
Usagereading,
Totalamount,
FK_Branchid,
FK_Modelid,
BU,
COMPANYTYPE,
Isrevisited,
Isrepeated,
[2HrsTat_Delivery],
[7DaysTat_Delivery],
Jcvaluebracket,
Pdt_Flag,
Pdc_Flag,
Pretaxrevenue,
Itemgrouptype,
PaidFlag,
ServiceType,
DealerCode,
Importeddate,
InvoiceDate,
Vehicleinvoicedatetime,
Billeddatetime,
Service_Retail_TypeIdentifier,
Posttaxrevenue,
LastServiceDate,
LastServiceName,
LastKmReading,
DATEDIFF(D,InvoiceDate,GETDATE()) AS VehicleAging,
[3rdFS_To_1stPS],
[1st_Ps_Date],
[3rd_Fs_Date],
TAT_Days,
GETDATE() AS Refresh_Date,
JOBCARDSOURCE,
ReasonForDelay,
Service_Advisor,
Technician,
[FK_PartContracttypeid],
ReasonOfRepeatVisit,
ReadyForInvDelayReason,
ReadyForInvDelayReasonOther,
[2ndFS_To_1stPS],
[2nd_Fs_Date],
[1st_Ps_Date_2],
retail_fiscal_year,
service_fiscal_year,
DefectCode,
PartRepairType,
JobCardStatus,
PDIOK, 
PDINOTOK,
PDINOWOK,
CUSTOMERVOICECODEWARRANTY,
CUSTOMERVOICENAMEWARRANTY,
Part_Repeat_Count,
SDD_DUE,
SDD_BILL,
SDD_READY,
CASE 
        WHEN Service_Retail_TypeIdentifier = 101 THEN 
			CASE    WHEN Itemgrouptype <> 'OILS' AND Type ='Part' Then 'Spares' 
					WHEN Type ='Service' then 'Labour'
					WHEN Itemgrouptype = 'OILS' AND Type ='Part' Then 'Lube' 
					Else null End
					End as  Service_Revenue_Type
,CustomerVoice,
CausalFlag, 
CausalPartCode, 
SA_WM_Observation

FROM ASM_PB_SERVICE_STG ASG

LEFT JOIN

(SELECT IBID
,LastServiceDate
,LastServiceName
,LastKmReading
FROM
(SELECT DISTINCT IBID
,CAST(BILLEDDATETIME AS DATE) AS LastServiceDate
,SCM.NAME AS LastServiceName
,SH.UsageReading as LastKmReading
,ROW_NUMBER() OVER(PARTITION BY IBID ORDER BY BILLEDDATETIME DESC) RNO
FROM SERVICE_HEADER SH
JOIN COMPANY_MASTER CM WITH (NOLOCK) ON (CM.COMPANYID = SH.COMPANYID AND CM.COMPANYTYPE = 2)
JOIN SERVICE_CONTRACT_MASTER SCM ON SCM.SERVICECONTRACTID=SH.CONTRACTTYPEID
) LATEST_DATE
WHERE RNO=1) LSD on LSD.IBID=ASG.FK_Ibid
WHERE ASG.DELETE_FLAG<>1
and ASG.CANCELLATIONDATE is null

print('Inserted service data from ASM_PB_SERVICE_FACT table')

print('Updateing Opne JC bucket in ASM_PB_SERVICE_FACT table')

update ASM_PB_SERVICE_FACT 
set OpenJC_buckets = CASE WHEN DATEDIFF(HH,CAST(DOCDATE AS DATE),GETDATE())<=24 THEN '<24 Hours'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 3 THEN '< 3 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 7 THEN '3-7 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 15 THEN  '7-15 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 30 THEN  '15-30 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 60 THEN  '30 - 60 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 90 THEN  '60 - 90 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 120 THEN  '90 - 120 Days'
WHEN DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) >= 120 THEN  '>= 120 Days' END
from ASM_PB_SERVICE_FACT
where  ISCLOSED=0 
--<3 ,<7,<15, <30,<60,<90,>90
print('Updated Opne JC bucket in ASM_PB_SERVICE_FACT table')

-------------------------------------------------------------------------------------------------

SELECT @TargetCount =  COUNT(1) FROM ASM_PB_SERVICE_FACT where IMPORTEDDATE > @MAXDATESTG
and SERVICE_RETAIL_TYPEIDENTIFIER=101;
        IF @SourceCount <> @TargetCount
        BEGIN
            SET @Status = 'WARNING';  
            SET @ErrorMessage = CONCAT('Record count mismatch. Source=', @SourceCount, ', Target=', @TargetCount);
        END
        ELSE
        BEGIN
            SET @Status = 'SUCCESS';
            SET @ErrorMessage = NULL;
        END
    END TRY
    BEGIN CATCH
        SET @Status = 'FAILURE';
        SET @ErrorMessage = ERROR_MESSAGE();
        THROW;  
    END CATCH
	
	SET @EndDate_utc = GETDATE();
	SET @EndDate_ist = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));
    SET @Duration_sec = DATEDIFF(SECOND, @StartDate_ist, @EndDate_ist);
	SET @Duration = CONVERT(VARCHAR(8), DATEADD(SECOND, @Duration_sec, 0), 108);
	
   
    EXEC [USP_Audit_Balance_Control_Logs] 
	     @SPID,
		@sp_name,
        @table_name,
        'Service',
        'PB',
        @StartDate_utc,
        @EndDate_utc,
		@StartDate_ist,
        @EndDate_ist,
        @Duration,  
        @SourceCount,
        @TargetCount,
        @Status,
        @ErrorMessage;
		
		PRINT 'Audit Execution completed ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));



print('droppping temporary tables')
drop table #3rdFS_To_1stPS_Data
drop table #DeletedLineID
drop table #JC_HEADER_PB
drop table #OpenJC_ManPowerData
End
GO