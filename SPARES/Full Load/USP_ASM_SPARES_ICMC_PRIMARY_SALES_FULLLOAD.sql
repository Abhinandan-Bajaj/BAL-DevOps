SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_SPARES_ICMC_PRIMARY_SALES_FULLLOAD]
AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			                            */
/*--------------------------------------------------------------------------------------------------*/
/*	2025-01-03 	|	 	Aswani	  |        Initiation of the SP                                     */
/*  2025-02-25  |       Aswani    |        Included the partial orders logic                        */
/*  2025-03-19  |       Aswani    |        Included the dynamic fiscal year logic                   */
/*	2025-03-26	|		Aswani	  |		   updated the KPI_MATERIAL_COUNT logic						*/
/*	2025-06-30	|		Aswani	  |		   Updated the BU column from company_master to             */ 
/*										   SAP_CUSTOMER_MASTER_KNA1									*/
/*  2025-10-30  |       Rashi     |        updated the 3rd and 7th fill rate logic for IC and MC
                                           updated invoice_division to order_division, billing_type_analytics to order_type in KPI_MATERIAL_FLAG and audit log */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

PRINT('LOADING DATA FROM Source TABLE')
TRUNCATE TABLE [dbo].[ASM_ICMC_SPARES_PRIMARY_SALES_STG];

--------------------------------------------------*GETTING FISCAL YEAR*--------------------------------------------------------------
DECLARE @FY date
DECLARE @FISCAL_YEAR DATE
 
set @FY = GETDATE()
 
		SELECT @FISCAL_YEAR= CAST(FISCAL_YEAR AS DATE) 
		FROM (SELECT DISTINCT cast(cast(YEAR(@FY)-
        (case 
            when MONTH(@FY) between 1 and 3 then 3
            else 2
        end) as varchar)+'0401' as date) AS FISCAL_YEAR FROM VW_SPARES_ICMC_ODI_DATA) AS DERIVED_TABLE;

--------------AUdit table --------------------------
PRINT 'Audit Execution Started ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));

DECLARE @SPID INT = @@SPID,
        @sp_name VARCHAR(128) = 'USP_ASM_SPARES_ICMC_PRIMARY_SALES_FULLLOAD';
		

DECLARE @StartDate_utc DATETIME = GETDATE(),
            @EndDate_utc DATETIME,
			@StartDate_ist DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist DATETIME,
            @Duration_sec bigint,
			@Duration varchar(15),
			 @table_name VARCHAR(128) = 'ASM_ICMC_SPARES_PRIMARY_SALES_STG and Fact',
            @SourceCount BIGINT,  
            @TargetCount BIGINT, 			
            @Status VARCHAR(10),
            @ErrorMessage VARCHAR(MAX)



