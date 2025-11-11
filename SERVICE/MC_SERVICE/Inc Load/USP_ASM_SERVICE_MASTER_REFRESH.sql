SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					                        */
/*--------------------------------------------------------------------------------------------------*/
/*	2024-05-06 	|	Aakash Kundu		| Dealer Master - RLS columns added for MC BU                     */
/*                                | Branch Master - TypeOfChannel Logic Update                      */
/*                                | InstallBase Master - Updating InvoiceDate for NULLS             */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

CREATE PROC [dbo].[USP_ASM_SERVICE_MASTER_REFRESH] AS
BEGIN

-----------------------------LOAD DEALER MASTER DATA

TRUNCATE TABLE ASM_SERVICE_DEALER_MASTER_DIM

insert into ASM_SERVICE_DEALER_MASTER_DIM(
[DealerCode]
,[DealerName]
,[Region]
,[RegionCode]
,[Hub]
,[Circle]
,[City]
,[State]
,[ASM]
,[RM]
,[BU]
,[HID]
,[Status_MC]
,[Status]
,[DealerCode_MC]
,[Refresh_Date]
,dealeremail
,ASM_NAME
,ASM_Email
,RM_NAME
,RM_EMAIL
,CH_NAME
,CH_EMAIL
)
select distinct dr.KUNNR
	  ,dr.NAME1
	  ,dr.VTEXT1
	  ,dr.SER_REG
	  ,dr.SER_HUB
	  ,dr.CIRCLE
	  ,dr.CITY1
	  ,dr.BEZEI
	  ,dr.rufnm3
	  ,dr.rufnm4
	  ,dr.KATR6
	  ,dr.KATR6+' BU' AS HID
	  ,UPPER(dr.SER_STATUS) AS Status_MC
	  ,dr.VTEXT2 AS Status
	  ,RIGHT(dr.KUNNR,5) DealerCode_MC
	  ,getdate()
	  ,SV_EMAIL as dealeremail
	  ,RUFNM3 as ASM_NAME
	  ,EMAIL3 as ASM_Email
 	  ,RUFNM4 as RM_NAME
	  ,EMAIL4 as RM_EMAIL
	  ,RUFNM5	as CH_NAME
	 ,EMAIL5 as CH_EMAIL
from [dbo].[SAP_ZSD_DEALER_REPOS] dr
where dr.T_DDIST='Veh. Dealer'
and KUNNR LIKE '00000[0-9][0-9][0-9][0-9][0-9]'

-----------------------------LOAD BRANCH MASTER DATA

TRUNCATE TABLE ASM_SERVICE_BRANCH_MASTER_DIM
 
INSERT INTO ASM_SERVICE_BRANCH_MASTER_DIM
(
	BranchId,
	BranchName,
	BranchCode,
	TypeOfChannel,
	CompanyType,
	Refresh_Date
)

SELECT DISTINCT 
BM.BRANCHID,
BM.NAME AS [BRANCH NAME],
--BM.CODE AS [BRANCH CODE],
CASE WHEN CM.COMPANYTYPE IN (1,8) AND BM.CODE LIKE '00000%' THEN SUBSTRING(BM.CODE,6,LEN(BM.CODE)) ELSE BM.CODE END AS [BRANCH CODE],
CASE WHEN BM.TYPEOFOUTLET LIKE '%ASD%' THEN 'ASD'
     WHEN BM.TYPEOFOUTLET LIKE 'MAIN%' THEN 'Main Dealership'
     WHEN BM.TYPEOFOUTLET LIKE 'BAL%' THEN 'BAL Registered Branch'
     ELSE 'Others' END AS Typeofchannel,
CM.COMPANYTYPE,
GETDATE() AS Refresh_Date
FROM BRANCH_MASTER BM
JOIN COMPANY_MASTER CM ON CM.COMPANYID=BM.COMPANYID AND CM.COMPANYTYPE IN (1,2,7,8)
WHERE CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)

-----------------------------LOAD MODEL MASTER DATA

TRUNCATE TABLE ASM_SERVICE_MODEL_MASTER_DIM
 
insert into ASM_SERVICE_MODEL_MASTER_DIM(
[ModelCode]
,[Modelid]
,[ModelName]
,[ModelFamily]
,[Category]
,[SubCategory]
,[ModelActivation]
,[BUCategory]
,[CategoryICBU]
,[SubBrand]
,[Brand]
,[Segment]
,[BU]
,[CC]
,[Refresh_Date]
)
select distinct LEFT(B.MATNR,6) AS ModelCode
	  ,IM.ITEMID as ModelID
	  ,zd.ZMKDT_MODEL as ModelName
	  ,zd.ZBRAND_MODEL_VAR as ModelFamily
	  ,zd.ZCATEGORY as Category
	  ,zd.ZSUB_CAT as SubCategory
	  ,zd.model_activation as ModelActivation
	  ,zd.bu_category as BUCategory
	  ,zd.variant as CategoryICBU
	  ,zd.zsub_brd as SubBrand
	  ,UPPER(LEFT(zd.ZBRAND1,1))+LOWER(SUBSTRING(zd.ZBRAND1,2,LEN(zd.ZBRAND1))) as Brand
	  ,zd.ZSEGMENT as Segment
	  ,zd.ZBU_TYPE as BU
	  ,TRIM(REPLACE(IME.CC,'CC','')) AS CC
	  ,getdate()
