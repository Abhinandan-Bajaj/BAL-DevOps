/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION		            */
/*--------------------------------------------------------------------------------------------------*/
/*	2024-07-29 	|	Ashwini Ahire		| Install_Base_Master --Added ProductionDate */
/*	                                      Item Master -- Newly Added for Phase3 for PartName [NEW]*/
/*                                         Service_Contract_Master- added 5YEW in Code Column        */
/*                                        Branch Master -- Added BranchType for Phase3 for MD,3S,2S  */
/*                                        Vendor Master -- Need VendorName for Vendor Master  [NEw]  */
/*                                        Defect Master-- Needed for Defect Description  [NEW]       */ 
/*  2024-08-06 |	Lachmanna		   | MANPOWER Master    -- we have excluded inactive employees and 
                                                          used the most recent employee information
/ *                                    MANPOWER Required Master --Added Manpower Required Info */
/*	2024-09-20 	|	Sarvesh Kulkarni		| Added City Name in branch_master */
/*	2025-02-03 	|	Dewang Makani		| New Master Created for SAP IBM data for IC ELF */
/*	2025-02-14 	|	Dewang Makani		| Added BU column in install base master */
/*                                                                                               */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/



SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Alter PROC [dbo].[USP_ASM_SERVICE_MASTER_REFRESH] AS
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
---Added BranchType for Phase3 for MD,3S,2S in R7

TRUNCATE TABLE ASM_SERVICE_BRANCH_MASTER_DIM
 
INSERT INTO ASM_SERVICE_BRANCH_MASTER_DIM
(
	BranchId,
	BranchName,
	BranchCode,
	TypeOfChannel,
	CompanyType,
    BranchType,
	Refresh_Date,
    cityname
)

SELECT DISTINCT
BM.BRANCHID,
CASE WHEN CM.COMPANYTYPE = 2 AND BM.[NAME] LIKE '%([0-9][0-9][0-9][0-9][0-9])' THEN left (BM.[NAME], len(BM.[NAME]) - 7)
ELSE BM.[NAME] END AS [BRANCH NAME],
--BM.CODE AS [BRANCH CODE],
CASE WHEN CM.COMPANYTYPE IN (1,2,8) AND BM.CODE LIKE '00000%' THEN SUBSTRING(BM.CODE,6,LEN(BM.CODE)) ELSE BM.CODE END AS [BRANCH CODE],
CASE WHEN BM.TYPEOFOUTLET LIKE '%ASD%' THEN 'ASD'
     WHEN BM.TYPEOFOUTLET LIKE 'MAIN%' THEN 'Main Dealership'
     WHEN BM.TYPEOFOUTLET LIKE 'BAL%' or BM.TYPEOFOUTLET LIKE 'Ship-%' THEN 'BAL Registered Branch'
     ELSE 'Others' END AS Typeofchannel,
CM.COMPANYTYPE,
Case when CM.COMPANYTYPE = 7 THEN
    CASE WHEN BM.TYPEOFOUTLET LIKE '%MAIN DEALERSHIP%' /*OR BM.OPERATIONS LIKE '%3S%'*/ THEN 'MAIN DEALERSHIP'
         WHEN BM.OPERATIONS LIKE '%3S%' THEN '3S'
         WHEN BM.OPERATIONS LIKE '%2S%' THEN '2S'
         ELSE 'OTHERS'
    END
end as BranchType,
GETDATE() AS Refresh_Date,
cityname
FROM BRANCH_MASTER BM
JOIN COMPANY_MASTER CM ON CM.COMPANYID=BM.COMPANYID AND CM.COMPANYTYPE IN (1,2,7,8)
WHERE CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)


-----------------------------LOAD MODEL MASTER DATA