---------------------------------------------------*PRIMARY_SCREEN_ORDER_DATA_LOAD*---------------------------------------------------
;WITH order_with_min_date AS (
    SELECT 
        O.order_no,
        O.order_date,
        O.order_material,
        O.order_quantity,
        O.actual_billed_qty,
        O.delivery_number,
        O.delivery_date,
		O.billing_date,
        MD.min_delivery_date,
		O.BU
    FROM (
        SELECT DISTINCT
            O.order_date,
            O.order_no,
            O.order_material,
            O.order_quantity,
            O.actual_billed_qty,
            O.delivery_number,
            O.delivery_date,
			O.billing_date,
			CASE WHEN CM.KATR6='2WH' THEN '2W'
			 WHEN CM.KATR6='3WH' THEN '3W'
		ELSE NULL END AS BU
        FROM dbo.VW_SPARES_ICMC_ODI_DATA O
        LEFT JOIN SAP_CUSTOMER_MASTER_KNA1 CM 
            ON O.sold_to_dealer_or_distributor = CM.KUNNR 
        WHERE O.sales_organization = 'ZDOM'
          AND O.invoice_division = 'B1' 
          AND O.distribution_channel IN (10, 20)  
          AND O.billing_type_analytics IN ('ZSTD', 'ZSCH', 'ZVOR', 'ZPSD', 'ZPVR') 
          AND O.ORDER_PLANT IN ('WA02', 'PT02')
          AND (O.GROSS_INVOICE_AMOUNT > 0 OR O.GROSS_DELIVERY_AMOUNT > 0)
          AND O.order_rejection_reason IN ('', 'A1')
          AND CM.KATR6 IN ('2WH', '3WH')
          -- AND O.sold_to_dealer_or_distributor = '0000016030' 
          -- AND O.ORDER_DATE BETWEEN '2025-03-01' AND '2025-03-31'
    ) O
    INNER JOIN (
        SELECT 
            order_no,
            MIN(delivery_date) AS min_delivery_date
        FROM dbo.VW_SPARES_ICMC_ODI_DATA
        WHERE invoice_division = 'B1'
          AND distribution_channel IN (10, 20)  
          AND billing_type_analytics IN ('ZSTD', 'ZSCH', 'ZVOR', 'ZPSD', 'ZPVR')
          AND ORDER_PLANT IN ('WA02', 'PT02')
          AND (GROSS_INVOICE_AMOUNT > 0 OR GROSS_DELIVERY_AMOUNT > 0)
          AND order_rejection_reason IN ('', 'A1')
          -- AND sold_to_dealer_or_distributor = '0000016030' 
          -- AND ORDER_DATE BETWEEN '2025-03-01' AND '2025-03-31'
        GROUP BY order_no
    ) MD
        ON O.order_no = MD.order_no),


	fillrate_cal AS (
        SELECT DISTINCT
			order_no,
			order_material,
			BU,
			CASE WHEN DATEDIFF(day, order_date, billing_date) <= 3 THEN actual_billed_qty ELSE 0 END AS three_day_2W,
			CASE WHEN DATEDIFF(day, order_date, billing_date) <= 7 THEN actual_billed_qty ELSE 0 END AS seven_day_2W,
			CASE WHEN DATEDIFF(day, min_delivery_date, delivery_date) <= 3 THEN actual_billed_qty ELSE 0 END AS three_day_3W,
			CASE WHEN DATEDIFF(day, min_delivery_date, delivery_date) <= 7 THEN actual_billed_qty ELSE 0 END AS seven_day_3W
			FROM order_with_min_date	
		
	),