from [dbo].[SAP_ZBRAND_V_DETAIL] zd
JOIN SAP_MAKT B ON zd.ZBRANDVARIANT=SUBSTRING(B.MATNR,3,4) and B.MATNR LIKE '00%'
LEFT JOIN ITEM_MASTER IM ON IM.CODE=LEFT(B.MATNR,6)
LEFT JOIN ITEM_MASTER_EXT IME ON IME.ITEMID = IM.ITEMID
where zd.ZBU_TYPE in ('MC','PB','CV')

-----------------------------LOAD CONTACT MASTER DATA

TRUNCATE TABLE ASM_SERVICE_CONTACT_MASTER_DIM 

insert into ASM_SERVICE_CONTACT_MASTER_DIM(
[PK_Contactid]
,[Code]
,[CustomerName]
,[Mobile]
,[Pincode]
,[Refresh_Date]
)

 select distinct CM.CONTACTID
	   ,CM.CODE
	   ,CM.NAME 
	   ,CM.MOBILE
       ,CM.ZIPNAME
	   ,getdate() AS Refresh_Date
	   from CONTACT_MASTER CM
	   WHERE CM.ID = (SELECT MAX(CN1.ID) FROM CONTACT_MASTER CN1 WHERE CM.CONTACTID = CN1.CONTACTID)

-----------------------------LOAD MANPOWER MASTER DATA

TRUNCATE TABLE ASM_SERVICE_MANPOWER_MASTER_DIM;

INSERT INTO ASM_SERVICE_MANPOWER_MASTER_DIM
(
[ID],    
[CDMSID],
[CompanyType],
[EmployeeCode],
[FirstName],
[MiddleName],
[LastName],
[CreatedCompanyID],
[CreatedCompany],
[DealerCode],
[Department],
[ContactGroupID],
[EmployeeGroup],
[DesignationID],
[Designation],
[CompanyID],
[Company],
[BranchID],
[Branch],
[IsActive],
[TrainingStatus],
[EmployeeCurrentStatus],
[BranchCategory],
[TypeOfOutlet],
Refresh_Date
)

SELECT DISTINCT
CMD.[ID],
[CDMSID],
CASE
WHEN CM.COMPANYTYPE = 7 THEN '3W DEALER'
WHEN CM.COMPANYTYPE IN (1,8)  THEN 'MOTOR CYCLE'
WHEN CM.COMPANYTYPE = 2 AND CM.COMPANYSUBTYPE IS NULL THEN 'PROBIKING'
END AS CompanyType,
[EmployeeCode],
[FirstName],
[MiddleName],
[LastName],
[CreatedCompanyID],
[CreatedCompany],
CM.CODE AS DEALERCODE,
[Department],
[ContactGroupID],
[EmployeeGroup],
[DesignationID],
[Designation],
CMD.CompanyID,
[Company],
[BranchID],
[Branch],
CMD.IsActive,
[TrainingStatus],
[EmployeeCurrentStatus],
[BranchCategory],
[TypeOfOutlet],
GETDATE() AS Refresh_Date
FROM CDMS_MANPOWER_DATA CMD
JOIN  COMPANY_MASTER CM ON (CMD.COMPANYID = CM.COMPANYID)
WHERE CMD.IsActive = 'TRUE' AND CM.COMPANYTYPE IS NOT NULL AND CM.COMPANYTYPE IN (1,2,7,8);


;WITH CTE AS                  
 (                  
  SELECT *,                  
    ROW_NUMBER()OVER(PARTITION BY CompanyType, EmployeeCode, BranchID, CDMSID  ORDER BY EmployeeGroup )RNK                  
  FROM ASM_SERVICE_MANPOWER_MASTER_DIM
  WHERE ISACTIVE = 'TRUE'                
)    
DELETE FROM CTE                  

 WHERE RNK<>1;

-----------------------------LOAD INSTALL BASE MASTER DATA

TRUNCATE TABLE ASM_SERVICE_INSTALLBASE_MASTER_DIM

insert into ASM_SERVICE_INSTALLBASE_MASTER_DIM(
[PK_Ibid]
,[Invoicedate]
,[Vehicle_Aging]
,[RegistrationNo]
,[Chassis]
,[Refresh_Date]
)
 
