/***************************************************HISTORY**********************************************************/
/*------------------------------------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|                 CHANGE DESCRIPTION		                            */
/*------------------------------------------------------------------------------------------------------------------*/
/*	2025-09-12	|	Rashi Pradhan       	|  First deployment for ASD BGO Report                                  */
/*	2025-09-18	|	Rashi Pradhan       	|  Updated filter condition to ITEM_GROUP_DETAIL_NEW in purchase table  */
/*  2025-09-18	|	Rashi Pradhan       	|  Added Audit logs in the script                                       */
/*------------------------------------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY******************************************************************/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_MC_SERVICE_ASD_BGO_REPORT_DIM] AS
BEGIN

DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_MC_SERVICE_ASD_BGO_REPORT_DIM';

----------------------------------------------------------------
    -- Audit Segment 1: ASM_MC_SERVICE_SPARE_PURCHASE_DIM
----------------------------------------------------------------  

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			@table_name1 VARCHAR(128) = 'ASM_MC_SERVICE_SPARE_PURCHASE_DIM', 
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT,   
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX);  

----------------------------------Audit Log Source

    BEGIN TRY
        SELECT @SourceCount1 = COUNT(DISTINCT PH.CDMSUNIQUEID)
		FROM SPARE_PURCHASE_HEADER PH
        LEFT JOIN [SPARE_PURCHASE_Line] PL ON (PL.CDMSDOCID = PH.CDMSUNIQUEID AND PL.IMPORTEDDATE = (SELECT MAX(PL1.IMPORTEDDATE) FROM [SPARE_PURCHASE_Line] PL1 WHERE PL1.ITEMID = PL.ITEMID AND PL.CDMSDOCID = PL1.CDMSDOCID))
        INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID = PH.COMPANYID AND CM.COMPANYTYPE IN (1,8))
        LEFT JOIN ITEM_MASTER IM ON PL.ITEMID = IM.ITEMID
        LEFT JOIN CONTACT_MASTER CC ON PH.CONTACTID = CC.CONTACTID AND CC.ID = (SELECT MAX(CC1.ID) FROM CONTACT_MASTER CC1 WHERE CC1.CONTACTID = CC.CONTACTID)
        LEFT JOIN ITEM_GROUP_DETAIL_NEW IMN on IM.ItemID=IMN.ITEMID AND IMN.ID = (SELECT MAX(IMN1.ID) FROM ITEM_GROUP_DETAIL_NEW IMN1 WHERE IMN.ITEMID = IMN1.ITEMID)
        WHERE IMN.ITEMGROUPTYPE = 'OILS'

-----------------------------LOAD SPARE PURCHASE DATA

PRINT ('Truncating table SPARE_PURCHASE_DIM')

TRUNCATE TABLE ASM_MC_SERVICE_SPARE_PURCHASE_DIM

PRINT ('Inserting data in SPARE_PURCHASE_DIM')

insert into ASM_MC_SERVICE_SPARE_PURCHASE_DIM (
	FK_DOCID,
	LINEID,
	FK_BRANCHID,
	DEALERCODE,
	ASD_DEALERCODE,
	FK_ITEMID,
	DOCNAME,
	DOCDATE,
	QTY,
	ITEMGROUPTYPE,
	SUPPLIER_CODE,
	DEALER_TYPE,
	IMPORTEDDATE,
	REFRESH_DATE
)

SELECT 
	PH.CDMSUNIQUEID AS FK_DOCID,
	PL.CDMSLINEID AS LINEID,
	PH.BRANCHID AS FK_BRANCHID,
	CM.CODE AS DEALERCODE,
	CM.CODE AS ASD_DEALERCODE,
	PL.ITEMID AS FK_ITEMID,
	PH.DOCNAME,
	CAST(PH.DOCDATE AS DATE) DOCDATE,
	PL.QTY,
	'OILS' AS ITEMGROUPTYPE,
	CC.CODE AS SUPPLIER_CODE,
	CASE WHEN TRY_CAST(CC.CODE AS INT) BETWEEN 10000 AND 14999 THEN 'DEALER'
	     WHEN TRY_CAST(CC.CODE AS INT) BETWEEN 15000 AND 16999 THEN 'DISTRIBUTOR'
	     ELSE 'LOCAL' 
	END AS DEALER_TYPE,
	PH.IMPORTEDDATE,
	GETDATE() AS REFRESH_DATE
FROM SPARE_PURCHASE_HEADER PH
LEFT JOIN [SPARE_PURCHASE_Line] PL ON (PL.CDMSDOCID = PH.CDMSUNIQUEID AND PL.IMPORTEDDATE = (SELECT MAX(PL1.IMPORTEDDATE) FROM [SPARE_PURCHASE_Line] PL1 WHERE PL1.ITEMID = PL.ITEMID AND PL.CDMSDOCID = PL1.CDMSDOCID))
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID = PH.COMPANYID AND CM.COMPANYTYPE IN (1,8))
LEFT JOIN ITEM_MASTER IM ON PL.ITEMID = IM.ITEMID
LEFT JOIN CONTACT_MASTER CC ON PH.CONTACTID = CC.CONTACTID AND CC.ID = (SELECT MAX(CC1.ID) FROM CONTACT_MASTER CC1 WHERE CC1.CONTACTID = CC.CONTACTID)
LEFT JOIN ITEM_GROUP_DETAIL_NEW IMN on IM.ItemID=IMN.ITEMID AND IMN.ID = (SELECT MAX(IMN1.ID) FROM ITEM_GROUP_DETAIL_NEW IMN1 WHERE IMN.ITEMID = IMN1.ITEMID)
WHERE IMN.ITEMGROUPTYPE = 'OILS'

