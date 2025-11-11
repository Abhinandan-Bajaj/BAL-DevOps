-- P3 INCLOAD Optimized Script
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_MC_SERVICE_P3_STG_FACT_INCLOAD] AS
BEGIN

/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			                            */
/*--------------------------------------------------------------------------------------------------*/
/*	2024-09-11 	|	Ashwini Ahire 		| ASM_MC_SERVICE_P3_STG                                     */
/*	2024-09-11 	|	Ashwini Ahire		| ASM_MC_SERVICE_P3_FACT                                    */                      
/*  2024-10-04  |   Ashwini Ahire       |Update Inc script                                          */    
/*  2024-12-18  |   Ashwini Ahire       |Added ELF Columns                                          */    
/*  2024-12-18  |   Ashwini Ahire       |Optimized INC load script and added ELF logic              */
/*	2025-02-17 	 |	Sarvesh Kulkarni		 | Added logic to populate Aggregare_fact table   */                                     
/*	2025-02-24 	 |	Dewang Makani   		 | Bug fix  
    2025-09-18 	|	Richa     		    | Excludecode table replaced by table DM_CodeInclusionExclusion_Master  and addition of ABC table          */                                     
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

declare @MAXDATESTGP3 DATETIME2(7);
set @MAXDATESTGP3= (SELECT MAX(IMPORTEDDATE) FROM ASM_MC_SERVICE_P3_STG);PRINT 'Script Execution Started at' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));PRINT 'Script Execution Started at' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));
PRINT 'Script Execution Started at' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));


----------------------Audit Script-----------------------------------------

DECLARE @StartDate_utc DATETIME = GETDATE(),
            @EndDate_utc DATETIME,
			@StartDate_ist DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist DATETIME,
            @Duration_sec bigint,
			@Duration varchar(15),
			 @table_name VARCHAR(128) = 'ASM_MC_SERVICE_P3_STG',
               @sp_name VARCHAR(128) = '[USP_ASM_MC_SERVICE_P3_STG_FACT_INCLOAD]',
            @SourceCount BIGINT,  
            @TargetCount BIGINT, 
			@SPID INT = @@SPID,			
            @Status VARCHAR(10),
            @ErrorMessage VARCHAR(MAX);  
 


 BEGIN TRY			
			
			SELECT @SourceCount = COUNT(1)
       FROM ASM_MC_SERVICE_STG P1STG
LEFT JOIN SERVICE_LINE_EXT SLE ON SLE.LINEID = P1STG.LINEID
INNER JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON (IBM.Pk_ibid = P1STG.FK_IBID AND IBM.ProductionDate >= '2020-01-01')
WHERE P1STG.QTYALLOCATED<>0 AND P1STG.QTYRETURNED<P1STG.QTYALLOCATED
AND P1STG.IMPORTEDDATE > @MAXDATESTGP3

-------------------SP logic----------------------------

PRINT('LOADING DATA FROM BASE TABLE')
INSERT INTO ASM_MC_SERVICE_P3_STG
(
Type
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
,Pretaxrevenue
,Itemgrouptype
,PaidFlag
,ServiceType
,DealerCode
,ASD_DealerCode
,Importeddate
,Vehicleinvoicedatetime
,Billeddatetime
,TOTALAMOUNT
,Delete_Flag
,Service_Retail_TypeIdentifier
,Usagereading
,Posttaxrevenue
,CANCELLATIONDATE
,DefectCode
,JobCardStatus
,DateOfFailure
,RefreshDate
)

