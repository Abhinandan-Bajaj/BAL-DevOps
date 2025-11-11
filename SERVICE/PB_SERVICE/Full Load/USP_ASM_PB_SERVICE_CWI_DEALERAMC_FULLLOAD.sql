SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_PB_SERVICE_CWI_DEALERAMC_FULLLOAD] AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY	    | CHANGE DESCRIPTION				    */
/*--------------------------------------------------------------------------------------------------*/
/*	2025-11-10 	|	Rashi Pradhan		    | New deployment                                */
/*	2025-11-10 	|	Rashi Pradhan		    | Added audit log and NOBLOCK for branchmaster and company master  */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

PRINT ('Truncating ASM_PB_CWI_STG')

TRUNCATE TABLE [dbo].[ASM_PB_CWI_STG]

PRINT 'Audit Execution started ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_PB_SERVICE_CWI_DEALERAMC_FULLLOAD';

------------Audit Log CWI - KTM
		
DECLARE @StartDate_utc DATETIME = GETDATE(),
        @EndDate_utc DATETIME,
	  @StartDate_ist DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
        @EndDate_ist DATETIME,
        @Duration_sec bigint,
	  @Duration varchar(15),
	  @table_name VARCHAR(128) = 'ASM_PB_CWI_STG - KTM',
        @SourceCount BIGINT,  
        @TargetCount BIGINT, 			
        @Status VARCHAR(10),
        @ErrorMessage VARCHAR(MAX),

		@StartDate_utc1 DATETIME,
		@StartDate_ist1 DATETIME,
        @EndDate_utc1 DATETIME,
        @EndDate_ist1 DATETIME,
        @Duration_sec1 bigint,
	  @Duration1 varchar(15),
	  @table_name1 VARCHAR(128) = 'ASM_PB_CWI_STG - TRM',
        @SourceCount1 BIGINT,  
        @TargetCount1 BIGINT, 			
        @Status1 VARCHAR(10),
        @ErrorMessage1 VARCHAR(MAX)



---------------Counting source records
 BEGIN TRY		

--KTM CWI Data			
SELECT @SourceCount = COUNT(1) FROM 
(select DISTINCT CWI.PolicyNo,CWI.Dealercode AS DEALERCODE, CWI.Dealercode AS Branchcode
FROM EXT_CWI_REPORT_KTM_DATA CWI
LEFT JOIN INSTALL_BASE_MASTER IBM ON (IBM.NAME=TRIM(REPLACE(CWI.[CHASSISNO.],':','')) AND IBM.IMPORTEDDATE = (SELECT MAX(IBM1.IMPORTEDDATE) FROM INSTALL_BASE_MASTER IBM1 WHERE IBM1.NAME = IBM.NAME)))B
LEFT JOIN COMPANY_MASTER CM WITH (NOLOCK) ON (CM.CODE = B.Dealercode AND CM.COMPANYTYPE IN (2))
LEFT JOIN BRANCH_MASTER BM WITH (NOLOCK) ON BM.CODE = B.Branchcode


        
---------------Insert CWI data for KTM 
PRINT ('Inserting KTM CWI data to ASM_PB_CWI_STG')

INSERT INTO ASM_PB_CWI_STG

