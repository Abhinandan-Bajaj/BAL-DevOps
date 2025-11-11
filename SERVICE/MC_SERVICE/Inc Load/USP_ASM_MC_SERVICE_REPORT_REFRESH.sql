SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-05-06 	|	Aakash Kundu		| Updating DocDate filter to FY20-21                        */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/


CREATE PROC [dbo].[USP_ASM_MC_SERVICE_REPORT_REFRESH] AS
BEGIN

--Free Service Due Report

TRUNCATE TABLE [dbo].[ASM_MC_RETAIL_FLAGS_UNION]

INSERT [dbo].[ASM_MC_RETAIL_FLAGS_UNION]

SELECT 
* 
FROM
(SELECT 
    [FK_Docid],
    DOCNAME,
    Retail_Type,
    PaidDueDate,
    FK_Companyid,
    Lineid,
    BU,
    AR.Companytype,
    [Dealercode],
    CASE WHEN RETAIL_TYPE = 'VSI' THEN FK_Contactid
    WHEN RETAIL_TYPE = 'AVSI' THEN ASDA_CONTACT ELSE NULL END AS FK_Contactid,
    [FK_Ibid],
    CASE WHEN RETAIL_TYPE = 'VSI' THEN FK_Branchid 
    WHEN RETAIL_TYPE = 'AVSI' THEN ASDA_BRANCHID ELSE NULL END AS FK_Branchid,
	FK_Modelid,
    [1stFS_EXPIRY1_Date] as Due_date,
    [1stFS_EXPIRY2_Date] as Expiry_date,
    'First Free Service' as Service_type,
    FSServicingStatus as Service_Status,
	FS_SERVICE_DATE AS Service_Date,
	CM.NAME AS Servicing_Outlet
    from ASM_MC_RETAIL_FLAGS AR
	LEFT JOIN COMPANY_MASTER CM ON CM.COMPANYID = AR.FS_COMPANYID
	WHERE CAST(DOCDATE AS DATE) >= '2020-04-01'

    UNION ALL
	
    SELECT 
    [FK_Docid],
    DOCNAME,
    Retail_Type,
    PaidDueDate,
    FK_Companyid,
    Lineid,
    BU,
    AR.Companytype,
    [Dealercode],
    CASE WHEN RETAIL_TYPE = 'VSI' THEN FK_Contactid
    WHEN RETAIL_TYPE = 'AVSI' THEN ASDA_CONTACT ELSE NULL END AS FK_Contactid,
    [FK_Ibid],
    CASE WHEN RETAIL_TYPE = 'VSI' THEN FK_Branchid 
    WHEN RETAIL_TYPE = 'AVSI' THEN ASDA_BRANCHID ELSE NULL END AS FK_Branchid,
	FK_Modelid,
    [2ndFS_EXPIRY1_Date] as Due_date,
    [2ndFS_EXPIRY2_Date] as Expiry_date,
    'Second Free Service' as Service_type,
    SSServicingStatus as Service_Status,
	SS_SERVICE_DATE AS Service_Date,
	CM.NAME AS Servicing_Outlet
    from ASM_MC_RETAIL_FLAGS AR
	LEFT JOIN COMPANY_MASTER CM ON CM.COMPANYID = AR.SS_COMPANYID
	WHERE CAST(DOCDATE AS DATE) >= '2020-04-01'
    
    UNION ALL
	
    SELECT 
    [FK_Docid],
    DOCNAME,
    Retail_Type,
    PaidDueDate,
    FK_Companyid,
    Lineid,
    BU,
    AR.Companytype,
    [Dealercode],
    CASE WHEN RETAIL_TYPE = 'VSI' THEN FK_Contactid
    WHEN RETAIL_TYPE = 'AVSI' THEN ASDA_CONTACT ELSE NULL END AS FK_Contactid,
    [FK_Ibid],
    CASE WHEN RETAIL_TYPE = 'VSI' THEN FK_Branchid 
    WHEN RETAIL_TYPE = 'AVSI' THEN ASDA_BRANCHID ELSE NULL END AS FK_Branchid,
	FK_Modelid,
    [3rdFS_EXPIRY1_Date] as Due_date,
    [3rdFS_EXPIRY2_Date] as Expiry_date,
    'Third Free Service' as Service_type,
    TSServicingStatus as Service_Status,
	TS_SERVICE_DATE AS Service_Date,
	CM.NAME AS Servicing_Outlet
    from ASM_MC_RETAIL_FLAGS AR
	LEFT JOIN COMPANY_MASTER CM ON CM.COMPANYID = AR.TS_COMPANYID
	WHERE CAST(DOCDATE AS DATE) >= '2020-04-01'
   
) t

