

/****** Object:  StoredProcedure [dbo].[USP_Full_Load_ASM_PB_T_STOCK_REFRESH]    Script Date: 03-11-2023 11:16:05 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

Alter PROC [dbo].[USP_Full_Load_ASM_PB_T_STOCK_REFRESH] AS
BEGIN
--***************************START********************************************************************************
/*******************************************HISTORY***************************************************************/
/*---------------------------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					             */
/*---------------------------------------------------------------------------------------------------------------*/
/*	2023-08-01	|	Nikita L		        |         New stored procedure created for Triumph						  */
/*	2024-05-14	|	Nikita L		        |         Chnages Related to SKU Mapping								  */
/*---------------------------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY***************************************************************/

--*********************START************************
--Stock Fact:
TRUNCATE TABLE ASM_PB_T_STOCK_FACT

INSERT INTO ASM_PB_T_STOCK_FACT
SELECT DISTINCT
VS.COMPANYCODE As DEALERCODE,
VS.MODELCODE+(CASE WHEN CHARINDEX('[',COLOR)>0 AND CHARINDEX(']',COLOR)>0 THEN SUBSTRING(COLOR,CHARINDEX('[',COLOR)+1,CHARINDEX(']',COLOR) - CHARINDEX('[',COLOR) - 1) ELSE '' END )  as SKU,
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
FROM
   VEHICLE_STOCK_DATA VS INNER JOIN COMPANY_MASTER CM ON (VS.COMPANYCODE=CM.CODE AND CM.COMPANYTYPE = 2)--  AND CM.COMPANYSUBTYPE='Triumph' 
       INNER JOIN (select *, Row_number() over (partition by MODELCODE order by MODELCODE) as rnk
    from ASM_PB_HKT_PRODUCT_DIM) PM  
   ON  PM.Modelcode = VS.MODELCODE and PM.BRAND ='TRIUMPH'and rnk = 1
   
WHERE 
CAST(VS.EXECUTIONDATE AS DATE) BETWEEN '2025-06-09' AND Cast(Getdate()-1 as date)
--Cast(VS.EXECUTIONDATE as date)>(SELECT MAX(DATE) from ASM_PB_T_STOCK_FACT)
GROUP BY
  VS.COMPANYCODE,
  VS.MODELCODE+(CASE WHEN CHARINDEX('[',COLOR)>0 AND CHARINDEX(']',COLOR)>0 THEN SUBSTRING(COLOR,CHARINDEX('[',COLOR)+1,CHARINDEX(']',COLOR) - CHARINDEX('[',COLOR) - 1) ELSE '' END ),
  CAST(VS.EXECUTIONDATE as Date),
  CM.COMPANYTYPE,
  VS.VEHICLESTATUS,
  VS.IMPORTEDDATE,
  VS.MODELCODE
 
--OLD Logic

INSERT INTO ASM_PB_T_STOCK_FACT
SELECT DISTINCT
VS.COMPANYCODE As DEALERCODE,
VS.MODELCODE+(CASE WHEN CHARINDEX('[',COLOR)>0 AND CHARINDEX(']',COLOR)>0 THEN SUBSTRING(COLOR,CHARINDEX('[',COLOR)+1,CHARINDEX(']',COLOR) - CHARINDEX('[',COLOR) - 1) ELSE '' END )  as SKU,
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
FROM
   VEHICLE_STOCK_DATA VS INNER JOIN COMPANY_MASTER CM ON (VS.COMPANYCODE=CM.CODE AND CM.COMPANYTYPE = 2  AND CM.COMPANYSUBTYPE='Triumph' 
   )
WHERE 
CAST(VS.EXECUTIONDATE AS DATE) BETWEEN '2021-01-01' AND '2025-06-08' 
--Cast(VS.EXECUTIONDATE as date)>(SELECT MAX(DATE) from ASM_TRIUMPH_STOCK_FACT)
GROUP BY
  VS.COMPANYCODE,
  VS.MODELCODE+(CASE WHEN CHARINDEX('[',COLOR)>0 AND CHARINDEX(']',COLOR)>0 THEN SUBSTRING(COLOR,CHARINDEX('[',COLOR)+1,CHARINDEX(']',COLOR) - CHARINDEX('[',COLOR) - 1) ELSE '' END ),
  CAST(VS.EXECUTIONDATE as Date),
  CM.COMPANYTYPE,
  VS.VEHICLESTATUS,
  VS.IMPORTEDDATE,
  VS.MODELCODE


--Product Master and Dealer Master FK update: ASM_PB_T_STOCK_FACT
update B set B.FK_SKU=C.PK_SKU from ASM_PB_T_STOCK_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_SKU_DIM C on (B.SKU=C.SKU_CODE)
update B set B.FK_MODEL=C.PK_Model_Code from ASM_PB_T_STOCK_FACT B INNER JOIN ASM_PB_HKT_PRODUCT_DIM C on (B.ModelCode=C.MODELCODE)
update B set B.FK_DEALERCODE=C.PK_DEALERCODE from [dbo].ASM_PB_T_STOCK_FACT B INNER JOIN ASM_PB_HKT_DEALER_MASTER_DIM C on (B.DEALERCODE=C.DEALERCODE)
--***********************************************************************************************************
END
GO