-- CTE for 3-day and 7-day delivery quantities - ICBU

	DeliveryQuantities AS (
        SELECT DISTINCT
			order_no,
			order_material,
			CASE WHEN BU = '2W' THEN SUM(three_day_2W) ELSE SUM(three_day_3W) END AS three_day_delivery_qty,
			CASE WHEN BU = '2W' THEN SUM(seven_day_2W) ELSE SUM(seven_day_3W) END AS seven_day_delivery_qty
		FROM fillrate_cal	
		GROUP BY order_no, order_material,BU
	),
		 
	-- CTE for First Fill Rate
	FirstFillRate AS (
		SELECT DISTINCT
    order_no,
    order_material,
    CASE 
        WHEN order_quantity = SUM(actual_billed_qty)
        AND delivery_date = min_delivery_date
        THEN 1 ELSE 0 
        END AS first_fill_rate_flag
FROM order_with_min_date
GROUP BY 
    order_no,
    order_material,
    order_quantity,
    delivery_date,
    min_delivery_date
	),
 
	-- CTE for Lead Time
	LeadTime AS (
		select order_no, order_material, datediff(day, order_date, billing_date) AS lead_time from (
		SELECT DISTINCT
			order_no,
            order_material,
            order_date,
			MAX(billing_date) AS billing_date
		FROM dbo.VW_SPARES_ICMC_ODI_DATA 
        WHERE billing_date IS NOT NULL
		AND sales_organization='ZDOM'
		and invoice_division='B1' 
		and distribution_channel in (10,20)  
		and billing_type_analytics in ('ZSTD','ZSCH','ZVOR','ZPSD','ZPVR')  
        AND ORDER_PLANT in ('WA02','PT02')
		and (GROSS_INVOICE_AMOUNT > 0 OR GROSS_DELIVERY_AMOUNT > 0)
		and order_rejection_reason in ('', 'A1')
		--AND sold_to_dealer_or_distributor = '0000016030' AND ORDER_DATE BETWEEN '2025-03-01' AND '2025-03-31'
		group by order_no,order_material,order_date)A
		group by order_no, order_material,order_date,billing_date
	),
	 
	-- CTE for Distributor Block Status
	DistributorStatus AS (
		SELECT
			KNA1.KUNNR AS DEALER_DISTRIBUTOR_ID,
			CASE
				WHEN KNA1.AUFSD = '' AND KNA1.LIFSD = '' AND KNA1.FAKSD = '' THEN 'ACTIVE'
				WHEN KNA1.AUFSD <> '' THEN 'ORDER_BLOCK'
				WHEN KNA1.LIFSD <> '' THEN 'DELIVERY_BLOCK'
				WHEN KNA1.FAKSD <> '' THEN 'INVOICE_BLOCK'
			END AS STATUS_COL1,
			CASE
				WHEN KNVV.AUFSD = '' AND KNVV.LIFSD = '' AND KNVV.FAKSD = '' THEN 'ACTIVE'
				WHEN KNVV.AUFSD <> '' THEN 'ORDER_BLOCK'
				WHEN KNVV.LIFSD <> '' THEN 'DELIVERY_BLOCK'
				WHEN KNVV.FAKSD <> '' THEN 'INVOICE_BLOCK'
			END AS STATUS_COL2
		FROM SAP_CUSTOMER_MASTER_KNA1 KNA1
		JOIN SAP_KNVV KNVV ON KNA1.KUNNR = KNVV.KUNNR
		WHERE KNVV.VKORG = 'ZDOM' AND KNVV.SPART = 'B1' AND KNVV.VTWEG IN (10, 20) --AND KUNNR='0000015666'
	),
	
	KPI_MATERIAL_FLAG AS (
	SELECT DISTINCT ORDER_NO,ORDER_MATERIAL, OTD.ITEM
	FROM dbo.VW_SPARES_ICMC_ODI_DATA AS OTD
    where OTD.sales_organization='ZDOM' and OTD.order_division='B1'  and OTD.distribution_channel in (10,20)  
    and otd.order_type in ('ZSTD','ZSCH','ZVOR','ZPSD','ZPVR','ZSPD')
    and OTD.order_rejection_reason in ('', 'A1')  AND ORDER_PLANT in ('WA02','PT02')
	--AND sold_to_dealer_or_distributor = '0000016030' AND ORDER_DATE BETWEEN '2025-03-01' AND '2025-03-31'
	),
	
	ORDER_DATA AS (
	SELECT DISTINCT
	ORDER_NO,
	ITEM,
	ORDER_DATE,
	ORDER_MATERIAL,
	ORDER_QUANTITY,
	GROSS_ORDER_AMOUNT,
	SOLD_TO_DEALER_OR_DISTRIBUTOR,
	DISTRIBUTION_CHANNEL,
	ORDER_PLANT,
	BU
	FROM (
	SELECT 
		ORDER_NO,
		ITEM,
		ORDER_DATE,
		ORDER_MATERIAL,
		ORDER_QUANTITY,
		GROSS_ORDER_AMOUNT,
		ORDER_CHANGE_DATE, 
		ORDER_VBAP_DATALOADTIME,
		ORDER_TYPE,
		SALES_ORGANIZATION,
		ORDER_DIVISION,
		ORDER_REJECTION_REASON,
		DISTRIBUTION_CHANNEL,
		ORDER_CANCELLATION, ORDER_PLANT,
		A.SOLD_TO_DEALER_OR_DISTRIBUTOR,
		CASE WHEN CM.KATR6='2WH' THEN '2W'
			 WHEN CM.KATR6='3WH' THEN '3W'
		ELSE NULL END AS BU,
		ROW_NUMBER() OVER( PARTITION BY ORDER_NO,ITEM ORDER BY ORDER_CHANGE_DATE DESC, ORDER_VBAP_DATALOADTIME DESC, ORDER_VBAK_DATALOADTIME DESC) as RNK
		FROM VW_SPARES_ICMC_ODI_DATA A 
		LEFT JOIN SAP_CUSTOMER_MASTER_KNA1 CM ON A.SOLD_TO_DEALER_OR_DISTRIBUTOR=CM.KUNNR
		WHERE  CM.KATR6 IN ('2WH','3WH') 
		and DISTRIBUTION_CHANNEL IN (10,20) AND SALES_ORGANIZATION='ZDOM' AND ORDER_DIVISION='B1' 
		AND ORDER_TYPE IN ('ZSTD','ZSCH','ZVOR','ZPSD','ZPSH','ZPVR','ZSPD','ZSPD')
		--AND ORDER_NO='0102962562' AND ORDER_MATERIAL='39193120'
		) A
	WHERE RNK = 1 AND ORDER_REJECTION_REASON IN ('','A1')
	--AND ORDER_CANCELLATION = 'A' 
	),
	 
	CTE_CAL AS (
	SELECT DISTINCT
		OTD.order_no,
		OTD.sold_to_dealer_or_distributor,
		OTD.order_date,
		OTD.order_material,
		OTD.order_quantity,
		OTD.gross_order_amount,
		CASE WHEN OTD.ORDER_NO=KPI.ORDER_NO AND OTD.ORDER_MATERIAL=KPI.ORDER_MATERIAL AND OTD.ITEM=KPI.ITEM THEN 1 ELSE 0
			END AS KPI_FLAG,
        OTD.order_plant,
		OTD.ITEM,
        OTD.distribution_channel,
		OTD.BU,
		COALESCE(FFR.first_fill_rate_flag, 0) AS FIRST_FILL_RATE,
		CASE WHEN OTD.order_quantity = DQ.three_day_delivery_qty THEN '1' ELSE '0' END AS [3_DAYS_FILLRATE],
		CASE WHEN OTD.order_quantity = DQ.seven_day_delivery_qty THEN '1' ELSE '0' END AS [7_DAYS_FILLRATE],
		COALESCE(LT.lead_time, 0) AS LEAD_TIME,
		CASE
		WHEN A.STATUS_COL1=A.STATUS_COL2 THEN STATUS_COL1
		WHEN A.STATUS_COL1='ACTIVE' AND A.STATUS_COL2<>'ACTIVE' THEN STATUS_COL2
		WHEN A.STATUS_COL1='ORDER_BLOCK' AND (A.STATUS_COL2='ACTIVE' OR A.STATUS_COL2='DELIVERY_BLOCK' OR A.STATUS_COL2='INVOICE_BLOCK') THEN STATUS_COL1
		WHEN A.STATUS_COL1='DELIVERY_BLOCK' AND (A.STATUS_COL2='ACTIVE' OR A.STATUS_COL2='ORDER_BLOCK' OR A.STATUS_COL2='INVOICE_BLOCK') THEN STATUS_COL1
		WHEN A.STATUS_COL1='INVOICE_BLOCK' AND (A.STATUS_COL2='ACTIVE' OR A.STATUS_COL2='ORDER_BLOCK' OR A.STATUS_COL2='DELIVERY_BLOCK') THEN STATUS_COL1
		WHEN A.STATUS_COL2='ACTIVE' AND A.STATUS_COL1<>'ACTIVE' THEN STATUS_COL1
		WHEN A.STATUS_COL2='ORDER_BLOCK' AND (A.STATUS_COL1='ACTIVE' OR A.STATUS_COL1='DELIVERY_BLOCK' OR A.STATUS_COL1='INVOICE_BLOCK') THEN STATUS_COL1
		WHEN A.STATUS_COL2='DELIVERY_BLOCK' AND (A.STATUS_COL1='ACTIVE' OR A.STATUS_COL1='ORDER_BLOCK' OR A.STATUS_COL1='INVOICE_BLOCK') THEN STATUS_COL1
		WHEN A.STATUS_COL2='INVOICE_BLOCK' AND (A.STATUS_COL1='ACTIVE' OR A.STATUS_COL1='ORDER_BLOCK' OR A.STATUS_COL1='DELIVERY_BLOCK') THEN STATUS_COL1
		END AS DISTRIBUTOR_BLOCK_STATUS
	 
	FROM ORDER_DATA OTD
	LEFT JOIN DeliveryQuantities AS DQ ON OTD.order_no = DQ.order_no AND OTD.order_material = DQ.order_material
	LEFT JOIN FirstFillRate AS FFR ON OTD.order_no = FFR.order_no AND OTD.order_material = FFR.order_material
	LEFT JOIN LeadTime AS LT ON OTD.order_no = LT.order_no AND OTD.order_material = LT.order_material
	LEFT JOIN DistributorStatus AS A ON OTD.sold_to_dealer_or_distributor = A.dealer_distributor_id
	LEFT JOIN KPI_MATERIAL_FLAG KPI ON OTD.ORDER_NO = KPI.ORDER_NO AND OTD.ORDER_MATERIAL = KPI.ORDER_MATERIAL AND OTD.ITEM = KPI.ITEM
	)
