/****** Object:  StoredProcedure [dbo].[USP_Full_Load_ASM_PB_STOCK_REFRESH]    Script Date: 6/13/2025 5:18:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Alter PROC [dbo].[USP_ASM_PB_HKT_STOCK_REFRESH] AS
BEGIN
--***************************START****************************************************
/****************************HISTORY**************************************************/
/*------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|	CHANGE DESCRIPTION    */
/*--------------------------------------------------------------------------------------------------*/
/* 2025-07-18 	|	Lachmanna		        | Newly Added script for K+T        */
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
--Stock Fact:

declare @ASMFact_IMPORTEDDATE date;
set @ASMFact_IMPORTEDDATE = CAST((SELECT MAX(DATE) from ASM_PB_HK_STOCK_FACT)AS DATE);


DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_PB_HKT_STOCK_REFRESH';

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			@table_name1 VARCHAR(128) = 'ASM_PB_HK_STOCK_FACT', 
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT,   
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX); 

BEGIN TRY
INSERT INTO ASM_PB_HK_STOCK_FACT
SELECT DISTINCT
VS.COMPANYCODE As DEALERCODE,
VS.MODELCODE+LEFT(RIGHT(VS.COLOR,3),2) as SKU,
Cast(0 as int) as FK_DEALERCODE,
Cast(0 as int) as FK_SKU,
10004 As FK_TYPE_ID,
CAST(VS.EXECUTIONDATE as Date) AS DATE,
CM.COMPANYTYPE AS COMPANYTYPE,
Cast('' as varchar(255)) AS FK_STOCKSTATUS,
VS.VEHICLESTATUS as STOCKSTATUS,
COUNT(VS.CHASSISNO) AS [Stock Quantity],
COUNT(VS.CHASSISNO) as ACTUALQUANTITY,
getdate() as LASTUPDATEDDATETIME,
VS.IMPORTEDDATE,
VS.MODELCODE,
Cast(0 as int) As FK_MODEL,
NULL AS TEHSILID,
NULL AS SALESPERSON 
--INTO ASM_PB_STOCK_FACT
FROM
   VEHICLE_STOCK_DATA VS INNER JOIN COMPANY_MASTER CM ON (VS.COMPANYCODE=CM.CODE AND (CM.COMPANYTYPE = 2))-- AND CM.COMPANYSUBTYPE is null))
    INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
    from ASM_PB_HKT_PRODUCT_DIM) PM  
   ON  PM.Modelcode = VS.MODELCODE and PM.BRAND <>'TRIUMPH'and rnk = 1
WHERE --CAST(VS.EXECUTIONDATE AS DATE) BETWEEN '2025-06-09' AND  Cast(Getdate()-1 as date)
  Cast(VS.EXECUTIONDATE as date)>@ASMFact_IMPORTEDDATE
GROUP BY
  VS.COMPANYCODE,
  VS.MODELCODE+LEFT(RIGHT(VS.COLOR,3),2),
  CAST(VS.EXECUTIONDATE as Date),
  CM.COMPANYTYPE,
  VS.VEHICLESTATUS,
  VS.IMPORTEDDATE,
  VS.MODELCODE

--Product Master and Dealer Master FK update: ASM_PB_STOCK_FACT
update B set B.FK_SKU=C.PK_SKU from ASM_PB_HK_STOCK_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_PB_HK_STOCK_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_DIM C on (B.ModelCode=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].ASM_PB_HK_STOCK_FACT B INNER JOIN ASM_PB_HKT_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE);
--***********************************************************************************************************
-- Triunph data load 
EXEC [USP_ASM_PB_T_STOCK_REFRESH]

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
        'PB-KTM',
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