SELECT 
P1STG.Type
,P1STG.FK_Contracttypeid
,P1STG.FK_PartContracttypeid
,P1STG.Lineid
,P1STG.FK_Docid
,P1STG.DOCNAME
,P1STG.Docdate
,P1STG.FK_Companyid
,P1STG.FK_Contactid
,P1STG.Isclosed
,P1STG.FK_Itemid
,P1STG.FK_Ibid
,P1STG.FK_Branchid
,P1STG.FK_Modelid
,P1STG.BU
,P1STG.COMPANYTYPE
,P1STG.TOTALTAX
,P1STG.Isrevisited
,P1STG.Isrepeated
,P1STG.Pretaxrevenue
,P1STG.Itemgrouptype
,P1STG.PaidFlag
,P1STG.ServiceType
,P1STG.DealerCode
,P1STG.ASD_DealerCode
,P1STG.Importeddate
,P1STG.Vehicleinvoicedatetime
,P1STG.Billeddatetime
,P1STG.TOTALAMOUNT
,P1STG.Delete_Flag
,P1STG.Service_Retail_TypeIdentifier
,P1STG.Usagereading
,P1STG.Posttaxrevenue
,P1STG.CANCELLATIONDATE
,SLE.Defectcode
,CASE
	WHEN P1STG.ISCLOSED = 0 AND (P1STG.READYFORBILLDATETIME IS NULL OR P1STG.READYFORBILLDATETIME IS NOT NULL) AND P1STG.BILLEDDATETIME IS NULL 
	THEN 'Open'
	WHEN P1STG.ISCLOSED = 1 AND P1STG.READYFORBILLDATETIME IS NOT NULL AND P1STG.BILLEDDATETIME IS NOT NULL 
	THEN 'Delivered/Closed'
END AS JobCardStatus
,P1STG.DateOfFailure
,getdate() AS RefreshDate

FROM ASM_MC_SERVICE_STG P1STG
LEFT JOIN SERVICE_LINE_EXT SLE ON SLE.LINEID = P1STG.LINEID
INNER JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON (IBM.Pk_ibid = P1STG.FK_IBID AND IBM.ProductionDate >= '2020-01-01')
WHERE P1STG.QTYALLOCATED<>0 AND P1STG.QTYRETURNED<P1STG.QTYALLOCATED
AND P1STG.IMPORTEDDATE > @MAXDATESTGP3
PRINT('STG TABLE LOADED')
PRINT 'STG TABLE LOADED at' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

-------------------Storing unique headerids in Temp. Object

PRINT('LOADING JC HEADERID FROM STG TABLE IN TEMP OBJ')
SELECT DISTINCT FK_DOCID
INTO #JC_HEADER_MC
FROM ASM_MC_SERVICE_P3_STG

---------------------Checking for missed JC
PRINT('CHECKING FOR MISSED JC IN BASE TABLES')

INSERT INTO ASM_MC_SERVICE_P3_STG
(
Type
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
,Pretaxrevenue
,Itemgrouptype
,PaidFlag
,ServiceType
,DealerCode
,ASD_DealerCode
,Importeddate
,Vehicleinvoicedatetime
,Billeddatetime
,TOTALAMOUNT
,Delete_Flag
,Service_Retail_TypeIdentifier
,Usagereading
,Posttaxrevenue
,CANCELLATIONDATE
,DefectCode
,JobCardStatus
,DateOfFailure
,RefreshDate
)

SELECT 
P1STG.Type
,P1STG.FK_Contracttypeid
,P1STG.FK_PartContracttypeid
,P1STG.Lineid
,P1STG.FK_Docid
,P1STG.DOCNAME
,P1STG.Docdate
,P1STG.FK_Companyid
,P1STG.FK_Contactid
,P1STG.Isclosed
,P1STG.FK_Itemid
,P1STG.FK_Ibid
,P1STG.FK_Branchid
,P1STG.FK_Modelid
,P1STG.BU
,P1STG.COMPANYTYPE
,P1STG.TOTALTAX
,P1STG.Isrevisited
,P1STG.Isrepeated
,P1STG.Pretaxrevenue
,P1STG.Itemgrouptype
,P1STG.PaidFlag
,P1STG.ServiceType
,P1STG.DealerCode
,P1STG.ASD_DealerCode
,P1STG.Importeddate
,P1STG.Vehicleinvoicedatetime
,P1STG.Billeddatetime
,P1STG.TOTALAMOUNT
,P1STG.Delete_Flag
,P1STG.Service_Retail_TypeIdentifier
,P1STG.Usagereading
,P1STG.Posttaxrevenue
,P1STG.CANCELLATIONDATE
,SLE.Defectcode
,CASE
	WHEN P1STG.ISCLOSED = 0 AND (P1STG.READYFORBILLDATETIME IS NULL OR P1STG.READYFORBILLDATETIME IS NOT NULL) AND P1STG.BILLEDDATETIME IS NULL 
	THEN 'Open'
	WHEN P1STG.ISCLOSED = 1 AND P1STG.READYFORBILLDATETIME IS NOT NULL AND P1STG.BILLEDDATETIME IS NOT NULL 
	THEN 'Delivered/Closed'
