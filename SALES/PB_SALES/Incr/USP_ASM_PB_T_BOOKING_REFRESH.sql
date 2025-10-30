SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
alter PROC [dbo].[USP_ASM_PB_T_BOOKING_REFRESH] AS
BEGIN
--***************************START*****************************
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION				                        	*/
/*--------------------------------------------------------------------------------------------------*/
/*  2025-07-18 	|	Lachmanna		        | Newly Added script for K+T        */
/*  2025-10-07 	|	Lachmanna		        | added ABC code  and applied date casting        */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
declare @ASMDim_IMPORTEDDATE date;
set @ASMDim_IMPORTEDDATE = CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_PB_T_BOOKING_DIM)AS DATE);

declare @ASMFact_IMPORTEDDATE date;
set @ASMFact_IMPORTEDDATE = CAST((SELECT MAX(IMPORTEDDATE) FROM ASM_PB_T_BOOKING_FACT)AS DATE);


DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_PB_T_BOOKING_REFRESH';

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			@table_name1 VARCHAR(128) = 'ASM_PB_T_BOOKING_DIM', 
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT,   
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX); 

BEGIN TRY

INSERT INTO ASM_PB_T_BOOKING_DIM
SELECT DISTINCT
BOOKING_HEADER.HEADERID AS PK_BOOKINGHEADERID,
CAST(BOOKING_HEADER.DOCDATE AS DATE) AS BOOKINGDATE,
BOOKING_HEADER.STATUS AS [BOOKING STATUS],
'' AS BOOKINGDAYSBUCKET,
GETDATE() AS CREATEDDATETIME,
BOOKING_HEADER.IMPORTEDDATE,
BOOKING_HEADER.CDMS_BATCHNO
--INTO ASM_PB_T_BOOKING_DIM
FROM BOOKING_HEADER 
LEFT JOIN BOOKING_LINE BL ON (BOOKING_HEADER.HEADERID=BL.HEADERID)
JOIN ITEM_MASTER IM ON (IM.ItemId=BL.ItemID)
--newly added code for test<
INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND in('TRIUMPH') and rnk = 1
--newly added code for test>
INNER JOIN COMPANY_MASTER ON (BOOKING_HEADER.COMPANYID=COMPANY_MASTER.COMPANYID 
AND (COMPANY_MASTER.COMPANYTYPE = 2 ))-- AND COMPANY_MASTER.COMPANYSUBTYPE='Triumph' ))
WHERE 
--CAST(BOOKING_HEADER.DOCDATE AS DATE) between '2025-06-09' AND Cast(Getdate()-1 as date)  and 
--BOOKING_HEADER.STATUS = 'Open' AND 
BOOKING_HEADER.DOCTYPE=1000050
AND Cast(BOOKING_HEADER.IMPORTEDDATE as date)>=@ASMDim_IMPORTEDDATE


Delete from ASM_PB_T_BOOKING_DIM Where Cast(BOOKINGDATE as Date)>Cast(Getdate()-1 as date)

--Dedup Process
;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY PK_BOOKINGHEADERID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_T_BOOKING_DIM                  
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1;
--*************************************************************************
--2. Booking Fact:
INSERT INTO ASM_PB_T_BOOKING_FACT
SELECT
DISTINCT 
CM.CODE AS DEALERCODE,
IM.CODE+IV.CODE As SKU,
Cast(0 as int) AS FK_DealerCode,
Cast(0 as int) AS FK_SKU,
10006 AS FK_TYPE_ID,
CAST(BH.DOCDATE AS DATE) AS DATE,
BL.LINEID AS BookingLineID,
BL.HEADERID AS FK_BookingDocID,
CM.COMPANYTYPE AS COMPANYTYPE,
BH.BRANCHID,
COUNT(BH.HEADERID) AS ACTUALQUANTITY,
getdate() AS LASTUPDATEDDATETIME,
BH.IMPORTEDDATE,
IM.CODE As MODEL,
Cast(0 as int) As FK_MODEL,
Cast(0 As decimal(19,0)) As FLAG,
CAST (Null AS VARCHAR(10)) as TEHSILID,
REPLACE(REPLACE(REPLACE(REPLACE(UPPER(LSQ_User.Firstname),CHAR(160),''),' ',' |'),'| ',''),' |',' ') as SalesPerson,
ISNULL(COALESCE(EH.LEADTYPE,LSQ_PBASE.mx_Enquiry_Mode),'Not Available') as LeadType, 
CASE WHEN CAST(PE.MX_dEALER_ASSIGNMENT_DATE AS DATE)>='2024-12-01' THEN COALESCE(EH.LEADTYPE,PE2.mx_Qualified_First_Source) END  AS First_Source_Lead_Type,
ISNULL(PE2.mx_Qualified_Source_of_Enquiry, 'Not Available')   AS First_Mode_Source,
ISNULL(PE2.mx_Qualified_Sub_Source, 'Not Available') AS First_Mode_SubSource
FROM
BOOKING_HEADER BH 
INNER JOIN COMPANY_MASTER CM 
ON (BH.COMPANYID=CM.COMPANYID 
AND (CM.COMPANYTYPE =2 ))-- AND CM.COMPANYSUBTYPE='Triumph' ))
INNER JOIN BOOKING_LINE BL ON (BH.HEADERID=BL.HEADERID)
JOIN ITEM_MASTER IM ON (IM.ItemId=BL.ItemID)
INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
	from ASM_PB_HKT_PRODUCT_DIM) PM  
	ON  PM.Modelcode = IM.Code and PM.BRAND in('TRIUMPH') and rnk = 1