Print('Truncating ASM_SERVICE_MODEL_MASTER_DIM table')
TRUNCATE TABLE ASM_SERVICE_MODEL_MASTER_DIM
Print('ASM_SERVICE_MODEL_MASTER_DIM table truncated')
Print('Inserting data in ASM_SERVICE_MODEL_MASTER_DIM table')

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
where zd.ZBU_TYPE in ('MC','CV','PB','PBK') and zd.ZBRAND1<>'TRIUMPH'
UNION
select ModelCode,modelid,ModelName,ModelFamily,Category,SubCategory,ModelActivation,BUCategory,CategoryICBU,SubBrand,Brand,Segment,BU,CC,date1
from(
SELECT  
distinct
      Case when LEN(B.MATNR)=8  then RIGHT(REPLICATE('0', 10) + LEFT(B.MATNR,6), 6)
        when LEN(B.MATNR) IN (6,7) THEN RIGHT(REPLICATE('0', 10) + LEFT(B.MATNR,4), 6) 
        when LEN(B.MATNR)=5 THEN RIGHT(REPLICATE('0', 10) + LEFT(B.MATNR,3), 6) END  AS ModelCode
      ,IM.ITEMID as modelid
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
	  ,getdate() as date1
	  ,ROW_NUMBER() over(partition by IM.ITEMID order by IM.importeddate desc) rnk
FROM SAP_ZBRAND_V_DETAIL zd
JOIN SAP_MAKT B ON zd.ZBRANDVARIANT=(CASE WHEN LEN(MATNR)=8 THEN SUBSTRING(MATNR,3,4) 
                         WHEN LEN(MATNR)=7 THEN CONCAT(0, SUBSTRING(MATNR,1,3)) 
					  WHEN LEN(MATNR)=5 THEN CONCAT(0, SUBSTRING(MATNR,1,3)) END)
JOIN ITEM_MASTER im on RIGHT(REPLICATE('0', 10) + im.code, 6) = Case when LEN(B.MATNR)=8  then RIGHT(REPLICATE('0', 10) + LEFT(B.MATNR,6), 6)
        when LEN(B.MATNR) IN (6,7) THEN RIGHT(REPLICATE('0', 10) + LEFT(B.MATNR,4), 6) 
        when LEN(B.MATNR)=5 THEN RIGHT(REPLICATE('0', 10) + LEFT(B.MATNR,3), 6) END
		and Im.ITEMGROUPTYPE=9
LEFT JOIN ITEM_MASTER_EXT IME ON IME.ITEMID = IM.ITEMID
WHERE zd.ZBU_TYPE in ('PB','PBK') and zd.ZBRAND1='TRIUMPH'
)a
where rnk=1

Print('Data inserted in ASM_SERVICE_MODEL_MASTER_DIM table')

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
FROM (select  ROW_NUMBER() OVER (PARTITION BY trim(FirstName), trim(MiddleName),trim(LastName),CreatedCompanyID,CDMSID,SkillSet,Designation,BranchID,contactgroupdetailID,AadharNo,
Mobile ORDER BY UPDATEDATE desc ) AS rnk,* from CDMS_MANPOWER_DATA) CMD 
JOIN  COMPANY_MASTER CM ON (CMD.COMPANYID = CM.COMPANYID)
WHERE CMD.IsActive = 'TRUE' AND CM.COMPANYTYPE IS NOT NULL AND CM.COMPANYTYPE IN (1,2,7,8) and rnk=1


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
,[ProductionDate]
,[Refresh_Date]
,[BU]
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
      ,DATEOFMFG AS ProductionDate
	  ,getdate() as Refresh_Date
	  ,CASE WHEN ITEMGROUPTYPE = '1' THEN 'MC'
			WHEN ITEMGROUPTYPE = '12' THEN 'CV'
			WHEN ITEMGROUPTYPE = '9' THEN 'PB'
			WHEN ITEMGROUPTYPE = '14' THEN 'UB'
			WHEN ITEMGROUPTYPE = '2' THEN 'UNKNOWN'
			ELSE NULL
	   END AS BU  -- Added on 14_02_2025
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
------Only added 5YEW in Code Column for Phase 3
TRUNCATE TABLE ASM_MC_SERVICE_CONTRACT_MASTER

INSERT INTO ASM_MC_SERVICE_CONTRACT_MASTER

SELECT DISTINCT SERVICECONTRACTID,
CODE,
CASE WHEN CODE IN ('PD001','00JR11','00JR11','ATW','INS-0001','SS001','EXP001','PDI','Secure AMC','AMC','FS001','5YEW') THEN NAME ELSE 'Others' END AS SERVICENAME
FROM SERVICE_CONTRACT_MASTER

--LOAD ITEM MASTER DATA
--New Dimension table for ItemName created for Phase 3

TRUNCATE TABLE ASM_SERVICE_ITEM_MASTER_DIM
 
INSERT INTO ASM_SERVICE_ITEM_MASTER_DIM(
[ItemID]
,[ItemCode]
,[ItemName]
,[Refresh_Date]
)
SELECT DISTINCT IM.ITEMID
		,IM.code AS ITEMCODE
		,IM.name AS ITEMNAME
		,getdate() AS Refresh_Date
FROM [dbo].[ITEM_MASTER] IM

-------Vendor Master

TRUNCATE TABLE ASM_SERVICE_VENDOR_MASTER_DIM
 
INSERT INTO ASM_SERVICE_VENDOR_MASTER_DIM(
[Itemid]
,[Itemcode]
,[Chassis]
,[VendorName]
,[Refresh_Date]
)
SELECT DISTINCT 
         IM.Itemid AS Itemid
		,SW.MATNR AS ITEMCODE
		,SW.CHASSIS AS Chassis
		,SW.DEB_NAME1 AS VENDORNAME
		,getdate() AS Refresh_Date
FROM [dbo].[SAP_YWTY_ANLTCS_VIW] SW
JOIN ITEM_MASTER IM on IM.CODE= SW.MATNR

--*****************************************************************
--Defect Master
--Added for Defect Description

TRUNCATE TABLE ASM_SERVICE_DEFECT_MASTER_DIM