END AS JobCardStatus
,P1STG.DateOfFailure
,getdate() AS RefreshDate

FROM ASM_MC_SERVICE_STG P1STG
LEFT JOIN #JC_HEADER_MC tempSH on P1STG.FK_Docid = tempSH.FK_DOCID
LEFT JOIN SERVICE_LINE_EXT SLE ON SLE.LINEID = P1STG.LINEID
INNER JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON (IBM.Pk_ibid = P1STG.FK_IBID AND IBM.ProductionDate >= '2020-01-01')
WHERE P1STG.QTYALLOCATED<>0 AND P1STG.QTYRETURNED<P1STG.QTYALLOCATED
AND CAST(P1STG.DOCDATE AS DATE) >= CAST(DATEADD(D,-90,GETDATE()) AS DATE) --AND P1STG.FK_Docid NOT IN (SELECT DISTINCT FK_DOCID FROM #JC_HEADER_MC)
AND tempSH.FK_DOCID is null

PRINT('MISSED JC DATA LOADED')
PRINT 'MISSED JC DATA LOADED' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

---------------------------------------
PRINT('DELETING DATA FOR DOCDATE GREATER THAN D-1')

Delete from ASM_MC_SERVICE_P3_STG Where DOCDATE>Cast(DATEADD(mi,30,(DATEADD(hh,5,getdate()))) - 1 as date);
PRINT 'DELETING DATA FOR DOCDATE GREATER THAN D-1' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

---------------------------------------DEDUP

;WITH CTE AS                  
(                  
  SELECT *,                  
   DENSE_RANK()OVER(PARTITION BY FK_DOCID ORDER BY IMPORTEDDATE DESC)RNK                  
  FROM ASM_MC_SERVICE_P3_STG              
)          
DELETE FROM CTE                  
WHERE RNK<>1;
PRINT 'DEDUP completed' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

------------------------------UPDATE DELETED LINEITEMS
PRINT('UPDATING DELETED LINE ITEMS')
SELECT DISTINCT SLD.LineID
INTO #DeletedLineID
FROM SERVICE_LINE_DELETED SLD
JOIN ASM_MC_SERVICE_P3_STG ASF ON ASF.LINEID=SLD.LINEID

UPDATE ASF
SET ASF.Delete_Flag=1
FROM ASM_MC_SERVICE_P3_STG ASF 
JOIN #DeletedLineID DLI ON DLI.LINEID=ASF.LINEID
PRINT('DELETED LINE ITEMS UPDATED')
PRINT 'DELETED LINE ITEMS UPDATED' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));
Delete from ASM_MC_SERVICE_P3_STG where Delete_Flag=1;
PRINT('DELETED flagged LINE ITEMS Deleted')


------------------------------UPDATE Cancellation date
print('Updating Cancellation date in ASM_MC_SERVICE_P3_STG table')