LEFT JOIN RETAIL_LINE RL ON (BL.LINEID=RL.BOOKINGDATALINEID)
LEFT JOIN ITEMVARMATRIX_MASTER IV ON (RL.VARMATRIXID=IV.ITEMVARMATRIXID)
LEFT JOIN BOOKING_HEADER_EXT BHE ON BH.HEADERID = BHE.HEADERID
LEFT JOIN ENQUIRY_LINE EL ON EL.LINEID = BL.ENQUIRYDATALINEID
LEFT JOIN ENQUIRY_HEADER EH ON EH.HEADERID = EL.DOCID
LEFT JOIN LSQ_ProspectActivity_ExtensionBase PAE ON (Cast(PAE.RelatedProspectId+','+PAE.ProspectActivityExtensionId as varchar(8000))=BHE.LMSBOOKINGID) and PAE.ActivityEvent=12002 and PAE.mx_Custom_48 IS NULL
LEFT JOIN LSQ_Prospect_Base LSQ_PBASE ON (LSQ_PBASE.ProspectID=PAE.RelatedProspectId)
LEFT JOIN LSQ_users LSQ_User  on LSQ_PBASE.OwnerId=LSQ_User.UserId
LEFT JOIN LSQ_Prospect_ExtensionBase PE ON (PE.ProspectID=LSQ_PBASE.ProspectID)
LEFT JOIN LSQ_Prospect_Extension2Base PE2 ON (PE2.ProspectID=LSQ_PBASE.ProspectID)
WHERE 
--CAST(BH.DOCDATE AS DATE) BETWEEN '2025-06-09' AND Cast(Getdate()-1 as date)  AND 
BH.DOCTYPE=1000050
AND CAST(BH.IMPORTEDDATE as date) >=@ASMFact_IMPORTEDDATE
GROUP BY
CM.CODE,
IM.CODE+IV.CODE,
CAST(BH.DOCDATE AS DATE),
BL.LINEID,
BL.HEADERID,
CM.COMPANYTYPE,
BH.BRANCHID,
BH.IMPORTEDDATE,
IM.CODE,
EH.LEADTYPE,
LSQ_PBASE.mx_Enquiry_Mode,
LSQ_User.Firstname,
LSQ_PBASE.MX_MODE_OF_ENQUIRY,
PE2.mx_Qualified_First_Source,
CAST(PE.MX_dEALER_ASSIGNMENT_DATE AS DATE),
PE2.mx_Qualified_Source_of_Enquiry,
PE2.mx_Qualified_Sub_Source


DELETE FROM ASM_PB_T_BOOKING_FACT WHERE DATE >Cast(Getdate()-1 as date)

--Dedup Process:

  ;WITH CTE AS                  
 (                  
  SELECT *,                  
   ROW_NUMBER()OVER(PARTITION BY FK_BookingDocID,BookingLineID ORDER BY IMPORTEDDATE DESC)RNK                   
  FROM ASM_PB_T_BOOKING_FACT                
 )                  
DELETE FROM CTE                  
 WHERE RNK<>1; 


--*****************************************************************************************************************

update B set B.FK_SKU=C.PK_SKU from ASM_PB_T_BOOKING_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_PB_T_BOOKING_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_DIM C on (B.MODEL=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].ASM_PB_T_BOOKING_FACT B INNER JOIN ASM_PB_HKT_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)

--******************************************************************************************************************


----------------------------------Audit Log Target
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
        'Sales',
        'PB-TRM',
        @StartDate_utc1,
        @EndDate_utc1,
		@StartDate_ist1,
        @EndDate_ist1,
        @Duration1,  
        '0',
        '0',
        @Status1,
        @ErrorMessage1;

END
GO