INSERT INTO ASM_SERVICE_DEFECT_MASTER_DIM(
[DefectCode]
,[DefectDescription]
,[Refresh_Date]
)
SELECT DISTINCT 
		 CMM.Code AS DefectCode
		,CMM.Name AS DefectDescription
		,getdate() AS Refresh_Date
FROM [dbo].[COMPLAINT_MASTER] CMM
Where CMM.Complainttype = 'Part Defect Code'


---------Required script for manpower of the branch or MD

TRUNCATE TABLE dbo.ASM_SERVICE_CV_MANPOWER_REQUIRED_MASTER_DIM
INSERT INTO dbo.ASM_SERVICE_CV_MANPOWER_REQUIRED_MASTER_DIM
SELECT DISTINCT 
BM.COMPANYID,
BM.BRANCHID,
BM.NAME AS [BRANCH NAME],
CASE WHEN CM.COMPANYTYPE IN (1,8) AND BM.CODE LIKE '00000%' THEN SUBSTRING(BM.CODE,6,LEN(BM.CODE)) ELSE BM.CODE END AS [DealerCode],
CM.COMPANYTYPE,
TypeOfOutlet,
Operations,
ISMAINBRANCH,
GETDATE() AS Refresh_Date,
CASE
    WHEN typeofoutlet = 'Main Dealership' OR operations = 'Sales, Service, Spares (3S)' THEN 1
            ELSE null
        END AS WM_Req
,null as DSM 
,CASE
            WHEN typeofoutlet = 'Main Dealership' OR operations = 'Sales, Service, Spares (3S)' OR operations = 'Service & Spares (2S)' THEN 1
            ELSE null
       END AS tool_inc_Req
,CASE
    WHEN typeofoutlet = 'Main Dealership'  THEN 1
            ELSE null
        END  AS RB_Req
,CASE
    WHEN typeofoutlet = 'Main Dealership'  THEN 1
            ELSE null
        END  AS PartPic_Req 
FROM  Branch_master BM
JOIN COMPANY_MASTER CM ON CM.COMPANYID=BM.COMPANYID AND CM.COMPANYTYPE IN (7)
and BM.INACTIVE<>1

UPDATE b 
SET b.DSM =     CASE 
                WHEN d.total_Branch > 3 and  typeofoutlet = 'Main Dealership' THEN 1
                ELSE null
            END
from  ASM_SERVICE_CV_MANPOWER_REQUIRED_MASTER_DIM b  
left join (SELECT COMPANYID,COUNT(DISTINCT BRANCHID) AS total_Branch 
FROM ASM_SERVICE_CV_MANPOWER_REQUIRED_MASTER_DIM where CompanyType=7 
GROUP BY COMPANYID
having COUNT(DISTINCT BRANCHID)>3  ) d on d.COMPANYID=B.COMPANYID 


-----------------------------LOAD SAP INSTALL BASE MASTER DATA FOR IC ELF

TRUNCATE TABLE [dbo].[ASM_CV_SERVICE_SAP_YMFGT_CHASSIS_VODATE_DIM] 
INSERT INTO [dbo].[ASM_CV_SERVICE_SAP_YMFGT_CHASSIS_VODATE_DIM](
 [CHASSIS]
,[MODELID]
,[MODELCODE]
,[WERKS]
,[USAGE]
,[DATEOFMFG]
,[DATEOFINSPECTION]
,[DATEOFDESPATCH]
,[REFRESH_DATE]
)
SELECT DISTINCT 
VO.CHASSIS,
MM.MODELID,
VO.MATNR AS MODELCODE,
VO.WERKS AS MFG_PLANT,
CASE WHEN VO.STATUS_CD = 'D' THEN 'Domestic'
	 ELSE NULL
	 END AS USAGE,
CASE WHEN ISDATE(VO.VODATE) = 1 THEN FORMAT(CAST(VO.VODATE AS DATE), 'yyyy-MM-dd')
	 ELSE NULL
	 END AS DATEOFMFG,
CASE WHEN ISDATE(VO.INSDATE) = 1 THEN FORMAT(CAST(VO.INSDATE AS DATE), 'yyyy-MM-dd')
	 ELSE NULL
	 END AS DATEOFINSPECTION,
CASE WHEN ISDATE(VO.DESDATE) = 1 THEN FORMAT(CAST(VO.DESDATE AS DATE), 'yyyy-MM-dd')
	 ELSE NULL
	 END AS DATEOFDESPATCH,
GETDATE() AS REFRESH_DATE

FROM [SAP_YMFGT_CHASSIS_VODATE] VO
join [ASM_SERVICE_MODEL_MASTER_DIM] MM on MM.modelcode = LEFT(VO.MATNR,6)
WHERE 
VO.STATUS_CD = 'D' AND VO.WERKS IN ('WA10','WA31') 
AND FORMAT(CAST(VO.VODATE AS DATE), 'yyyy-MM-dd') >= '2022-04-01'

PRINT('ASM_CV_SERVICE_SAP_YMFGT_CHASSIS_VODATE_DIM LOADED')

END
GO