Update ASF 
SET ASF.CANCELLATIONDATE=sh.CANCELLATIONDATE
FROM ASM_MC_SERVICE_P3_STG ASF
LEFT JOIN SERVICE_HEADER SH ON SH.HEADERID = asf.FK_Docid
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=SH.COMPANYID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)
AND CM.COMPANYTYPE IN (1,8))
WHERE cast(SH.IMPORTEDDATE as date) > DATEADD(Day,-2,@MAXDATESTGP3)
AND SH.CANCELLATIONDATE IS NOT NULL
print('Cancellation date updated in ASM_MC_SERVICE_P3_STG table');;

Delete from ASM_MC_SERVICE_P3_STG where CANCELLATIONDATE is not null;
PRINT 'DELETED Canceled rows' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));


----------------------------UPDATE ASD DEALERCODE MAPPING
PRINT('UPDATING DEALER ASD MAPPING')

SELECT * INTO #ServiceDealerMapping FROM
(SELECT DISTINCT ZF_ASC ASD_DEALERCODE,DEALER_CODE DEALERCODE
FROM SAP_ZSD_ASC_DETAIL
WHERE SER_STATUS = 'OPERATIONAL')T

UPDATE B
SET B.Dealercode=A.DEALERCODE
FROM ASM_MC_SERVICE_P3_STG B
INNER JOIN #ServiceDealerMapping A ON B.ASD_DealerCode=A.ASD_DEALERCODE
WHERE B.DEALERCODE>'0000020000';

PRINT('DEALER ASD MAPPING UPDATED');
PRINT 'DEALER ASD MAPPING UPDATED' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

-----------------------------UPDATE FOR PART REPAIR TYPE---------------------------------------
PRINT('UPDATING PART REPAIRTYPE')

UPDATE STG
SET PartRepairType = 
                  CASE 
			            WHEN EC.Code is not null THEN 'Others'
                        WHEN STG.FK_PartContractTypeID = 1 THEN 'Warranty'
                        WHEN STG.FK_PartContractTypeID = 8 THEN 'PDI'
                        WHEN STG.FK_PartContractTypeID = 170 THEN '5 Year Warranty'
                        WHEN STG.FK_PartContractTypeID = 198 THEN 'Any Time Warranty'
                        WHEN STG.FK_PartContractTypeID = 3 THEN 'Special Sanction'
                        WHEN STG.FK_PartContractTypeID IN (2,4,5,7,9,13,37,39,40,41,42,43,44,45,166,167,171,192,193) THEN 'Paid'
						ELSE 'Others'
                    END 
FROM ASM_MC_SERVICE_P3_STG STG
INNER JOIN ITEM_MASTER IM ON im.itemid = STG.fk_itemid
LEFT JOIN DM_CodeInclusionExclusion_Master EC ON EC.code = IM.code AND EC.TypeFlag = 'Itemcode_001'
WHERE STG.Type = 'Part'
  AND STG.ItemGroupType = 'BAL Parts'
  AND STG.PartRepairType IS NULL;

PRINT('PART REPAIRTYPE UPDATED');
PRINT 'PART REPAIRTYPE UPDATED' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

-----------------------------UPDATE FOR PART REPAIR TYPE which are "null" as "others" ------------------------
UPDATE STG
SET PartRepairType = 'Others'
FROM ASM_MC_SERVICE_P3_STG STG
WHERE PartRepairType IS NULL

PRINT('PART REPAIRTYPE UPDATED as OTHERS for nulls as well')
PRINT 'PART REPAIRTYPE UPDATED as OTHERS' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

-----------------------------UPDATE FOR INVOICEDATE AND PRODUCTIONDATE------------------------------

PRINT('UPDATING INVOICEDATE AND PRODUCTION DATES')

UPDATE STG
SET InvoiceDate = IBM.InvoiceDate, ProductionDate = IBM.PRODUCTIONDATE
FROM ASM_MC_SERVICE_P3_STG STG
INNER JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON IBM.PK_Ibid = STG.FK_IBID
WHERE STG.InvoiceDate IS NULL OR STG.ProductionDate IS NULL