select DISTINCT IBID
	  ,INVOICEDATE
	  ,CASE WHEN DATEDIFF(MM,CAST(INVOICEDATE AS DATE),GETDATE())>=0 AND DATEDIFF(MM,CAST(INVOICEDATE AS DATE),GETDATE())<12 THEN '0-1 yrs'
	        WHEN DATEDIFF(MM,CAST(INVOICEDATE AS DATE),GETDATE())>=12 AND DATEDIFF(MM,CAST(INVOICEDATE AS DATE),GETDATE())<24 THEN '1-2 yrs'
			WHEN DATEDIFF(MM,CAST(INVOICEDATE AS DATE),GETDATE())>=24 AND DATEDIFF(MM,CAST(INVOICEDATE AS DATE),GETDATE())<36 THEN '2-3 yrs'
			WHEN DATEDIFF(MM,CAST(INVOICEDATE AS DATE),GETDATE())>=36 AND DATEDIFF(MM,CAST(INVOICEDATE AS DATE),GETDATE())<48 THEN '3-4 yrs'
			WHEN DATEDIFF(MM,CAST(INVOICEDATE AS DATE),GETDATE())>=48 AND DATEDIFF(MM,CAST(INVOICEDATE AS DATE),GETDATE())<60 THEN '4-5 yrs'
			WHEN DATEDIFF(MM,CAST(INVOICEDATE AS DATE),GETDATE())>=60 THEN '>5 yrs' END AS Vehicle_Aging
	  ,UPPER(REGISTRATIONNO) RegistrationNo
	  ,TRIM(NAME) AS CHASSIS
	  ,getdate() as Refresh_Date
	  FROM INSTALL_BASE_MASTER

--UPDATE MISSING INVOICE DATE
SELECT PK_IBID,CAST(RH.DOCDATE AS DATE) RETAIL_DATE,
CASE WHEN DATEDIFF(MM,CAST(RH.DOCDATE AS DATE),GETDATE())>=0 AND DATEDIFF(MM,CAST(RH.DOCDATE AS DATE),GETDATE())<12 THEN '0-1 yrs'
	        WHEN DATEDIFF(MM,CAST(RH.DOCDATE AS DATE),GETDATE())>=12 AND DATEDIFF(MM,CAST(RH.DOCDATE AS DATE),GETDATE())<24 THEN '1-2 yrs'
			WHEN DATEDIFF(MM,CAST(RH.DOCDATE AS DATE),GETDATE())>=24 AND DATEDIFF(MM,CAST(RH.DOCDATE AS DATE),GETDATE())<36 THEN '2-3 yrs'
			WHEN DATEDIFF(MM,CAST(RH.DOCDATE AS DATE),GETDATE())>=36 AND DATEDIFF(MM,CAST(RH.DOCDATE AS DATE),GETDATE())<48 THEN '3-4 yrs'
			WHEN DATEDIFF(MM,CAST(RH.DOCDATE AS DATE),GETDATE())>=48 AND DATEDIFF(MM,CAST(RH.DOCDATE AS DATE),GETDATE())<60 THEN '4-5 yrs'
			WHEN DATEDIFF(MM,CAST(RH.DOCDATE AS DATE),GETDATE())>=60 THEN '>5 yrs' END AS Vehicle_Aging
INTO #MISSING_INVOICE_DATE
FROM ASM_SERVICE_INSTALLBASE_MASTER_DIM IBMD
LEFT JOIN RETAIL_LINE RL ON RL.IBID = IBMD.PK_Ibid
LEFT JOIN RETAIL_HEADER RH ON RH.HEADERID = RL.DOCID
WHERE IBMD.INVOICEDATE IS NULL AND RH.DOCTYPE IN (141,441,1000079,1000317,1012739)
AND RL.LINEID NOT IN (SELECT RRL.SALEINVOICELINEID FROM RETAIL_LINE_RETURN RRL JOIN RETAIL_LINE RL1 ON  RRL.SALEINVOICELINEID = RL1.LINEID)


UPDATE IBM1
SET IBM1.INVOICEDATE = ID.RETAIL_DATE,IBM1.Vehicle_Aging = ID.Vehicle_Aging
FROM ASM_SERVICE_INSTALLBASE_MASTER_DIM IBM1 INNER JOIN #MISSING_INVOICE_DATE ID ON ID.PK_IBID = IBM1.PK_IBID

------------------------------LOAD ITEM GROUP DETAIL MASTER DATA

TRUNCATE TABLE ITEM_GROUP_DETAIL_NEW

INSERT INTO ITEM_GROUP_DETAIL_NEW

SELECT DISTINCT ID,
ITEMID,
ITEMGROUPTYPE,
IMPORTEDDATE FROM ITEM_GROUP_DETAIL
WHERE CDMSUNIQUEID NOT IN (338717529)
AND ITEMGROUPID NOT IN  (13875)

----------------------------LOAD SERVICE NAMES FOR MC

TRUNCATE TABLE ASM_MC_SERVICE_CONTRACT_MASTER

INSERT INTO ASM_MC_SERVICE_CONTRACT_MASTER

SELECT DISTINCT SERVICECONTRACTID,
CODE,
CASE WHEN CODE IN ('PD001','00JR11','00JR11','ATW','INS-0001','SS001','EXP001','PDI','Secure AMC','AMC','FS001') THEN NAME ELSE 'Others' END AS SERVICENAME
FROM SERVICE_CONTRACT_MASTER

END

GO