---------------------------------------------------STG TABLE DATA FULL LOAD------------------------------------------------------


	INSERT INTO [dbo].[ASM_ICMC_SPARES_PRIMARY_SALES_STG] (
	    [BU],
	    [ORDER_NO],
	    [ORDER_AMOUNT],
	    [ORDER_MATERIAL],
	    [ORDER_QUANTITY],
	    [ORDER_DATE],
	    [SOLD_TO_DEALER_OR_DISTRIBUTOR],
	    [DISTRIBUTOR_BLOCK_STATUS],
	    [FIRST_FILL_RATE],
	    [3_DAYS_FILLRATE],
	    [7_DAYS_FILLRATE],
	    [LEAD_TIME],
        [KPI_MATERIAL_COUNT],
        [DISTRIBUTION_CHANNEL],
        [CREATE_DATE]
	    )
 
	SELECT
	    bu,
	    order_no,
	    gross_order_amount,
	    order_material,
	    order_quantity,
	    order_date,
	    sold_to_dealer_or_distributor,
	    DISTRIBUTOR_BLOCK_STATUS,
	    FIRST_FILL_RATE,
	    [3_DAYS_FILLRATE],
	    [7_DAYS_FILLRATE],
	    LEAD_TIME,
        case when
        KPI_FLAG= 1 THEN 1 else 0
        end as KPI_MATERIAL_COUNT,
        distribution_channel,
        CAST(getdate() AS DATE) AS CREATE_DATE
    FROM CTE_CAL
	WHERE BU IN ('2W', '3W')
	AND ORDER_DATE >= @FISCAL_YEAR;