PRINT('INVOICEDATE AND PRODUCTION DATES UPDATED');
PRINT 'INVOICEDATE AND PRODUCTION DATES UPDATED' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

------------------------------------------------------------------------------------------
--MC FACT Repeat Logic for Parts--

;;WITH PartitionedData AS (
   SELECT 
       STG.FK_Ibid,
       STG.FK_Itemid,
       STG.PartRepairType,
       STG.FK_docid,
       ROW_NUMBER() OVER (PARTITION BY STG.FK_Ibid, STG.FK_Itemid, STG.PartRepairType ORDER BY STG.FK_docid) AS RowNum
   FROM 
       ASM_MC_SERVICE_P3_STG STG
LEFT JOIN ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM ON IBM.PK_Ibid = STG.FK_Ibid
WHERE DATEDIFF(YEAR, STG.DOCDATE, IBM.ProductionDate) <= 5 AND STG.TYPE = 'Part'
)
 
UPDATE OriginalData
SET Part_Repeat_Count = CASE
   WHEN PartitionedData.RowNum = 1 THEN 0
   ELSE 1
END
FROM 
   ASM_MC_SERVICE_P3_STG AS OriginalData
JOIN 
   PartitionedData
ON 
   OriginalData.FK_docid = PartitionedData.FK_docid and
OriginalData.FK_ibid = PartitionedData.FK_ibid and
OriginalData.FK_itemid = PartitionedData.FK_itemid;
PRINT 'Repeat Part UPDATED' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

---------------------INSERT SERVICE DATA IN FACT TABLE
/*
PRINT('INSERTING DATA INTO FACT TABLE')
DELETE FROM ASM_MC_SERVICE_P3_FACT WHERE SERVICE_RETAIL_TYPEIDENTIFIER=101

INSERT INTO ASM_MC_SERVICE_P3_FACT(
Type,
FK_Contracttypeid,
FK_PartContracttypeid,
Lineid,
FK_Docid,
DOCNAME,
Docdate,
FK_Companyid,
FK_Contactid,
FK_Itemid,
FK_Ibid,
FK_Branchid,
FK_Modelid,
COMPANYTYPE,
Isrepeated,
Pretaxrevenue,
Itemgrouptype,
ServiceType,
DealerCode,
ASD_DealerCode,
Importeddate,
Billeddatetime,
Service_Retail_TypeIdentifier,
Usagereading,
PartRepairType,
DefectCode,
JobCardStatus,
DateOfFailure,
Posttaxrevenue,
Refresh_Date,
Part_Repeat_Count,
InvoiceDate,
ProductionDate
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
FK_Itemid,
FK_Ibid,
FK_Branchid,
FK_Modelid,
COMPANYTYPE,
Isrepeated,
Pretaxrevenue,
Itemgrouptype,
ServiceType,
DealerCode,
ASD_DealerCode,
Importeddate,
Billeddatetime,
Service_Retail_TypeIdentifier,
Usagereading,
PartRepairType,
DefectCode,
JobCardStatus,
DateOfFailure,
Posttaxrevenue,
GETDATE() AS Refresh_Date,
Part_Repeat_Count,
InvoiceDate,
ProductionDate

FROM ASM_MC_SERVICE_P3_STG ARS
WHERE ARS.DELETE_FLAG<>1
and ARS.CANCELLATIONDATE is null

print('Service Data inserted into fact table');
*/
print('Dropping temporary tables');

Drop table #JC_HEADER_MC
Drop table #DeletedLineID 
print('Temporary tables dropped');


SELECT @TargetCount =  COUNT(1) FROM ASM_MC_SERVICE_P3_STG where IMPORTEDDATE > @MAXDATESTGP3;
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
        'MC',
        @StartDate_utc,
        @EndDate_utc,
		@StartDate_ist,
        @EndDate_ist,
        @Duration,  
        @SourceCount,
        @TargetCount,
        @Status,
        @ErrorMessage;
	

END 
GO