SELECT B.*
,CM.COMPANYID AS FK_Companyid
,BM.BRANCHID AS FK_Branchid
FROM
(SELECT DISTINCT CWI.PROGRAM AS Type
,CWI.PolicyNo AS FK_Docid
--,CWI.InvoiceNo AS DOCNAME
,Case when CWI.EnrollmentDate like '%/%/%' then try_CONVERT(DATE, CWI.EnrollmentDate, 103) END AS Docdate
--,CM.COMPANYID AS FK_Companyid
,IBM.IBID AS [FK_Ibid]
--,BM.Branchid AS FK_Branchid
,IBM.ITEMID AS FK_Modelid
,CASE WHEN CWI.PROGRAM = 'Comprehensive AMC' OR CWI.PROGRAM = 'Periodic Service AMC' THEN 500 ELSE CWI.TaxableAmount END AS Pretaxrevenue
,CASE WHEN CWI.PROGRAM = 'Comprehensive AMC' OR CWI.PROGRAM = 'Periodic Service AMC' THEN 590 ELSE CWI.AmountPaid END AS Posttaxrevenue
,CASE WHEN CWI.Dealercode LIKE '[0-9][0-9][0-9][0-9][0-9]' THEN CONCAT('00000',CWI.Dealercode)
      ELSE CONCAT('00000',RIGHT(CWI.Dealercode,5)) END AS Dealercode
,CASE WHEN CWI.Dealercode LIKE '[0-9][0-9][0-9][0-9][0-9]' THEN CONCAT('00000',CWI.Dealercode)
      ELSE CWI.Dealercode END AS Branchcode
,TRIM(REPLACE(CWI.[CHASSISNO.],':','')) AS Chassis_CWI
,Case when CWI.STARTDATE like '%/%/%' then try_CONVERT(DATE, CWI.STARTDATE, 103) END AS Vehicleinvoicedatetime
--,case when CWI.invoicedate like '%/%/%' then try_CONVERT(DATE, CWI.invoicedate, 103) -- ODBC canonical
--      when CWI.invoicedate like '%-%-%' then cast(CWI.invoicedate as date) END AS Billeddatetime
,Case when CWI.ENDDATE like '%/%/%' then try_CONVERT(DATE, CWI.ENDDATE, 103)  END AS ExpiryDate
,2 as COMPANYTYPE
,103 AS Service_Retail_TypeIdentifier
,GETDATE() AS Refresh_Date
FROM EXT_CWI_REPORT_KTM_DATA CWI
LEFT JOIN INSTALL_BASE_MASTER IBM ON (IBM.NAME=TRIM(REPLACE(CWI.[CHASSISNO.],':','')) AND IBM.IMPORTEDDATE = (SELECT MAX(IBM1.IMPORTEDDATE) FROM INSTALL_BASE_MASTER IBM1 WHERE IBM1.NAME = IBM.NAME))
)B
LEFT JOIN COMPANY_MASTER CM WITH (NOLOCK) ON (CM.CODE = B.Dealercode AND CM.COMPANYTYPE IN (2))
LEFT JOIN BRANCH_MASTER BM WITH (NOLOCK) ON BM.CODE = B.Branchcode

------------Audit Log CWI - TRM

set @StartDate_utc1 = GETDATE();
set @StartDate_ist1 = (DATEADD(mi,30,(DATEADD(hh,5,getdate()))));

---------------Counting source records
 BEGIN TRY		

--TRM CWI Data
SELECT @SourceCount = COUNT(1) FROM 
(select DISTINCT CWI.PolicyNo,CWI.Dealercode AS DEALERCODE, CWI.Dealercode AS Branchcode
FROM EXT_CWI_REPORT_KTM_DATA CWI
LEFT JOIN INSTALL_BASE_MASTER IBM ON (IBM.NAME=TRIM(REPLACE(CWI.[CHASSISNO.],':','')) AND IBM.IMPORTEDDATE = (SELECT MAX(IBM1.IMPORTEDDATE) FROM INSTALL_BASE_MASTER IBM1 WHERE IBM1.NAME = IBM.NAME)))B
LEFT JOIN COMPANY_MASTER CM WITH (NOLOCK) ON (CM.CODE = B.Dealercode AND CM.COMPANYTYPE IN (2))
LEFT JOIN BRANCH_MASTER BM WITH (NOLOCK) ON BM.CODE = B.Branchcode

---------------Insert CWI data for TRM
PRINT ('Inserting TRM CWI data to ASM_PB_CWI_STG')

INSERT INTO ASM_PB_CWI_STG