-----------------------------------------------------------

--3rdFS_to_1stPS Conversion Report

TRUNCATE TABLE [ASM_MC_FS_PS_CONV]

INSERT INTO [ASM_MC_FS_PS_CONV]

SELECT BASE.FK_Ibid,Ret_Dealercode,PaidDueDate,FS_DealerCode,FK_Branchid,Fk_Contactid,Fk_Modelid,FilterDate
,[3rdFS_To_1stPS]
,CASE WHEN [3rdFS_To_1stPS]=1 THEN 'Yes' WHEN [3rdFS_To_1stPS]=0 THEN 'No' END AS [3rdFS_To_1stPS_Conversion]
,FREE_MAIN_BLOCK.FREE_DATE AS [3rd_FS_Date]
,FREE_MAIN_BLOCK.KmReading_3rdFS
,PAID_MAIN_BLOCK1.PAID_DATE AS [1st_Paid_Date]
,PAID_MAIN_BLOCK1.USAGEREADING_PAID1 AS KmReading_1stPS
,PAID_MAIN_BLOCK1.PS_Dealercode
--INTO MC_3rdFs_1stPaid_Data 
FROM
(SELECT DISTINCT FK_Ibid,DATEADD(MM,7,Billeddatetime) AS FilterDate,[3rdFS_To_1stPS],
ROW_NUMBER() OVER(PARTITION BY FK_Ibid ORDER BY Billeddatetime DESC) RNK,
Dealercode as FS_Dealercode,FK_Branchid,FK_Contactid,FK_Modelid
FROM ASM_MC_SERVICE_STG
WHERE Service_Retail_TypeIdentifier=101
AND FK_Contracttypeid IN (40)) BASE

LEFT JOIN 

(SELECT * FROM
(SELECT DISTINCT FK_IBID,SS.BILLEDDATETIME AS FREE_DATE
,SS.USAGEREADING AS KmReading_3rdFS
,ROW_NUMBER() OVER(PARTITION BY FK_IBID ORDER BY SS.BILLEDDATETIME) FREE_RNO
FROM ASM_MC_SERVICE_STG SS
WHERE SS.FK_Contracttypeid IN (40)) FREE_BLOCK1
WHERE FREE_RNO=1)FREE_MAIN_BLOCK ON FREE_MAIN_BLOCK.FK_IBID=BASE.FK_IBID

LEFT JOIN

(SELECT FK_IBID,PAID_DATE,USAGEREADING_PAID1,PS_Dealercode FROM
(SELECT FK_IBID,PAID_DATE,USAGEREADING_PAID1,PS_Dealercode
,ROW_NUMBER() OVER(PARTITION BY FK_IBID ORDER BY PAID_DATE ASC) PAID_RNO
FROM
(SELECT BASE.FK_IBID,FREE_BLOCK2.FREE_DATE,PAID_BLOCK.PAID_DATE
,FREE_BLOCK2.USAGEREADING_FS3
,PAID_BLOCK.USAGEREADING_PAID1
,PAID_BLOCK.PS_Dealercode
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
--LEFT JOIN SERVICE_CONTRACT_MASTER SC ON SC.SERVICECONTRACTID=SS.FK_Contracttypeid
WHERE SS.FK_Contracttypeid IN (40)) FREE_BLOCK1
WHERE FREE_RNO=1)FREE_BLOCK2 ON FREE_BLOCK2.FK_IBID=BASE.FK_IBID
LEFT JOIN
(SELECT DISTINCT FK_IBID,BU
,SS.BILLEDDATETIME AS PAID_DATE
,SS.USAGEREADING AS USAGEREADING_PAID1
,SS.DealerCode AS PS_Dealercode
 FROM ASM_MC_SERVICE_STG SS
WHERE SS.FK_CONTRACTTYPEID IN (2,41,42,192,193,13))PAID_BLOCK ON BASE.FK_IBID=PAID_BLOCK.FK_IBID
) BASE
WHERE EXCLUDE_FLAG<>1)PAID_FINAL_BLOCK
WHERE PAID_RNO=1)PAID_MAIN_BLOCK1 ON PAID_MAIN_BLOCK1.FK_IBID=BASE.FK_IBID

LEFT JOIN

(SELECT FK_Ibid, PaidDueDate, Dealercode AS Ret_Dealercode
FROM ASM_MC_SERVICE_FACT 
WHERE SERVICE_RETAIL_TYPEIDENTIFIER=102) RET_BASE ON RET_BASE.FK_Ibid=BASE.FK_IBID

WHERE BASE.RNK=1

END

GO