----------------------------------------------------------PARTIALLY CANECLLED ORDERS---------------------------------------------------
	
	
;WITH ORDER_AMOUNT AS (
SELECT ORDER_DATE, ORDER_NO, ORDER_MATERIAL, SUM(GROSS_INVOICE_AMOUNT) as GROSS_ORDER_AMOUNT , 
ITEM,SOLD_TO_DEALER_OR_DISTRIBUTOR,BU,BILLING_TYPE_ANALYTICS,distribution_channel,ORDER_QUANTITY
FROM (
SELECT distinct  ORDER_DATE,ORDER_NO, ORDER_MATERIAL, ORDER_QUANTITY, 
INVOICE_NUMBER, ITEM ,INVOICE_MATERIAL, 
order_rejection_reason, GROSS_INVOICE_AMOUNT,
GROSS_ORDER_AMOUNT,SOLD_TO_DEALER_OR_DISTRIBUTOR,BILLING_TYPE_ANALYTICS,distribution_channel,
CASE WHEN CM.KATR6='2WH' THEN '2W'
     WHEN CM.KATR6='3WH' THEN '3W'
     ELSE NULL END AS BU
    FROM VW_SPARES_ICMC_ODI_DATA A
    LEFT JOIN SAP_CUSTOMER_MASTER_KNA1 CM ON A.sold_to_dealer_or_distributor=CM.KUNNR
WHERE A.sales_organization='ZDOM' and A.invoice_division='B1'  and A.distribution_channel in (10,20)  
and A.billing_type_analytics in ('ZSTD','ZSCH','ZVOR','ZPSD','ZPSH','ZPVR','ZSPD','ZSPD')
AND A.billing_date IS NOT NULL and CM.KATR6 IN ('2WH','3WH')
and order_rejection_reason not in ('', 'A1')
and FKSTO <> 'X' AND GROSS_ORDER_AMOUNT > GROSS_INVOICE_AMOUNT
)A
GROUP BY  ORDER_DATE, ORDER_NO, ORDER_MATERIAL, ITEM, SOLD_TO_DEALER_OR_DISTRIBUTOR,BU, BILLING_TYPE_ANALYTICS,distribution_channel,ORDER_QUANTITY
)