SELECT B.*
,CM.COMPANYID AS FK_Companyid
,BM.BRANCHID AS FK_Branchid
--INTO ASM_MC_CWI_STG
FROM
(SELECT DISTINCT CWI.PROGRAM AS Type
,CWI.PolicyNo AS FK_Docid
--,CWI.InvoiceNo AS DOCNAME
,Case when CWI.EnrollmentDate like '%/%/%' then try_CONVERT(DATE, CWI.EnrollmentDate, 103) END AS Docdate
--,CM.COMPANYID AS FK_Companyid
,IBM.IBID AS [FK_Ibid]
--,BM.Branchid AS FK_Branchid
,IBM.ITEMID AS FK_Modelid
,CASE WHEN CWI.PROGRAM = 'Comprehensive AMC' OR CWI.PROGRAM = 'Periodic Service AMC' THEN 500 ELSE CWI.TaxableAmount END AS Pretaxrevenue
,CASE WHEN CWI.PROGRAM = 'Comprehensive AMC' OR CWI.PROGRAM = 'Periodic Service AMC' THEN 590 ELSE CWI.AmountPaid END AS Posttaxrevenue
,CASE WHEN CWI.Dealercode LIKE '[0-9][0-9][0-9][0-9][0-9]' THEN CONCAT('00000',CWI.Dealercode)
      ELSE CONCAT('00000',RIGHT(CWI.Dealercode,5)) END AS Dealercode
,CASE WHEN CWI.Dealercode LIKE '[0-9][0-9][0-9][0-9][0-9]' THEN CONCAT('00000',CWI.Dealercode)
      ELSE CWI.Dealercode END AS Branchcode
,TRIM(REPLACE(CWI.[CHASSISNO.],':','')) AS Chassis_CWI
,Case when CWI.STARTDATE like '%/%/%' then try_CONVERT(DATE, CWI.STARTDATE, 103) END AS Vehicleinvoicedatetime
--,case when CWI.invoicedate like '%/%/%' then try_CONVERT(DATE, CWI.invoicedate, 103) -- ODBC canonical
--      when CWI.invoicedate like '%-%-%' then cast(CWI.invoicedate as date) END AS Billeddatetime
,Case when CWI.ENDDATE like '%/%/%' then try_CONVERT(DATE, CWI.ENDDATE, 103) END AS ExpiryDate
,2 as COMPANYTYPE
,104 AS Service_Retail_TypeIdentifier
,GETDATE() AS Refresh_Date
FROM EXT_CWI_REPORT_TRM_DATA CWI
LEFT JOIN INSTALL_BASE_MASTER IBM ON (IBM.NAME=TRIM(REPLACE(CWI.[CHASSISNO.],':','')) AND IBM.IMPORTEDDATE = (SELECT MAX(IBM1.IMPORTEDDATE) FROM INSTALL_BASE_MASTER IBM1 WHERE IBM1.NAME = IBM.NAME))
)B
LEFT JOIN COMPANY_MASTER CM WITH (NOLOCK) ON (CM.CODE = B.Dealercode AND CM.COMPANYTYPE IN (2))
LEFT JOIN BRANCH_MASTER BM WITH (NOLOCK) ON BM.CODE = B.Branchcode


-------------------------------------INSERT CWI DATA INTO FACT TABLE
PRINT ('Deleting data for 103, 104 in Fact')

DELETE FROM ASM_PB_SERVICE_FACT WHERE SERVICE_RETAIL_TYPEIDENTIFIER IN (103,104)

PRINT ('Inserting CWI data to fact')

INSERT INTO ASM_PB_SERVICE_FACT(Type,
FK_Docid,
Docdate,
FK_Companyid,
FK_Ibid,
FK_Modelid,
FK_Branchid,
Pretaxrevenue,
Posttaxrevenue,
Dealercode,
Chassis_CWI,
Vehicleinvoicedatetime,
ExpiryDate,
CompanyType,
Service_Retail_TypeIdentifier,
Refresh_Date)