-----------------------------UPDATE ASD DEALER MAPPING

PRINT('Updating ASD mappping')

SELECT * INTO #TEMP1 FROM
(SELECT DISTINCT ZF_ASC ASD_DEALERCODE,DEALER_CODE DEALERCODE
FROM SAP_ZSD_ASC_DETAIL
WHERE SER_STATUS = 'OPERATIONAL')T

UPDATE B
SET B.Dealercode=A.DEALERCODE
FROM ASM_MC_SERVICE_SPARE_PURCHASE_DIM B
INNER JOIN #TEMP1 A on B.ASD_Dealercode = A.ASD_DEALERCODE

PRINT('ASM_MC_SERVICE_SPARE_PURCHASE_DIM table Loaded')

----------------------------------Audit Log Target

SELECT @TargetCount1 = COUNT(DISTINCT FK_DOCID) FROM ASM_MC_SERVICE_SPARE_PURCHASE_DIM;
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

----------------------------------------------------------------
    -- Audit Segment 1: ASM_MC_SERVICE_PART_STOCK_ADJUSTMENT_DIM
---------------------------------------------------------------- 

DECLARE @StartDate_utc2 DATETIME = GETDATE(),
        @EndDate_utc2 DATETIME,
	    @StartDate_ist2 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
        @EndDate_ist2 DATETIME,
		@Duration_sec2 bigint,
		@Duration2 varchar(15),
		@table_name2 VARCHAR(128) = 'ASM_MC_SERVICE_PART_STOCK_ADJUSTMENT_DIM', 
        @SourceCount2 BIGINT,  
        @TargetCount2 BIGINT,   
        @Status2 VARCHAR(10),
        @ErrorMessage2 VARCHAR(MAX);  

----------------------------------Audit Log Source

    BEGIN TRY
        SELECT @SourceCount2 = COUNT(SAH.HEADERID)
		FROM CDMS_STOCK_ADJUSTMENT_HEADER SAH
        LEFT JOIN CDMS_STOCK_ADJUSTMENT_LINE SAL ON SAH.HEADERID = SAL.HEADERID
        INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID = SAH.COMPANYID AND CM.COMPANYTYPE IN (1,8))
        LEFT JOIN ITEM_MASTER IM ON SAL.ITEMID = IM.ITEMID
        LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=SAL.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
        WHERE IG.ITEMGROUPTYPE = 'OILS'
        AND SAL.QTY > 0
		

-----------------------------LOAD PART STOCK ADJUSTMENT DATA

PRINT ('Truncating table STOCK_ADJUSTMENT_DIM')

TRUNCATE TABLE ASM_MC_SERVICE_PART_STOCK_ADJUSTMENT_DIM 

PRINT ('Inserting data in STOCK_ADJUSTMENT_DIM')

INSERT INTO ASM_MC_SERVICE_PART_STOCK_ADJUSTMENT_DIM ( 
	FK_DOCID,
	LINEID,
	FK_BRANCHID,
	DEALERCODE, 
	ASD_DEALERCODE, 
	FK_ITEMID,
	DOCNAME,
	DOCDATE,  
	QTY,
	ITEMGROUPTYPE,
	IMPORTEDDATE,
	REFRESH_DATE
)

SELECT 
	SAH.HEADERID AS FK_DOCID,
	SAL.CDMSUNIQUEID AS LINEID,
	SAH.BRANCHID AS FK_BRANCHID, 
	CM.CODE AS DEALERCODE, 
	CM.CODE AS ASD_DEALERCODE,
	SAL.ITEMID AS FK_ITEMID,
	SAH.DOCNAME, 
	CAST(SAH.DOCDATE AS DATE) AS DOCDATE, 
	SAL.QTY,
	IG.ITEMGROUPTYPE, 
	SAH.IMPORTEDDATE,
	GETDATE() AS REFRESH_DATE
FROM CDMS_STOCK_ADJUSTMENT_HEADER SAH
LEFT JOIN CDMS_STOCK_ADJUSTMENT_LINE SAL ON SAH.HEADERID = SAL.HEADERID
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID = SAH.COMPANYID AND CM.COMPANYTYPE IN (1,8))
LEFT JOIN ITEM_MASTER IM ON SAL.ITEMID = IM.ITEMID
LEFT JOIN ITEM_GROUP_DETAIL_NEW IG ON IG.ITEMID=SAL.ITEMID AND IG.ID = (SELECT MAX(IG1.ID) FROM ITEM_GROUP_DETAIL_NEW IG1 WHERE IG.ITEMID = IG1.ITEMID)
WHERE IG.ITEMGROUPTYPE = 'OILS'
AND SAL.QTY > 0

-----------------------------UPDATE ASD DEALER MAPPING

PRINT('Updating ASD mappping')

SELECT * INTO #TEMP2 FROM
(SELECT DISTINCT ZF_ASC ASD_DEALERCODE,DEALER_CODE DEALERCODE
FROM SAP_ZSD_ASC_DETAIL
WHERE SER_STATUS = 'OPERATIONAL')T

UPDATE B
SET B.Dealercode=A.DEALERCODE
FROM ASM_MC_SERVICE_PART_STOCK_ADJUSTMENT_DIM B
INNER JOIN #TEMP2 A on B.ASD_Dealercode = A.ASD_DEALERCODE

PRINT('ASM_MC_SERVICE_PART_STOCK_ADJUSTMENT_DIM table Loaded')

----------------------------------Audit Log Target

SELECT @TargetCount2 = COUNT(DISTINCT FK_DOCID) FROM ASM_MC_SERVICE_PART_STOCK_ADJUSTMENT_DIM;
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


PRINT('Drop temp tables')

DROP TABLE #TEMP1
DROP TABLE #TEMP2



END
GO