INSERT INTO [dbo].[ASM_ICMC_SPARES_PRIMARY_SALES_STG] (
	    [BU],
	    [ORDER_NO],
	    [ORDER_AMOUNT],
	    [ORDER_MATERIAL],
	    [ORDER_QUANTITY],
	    [ORDER_DATE],
	    [SOLD_TO_DEALER_OR_DISTRIBUTOR],
	    [DISTRIBUTOR_BLOCK_STATUS],
	    [FIRST_FILL_RATE],
	    [3_DAYS_FILLRATE],
	    [7_DAYS_FILLRATE],
	    [LEAD_TIME],
        [KPI_MATERIAL_COUNT],
        [DISTRIBUTION_CHANNEL],
        [CREATE_DATE]
	    )
 
	SELECT
	    bu,
	    order_no,
	    gross_order_amount,
	    order_material,
	    order_quantity,
	    order_date,
	    sold_to_dealer_or_distributor,
	    NULL AS DISTRIBUTOR_BLOCK_STATUS,
	    NULL AS FIRST_FILL_RATE,
	    NULL AS [3_DAYS_FILLRATE],
	    NULL AS [7_DAYS_FILLRATE],
	    NULL AS LEAD_TIME,
        NULL AS KPI_MATERIAL_COUNT,
        distribution_channel,
        CAST(getdate() AS DATE) AS CREATE_DATE
    FROM ORDER_AMOUNT
	WHERE BU IN ('2W', '3W')
	AND ORDER_DATE >= @FISCAL_YEAR;

    ----------------------------------------------FACT TABLE DATA FULL LOAD------------------------------------------------

    TRUNCATE TABLE [dbo].[ASM_ICMC_SPARES_ORDER_DATA_FACT];

	INSERT INTO [dbo].[ASM_ICMC_SPARES_ORDER_DATA_FACT] (
		[ORDER_NO],
	    [BU],
	    [SOLD_TO_DEALER_OR_DISTRIBUTOR],
	    [ORDER_DATE],
	    [ORDER_AMOUNT],
	    [MATERIAL_COUNT],
		   [FFR_FLAG_SUM],
	    [3FR_FLAG_SUM],
	    [7_FR_FLAG_SUM] ,
	    [LEAD_TIME_SUM] ,
	    [DISTRIBUTOR_BLOCK_STATUS],
        [KPI_MATERIAL_COUNT],
        [DISTRIBUTION_CHANNEL],
        [CREATE_DATE]
	    )
	 
	SELECT
	ORDER_NO,
	BU,
	SOLD_TO_DEALER_OR_DISTRIBUTOR,
	ORDER_DATE,
	SUM(ORDER_AMOUNT) AS TOTAL_ORDER_AMOUNT,
	COUNT(ORDER_NO) AS MATERIAL_COUNT,
	SUM(FIRST_FILL_RATE) AS FFR_FLAG_SUM,
	SUM([3_DAYS_FILLRATE]) AS [3FR_FLAG_SUM],
	SUM([7_DAYS_FILLRATE]) AS [7_FR_FLAG_SUM],
	SUM(LEAD_TIME) AS LEAD_TIME_SUM,
	DISTRIBUTOR_BLOCK_STATUS,
    SUM(KPI_MATERIAL_COUNT),
    DISTRIBUTION_CHANNEL,
    CAST(getdate() AS DATE) AS CREATE_DATE
	FROM dbo.ASM_ICMC_SPARES_PRIMARY_SALES_STG
	GROUP BY ORDER_NO,BU,SOLD_TO_DEALER_OR_DISTRIBUTOR,ORDER_DATE,DISTRIBUTOR_BLOCK_STATUS, DISTRIBUTION_CHANNEL;

	---------------------Audit target count---------------------------------------------------------------------
BEGIN TRY
SELECT @TargetCount =  COUNT(1) FROM ASM_ICMC_SPARES_ORDER_DATA_FACT;

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
        'Spares',
        'ICMC',
        @StartDate_utc,
        @EndDate_utc,
		@StartDate_ist,
        @EndDate_ist,
        @Duration,  
        0,
        @TargetCount,
        @Status,
        @ErrorMessage;
		
		PRINT 'Audit Execution completed ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));



----------------------------------------------------**PRIMARY SCREEN INVOICE DATA LOAD**---------------------------------------------------------------

TRUNCATE TABLE [dbo].[ASM_ICMC_SPARES_INVOICE_DATA_STG];

--------------AUdit table --------------------------
PRINT 'Audit Execution Started ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));
		

DECLARE @StartDate_utc1 DATETIME = GETDATE(),
            @EndDate_utc1 DATETIME,
			@StartDate_ist1 DATETIME = (DATEADD(mi,30,(DATEADD(hh,5,getdate())))),
            @EndDate_ist1 DATETIME,
            @Duration_sec1 bigint,
			@Duration1 varchar(15),
			 @table_name1 VARCHAR(128) = 'ASM_ICMC_SPARES_INVOICE_DATA_STG and FACT',
            @SourceCount1 BIGINT,  
            @TargetCount1 BIGINT, 			
            @Status1 VARCHAR(10),
            @ErrorMessage1 VARCHAR(MAX)


--CTE FOR UNIQUE_SKU_BILLED