SELECT 
Type,
FK_Docid,
Docdate,
FK_Companyid,
FK_Ibid,
FK_Modelid,
FK_Branchid,
Pretaxrevenue,
Posttaxrevenue,
Dealercode,
Chassis_CWI,
Vehicleinvoicedatetime,
ExpiryDate,
CompanyType,
Service_Retail_TypeIdentifier,
GETDATE() AS Refresh_Date
FROM ASM_PB_CWI_STG

---------------Counting target records

SELECT @TargetCount =  COUNT(1) FROM ASM_PB_SERVICE_FACT 
where SERVICE_RETAIL_TYPEIDENTIFIER IN(103);

SELECT @TargetCount1 =  COUNT(1) FROM ASM_PB_SERVICE_FACT 
where SERVICE_RETAIL_TYPEIDENTIFIER IN(104);

---------------Audit Log target CWI - KTM

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

---------------Audit Log target CWI - TRM

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
        'PB',
        @StartDate_utc1,
        @EndDate_utc1,
	  @StartDate_ist1,
        @EndDate_ist1,
        @Duration1,  
        @SourceCount1,
        @TargetCount1,
        @Status1,
        @ErrorMessage1;
		
		PRINT 'Audit Execution completed ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

-------------------------------------------------------
/*
--Loading Dealer AMC Data
PRINT ('Truncating ASM_PB_DEALER_AMC_STG')

TRUNCATE TABLE ASM_PB_DEALER_AMC_STG

INSERT INTO ASM_PB_DEALER_AMC_STG
SELECT DISTINCT 'DEALER AMC' as Type,
DOCNAME,
CAST(DOCDATE AS DATE) DOCDATE,
CAST(DOCDATE AS DATE) BILLEDDATETIME,
ACS.DEALERCODE AS DEALERCODE,
ACS.TOTALAMOUNT AS POSTTAXREVENUE,
(ACS.RATE - ACS.TRADEDISCOUNT) AS PRETAXREVENUE,
IBM.IBID AS FK_IBID,
BM.BRANCHID AS FK_BRANCHID,
IM.ITEMID AS FK_MODELID,
1 AS COMPANYTYPE,
106 as Service_Retail_TypeIdentifier
FROM AMC_CONTRACT_SALE ACS
JOIN BRANCH_MASTER BM ON BM.CODE = ACS.BRANCHCODE
LEFT JOIN ITEM_MASTER IM ON IM.CODE = ACS.MODELCODE
LEFT JOIN INSTALL_BASE_MASTER IBM ON TRIM(IBM.NAME) = TRIM(ACS.CHASSISNO)
LEFT JOIN COMPANY_MASTER CM ON (CM.CODE = ACS.Dealercode AND CM.COMPANYTYPE IN (2))
WHERE CAST(DOCDATE AS DATE) >= '2022-04-01'


------------------------------------------------------INSERT INTO FACT TABLE
PRINT ('Deleting data for 106 in Fact')

DELETE FROM ASM_PB_SERVICE_FACT WHERE SERVICE_RETAIL_TYPEIDENTIFIER=106

PRINT ('Inserting dealer AMC data to fact')

INSERT INTO ASM_PB_SERVICE_FACT(Type,
DOCNAME,
Docdate,
FK_Ibid,
FK_Branchid,
FK_Modelid,
COMPANYTYPE,
Pretaxrevenue,
DealerCode,
Billeddatetime,
Service_Retail_TypeIdentifier,
Posttaxrevenue,
Refresh_Date)

SELECT Type,
DOCNAME,
Docdate,
FK_Ibid,
FK_Branchid,
FK_Modelid,
COMPANYTYPE,
Pretaxrevenue,
DealerCode,
Billeddatetime,
Service_Retail_TypeIdentifier,
Posttaxrevenue,
GETDATE() AS Refresh_Date
FROM  ASM_PB_DEALER_AMC_STG
*/

END
GO