;with 
UNIQUE_SKU as (
SELECT
A.billing_date ,
A.SOLD_TO_DEALER_OR_DISTRIBUTOR ,A.BU,
COUNT(A.INVOICE_MATERIAL) AS UNIQUE_SKU
FROM (
select A.billing_date ,
A.SOLD_TO_DEALER_OR_DISTRIBUTOR,
A.INVOICE_MATERIAL,
CASE WHEN CM.KATR6='2WH' THEN '2W'
     WHEN CM.KATR6='3WH' THEN '3W'
     ELSE NULL END AS BU
FROM dbo.VW_SPARES_ICMC_ODI_DATA A
LEFT JOIN SAP_CUSTOMER_MASTER_KNA1 CM ON A.sold_to_dealer_or_distributor=CM.KUNNR
WHERE A.billing_date is not NULL
AND A.sales_organization='ZDOM' and A.invoice_division='B1'  and A.distribution_channel in (10,20)  
and A.billing_type_analytics in ('ZSTD','ZSCH','ZVOR','ZPSD','ZPSH','ZPVR','ZSPD','ZSPD')
)A
GROUP BY A.billing_date,A.BU, A.SOLD_TO_DEALER_OR_DISTRIBUTOR
),

--CTE FOR FOCUS_PART_SALE 

FOCUS_PART_SALE as (                                                                                                   
SELECT BILLING_DATE,BU, SOLD_TO_DEALER_OR_DISTRIBUTOR, SUM(FOCUS_PART_SALE) AS FOCUS_PART_SALE FROM
(
select DISTINCT ORDER_NO, INVOICE_ITEM, INVOICE_NUMBER,
BILLING_DATE,
INVOICE_MATERIAL, A.SOLD_TO_DEALER_OR_DISTRIBUTOR, GROSS_INVOICE_AMOUNT, SUBSTRING(CM.KATR6,1,2) AS BU,
CASE WHEN A.INVOICE_MATERIAL = FPL.[P.No.] THEN GROSS_INVOICE_AMOUNT ELSE 0 END AS FOCUS_PART_SALE
from dbo.VW_SPARES_ICMC_ODI_DATA A
LEFT JOIN SAP_CUSTOMER_MASTER_KNA1 CM ON A.sold_to_dealer_or_distributor=CM.KUNNR 
LEFT JOIN
(SELECT CALENDAR_DATE, FISCAL_YEAR, FISCAL_MONTH, CONCAT('Q',FISCAL_QUARTER) AS FY_Q ,
CONCAT(FISCAL_YEAR,'-',FISCAL_YEAR+1) as FY
from dbo.ASM_CV_CALENDAR_DIM ) CL
ON A.BILLING_DATE = CL.CALENDAR_DATE
LEFT JOIN dbo.FOCUS_PART_LIST FPL
ON SUBSTRING(INVOICE_MATERIAL, PATINDEX('%[^0]%', INVOICE_MATERIAL+'.'), LEN(INVOICE_MATERIAL)) = FPL.[P.No.]
AND CL.FY = FPL.FY
AND CL.FY_Q = FPL.[Quarter]
AND LEFT(CM.KATR6, 2) = FPL.BU
WHERE A.billing_date is not NULL
AND A.sales_organization='ZDOM' and A.invoice_division='B1'  and A.distribution_channel in (10,20)  
and A.billing_type_analytics in ('ZSTD','ZSCH','ZVOR','ZPSD','ZPSH','ZPVR','ZSPD','ZSPD') AND A.FKSTO<>'X'
)C 
GROUP BY BILLING_DATE,BU, SOLD_TO_DEALER_OR_DISTRIBUTOR
),
 
--CTE FOR PRIMARY SALES

INVOICE_AMOUNT AS (                                                                                                         
    SELECT SUM(GROSS_INVOICE_AMOUNT) AS INVOICE_AMOUNT,SOLD_TO_DEALER_OR_DISTRIBUTOR,billing_date,BU, DISTRIBUTION_CHANNEL
    FROM  (SELECT DISTINCT A.ORDER_NO,A.INVOICE_ITEM,A.INVOICE_MATERIAL,A.INVOICE_NUMBER, A.GROSS_INVOICE_AMOUNT,A.SOLD_TO_DEALER_OR_DISTRIBUTOR,
    A.billing_date, A.distribution_channel,
    CASE WHEN CM.KATR6='2WH' THEN '2W'
     WHEN CM.KATR6='3WH' THEN '3W'
     ELSE NULL END AS BU
    FROM VW_SPARES_ICMC_ODI_DATA A
    LEFT JOIN SAP_CUSTOMER_MASTER_KNA1 CM ON A.sold_to_dealer_or_distributor=CM.KUNNR 
WHERE A.sales_organization='ZDOM' and A.invoice_division='B1'  and A.distribution_channel in (10,20)  
and A.billing_type_analytics in ('ZSTD','ZSCH','ZVOR','ZPSD','ZPSH','ZPVR','ZSPD','ZSPD') 
AND A.billing_date IS NOT NULL and CM.KATR6 IN ('2WH','3WH') AND FKSTO<>'X'
)P
    GROUP BY SOLD_TO_DEALER_OR_DISTRIBUTOR,billing_date,BU, DISTRIBUTION_CHANNEL
),

CTE_CAL AS (
SELECT
IA.billing_date AS INVOICE_DATE,
IA.SOLD_TO_DEALER_OR_DISTRIBUTOR,
IA.BU,
IA.INVOICE_AMOUNT,
IA.DISTRIBUTION_CHANNEL,
SKU.UNIQUE_SKU,
FP.FOCUS_PART_SALE
FROM INVOICE_AMOUNT IA
LEFT JOIN UNIQUE_SKU SKU
ON IA.billing_date=SKU.billing_date AND IA.SOLD_TO_DEALER_OR_DISTRIBUTOR=SKU.SOLD_TO_DEALER_OR_DISTRIBUTOR AND IA.BU=SKU.BU
LEFT JOIN FOCUS_PART_SALE FP
ON IA.billing_date=FP.billing_date AND IA.SOLD_TO_DEALER_OR_DISTRIBUTOR=FP.SOLD_TO_DEALER_OR_DISTRIBUTOR AND IA.BU=FP.BU
WHERE IA.BU IN ('2W','3W')
)

---------------------------------------------------STG TABLE DATA FULL LOAD------------------------------------------------------


INSERT INTO [dbo].[ASM_ICMC_SPARES_INVOICE_DATA_STG]
(
SOLD_TO_DEALER_OR_DISTRIBUTOR,
BU,
INVOICE_DATE,
INVOICE_AMOUNT,
DISTRIBUTION_CHANNEL,
UNIQUE_SKU_BILLED,
FOCUS_PART_SALE_ACTUAL,
CREATE_DATE
) 

SELECT
SOLD_TO_DEALER_OR_DISTRIBUTOR,
BU,
INVOICE_DATE,
INVOICE_AMOUNT,
DISTRIBUTION_CHANNEL,
UNIQUE_SKU,
FOCUS_PART_SALE,
CAST(getdate() AS DATE) AS CREATE_DATE
FROM CTE_CAL
WHERE INVOICE_DATE >= @FISCAL_YEAR;

    ----------------------------------------------DIM TABLE DATA FULL LOAD------------------------------------------------

TRUNCATE TABLE [dbo].[ASM_ICMC_SPARES_INVOICE_DATA_FACT];

INSERT INTO [dbo].[ASM_ICMC_SPARES_INVOICE_DATA_FACT]
(
    [SOLD_TO_DEALER_OR_DISTRIBUTOR],
    [BU],
    [INVOICE_DATE],
    [INVOICE_AMOUNT],
	[DISTRIBUTION_CHANNEL],
    [UNIQUE_SKU_BILLED],
    [FOCUS_PART_SALE_ACTUAL],
    [CREATE_DATE]
)
 
SELECT
SOLD_TO_DEALER_OR_DISTRIBUTOR,
BU,
INVOICE_DATE,
INVOICE_AMOUNT,
DISTRIBUTION_CHANNEL,
UNIQUE_SKU_BILLED,
FOCUS_PART_SALE_ACTUAL,
CAST(getdate() AS DATE) AS CREATE_DATE
FROM [dbo].[ASM_ICMC_SPARES_INVOICE_DATA_STG];

---------------------Audit target count---------------------------------------------------------------------
BEGIN TRY
SELECT @TargetCount1 =  COUNT(1) FROM ASM_ICMC_SPARES_INVOICE_DATA_FACT;

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
        'Spares',
        'ICMC',
        @StartDate_utc1,
        @EndDate_utc1,
		@StartDate_ist1,
        @EndDate_ist1,
        @Duration1,  
        0,
        @TargetCount1,
        @Status1,
        @ErrorMessage1;
		
		PRINT 'Audit Execution completed ' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()));





PRINT('Order and Invoice data for Primary screen loaded successfully')

END
GO