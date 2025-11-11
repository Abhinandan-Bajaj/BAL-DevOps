SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_MC_SERVICE_CWI_DEALERAMC_FULLLOAD] AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2025-01-31 	|	Sarvesh Kulkarni		| Added logic to populate Aggregare_fact table   */
/*	2024-05-10 	|	Sarvesh Kulkarni		| Added logic to identify the AMC redemption.   */
/*	2024-05-06 	|	Aakash Kundu		| Adding FK_Modelid for enabling model cut on dashbaord
     */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

TRUNCATE TABLE [dbo].[ASM_MC_CWI_STG]

INSERT INTO ASM_MC_CWI_STG

SELECT B.*
,CM.COMPANYID AS FK_Companyid
,BM.BRANCHID AS FK_Branchid
--INTO ASM_MC_CWI_STG
FROM
(SELECT DISTINCT CWI.PROGRAM AS Type
,CWI.PolicyNo AS FK_Docid
,CWI.InvoiceNo AS DOCNAME
,CAST(CWI.EnrollmentDate AS DATE) AS Docdate
--,CM.COMPANYID AS FK_Companyid
,IBM.IBID AS [FK_Ibid]
--,BM.Branchid AS FK_Branchid
,IBM.ITEMID AS FK_Modelid
,CWI.TaxableAmount AS Pretaxrevenue
,CWI.AmountPaid AS Posttaxrevenue
,CASE WHEN CWI.Dealercode LIKE '[0-9][0-9][0-9][0-9][0-9]' THEN CONCAT('00000',CWI.Dealercode)
      ELSE CONCAT('00000',RIGHT(CWI.Dealercode,5)) END AS Dealercode
,CASE WHEN CWI.Dealercode LIKE '[0-9][0-9][0-9][0-9][0-9]' THEN CONCAT('00000',CWI.Dealercode)
      ELSE CONCAT('00000',RIGHT(CWI.Dealercode,5)) END AS ASD_Dealercode
,CASE WHEN CWI.Dealercode LIKE '[0-9][0-9][0-9][0-9][0-9]' THEN CONCAT('00000',CWI.Dealercode)
      ELSE CWI.Dealercode END AS Branchcode
,TRIM(REPLACE(CWI.[CHASSISNO.],':','')) AS Chassis_CWI
,CAST(CWI.STARTDATE AS DATE) AS Vehicleinvoicedatetime
,case when CWI.invoicedate like '%/%/%' then try_CONVERT(DATE, CWI.invoicedate, 103) -- ODBC canonical
      when CWI.invoicedate like '%-%-%' then cast(CWI.invoicedate as date) END AS Billeddatetime
,CAST(CWI.ENDDATE AS DATE) AS ExpiryDate
,1 as COMPANYTYPE
,103 AS Service_Retail_TypeIdentifier
,GETDATE() AS Refresh_Date
--INTO ASM_CWI_STG
FROM EXT_CWI_REPORT_DATA CWI
--LEFT JOIN COMPANY_MASTER CM ON (CM.CODE=concat('00000',CWI.DealerCode) AND ISNULL(CAST(CM.IMPORTEDDATE AS DATE) ,'01/01/1900') = (SELECT ISNULL(MAX(CAST(CM1.IMPORTEDDATE AS DATE)),'01/01/1900') FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID))
--LEFT JOIN BRANCH_MASTER BM ON (BM.CODE = '00000'+CWI.DEALERCODE AND ISNULL(CAST(BM.IMPORTEDDATE AS DATE) ,'01/01/1900') = (SELECT ISNULL(MAX(CAST(BM1.IMPORTEDDATE AS DATE)),'01/01/1900') FROM BRANCH_MASTER BM1 WHERE BM.BRANCHID = BM1.BRANCHID))
LEFT JOIN INSTALL_BASE_MASTER IBM ON (IBM.NAME=TRIM(REPLACE(CWI.[CHASSISNO.],':','')) AND IBM.IMPORTEDDATE = (SELECT MAX(IBM1.IMPORTEDDATE) FROM INSTALL_BASE_MASTER IBM1 WHERE IBM1.NAME = IBM.NAME))
WHERE CWI.PROGRAM IN ('AMC','ATW','RSA'))B
LEFT JOIN COMPANY_MASTER CM ON (CM.CODE = B.Dealercode AND CM.COMPANYTYPE IN (1,8))
LEFT JOIN BRANCH_MASTER BM ON BM.CODE = B.Branchcode


----------------------------UPDATE ASD DEALERCODE MAPPING

SELECT * INTO #ServiceDealerMapping FROM
(SELECT DISTINCT ZF_ASC ASD_DEALERCODE,DEALER_CODE DEALERCODE
FROM SAP_ZSD_ASC_DETAIL
WHERE SER_STATUS = 'OPERATIONAL')T

UPDATE B
SET B.Dealercode=A.DEALERCODE
FROM ASM_MC_CWI_STG B
INNER JOIN #ServiceDealerMapping A ON B.ASD_DEALERCODE=A.ASD_DEALERCODE


-------------------------------------INSERT CWI DATA INTO FACT TABLE

DELETE FROM ASM_MC_SERVICE_FACT WHERE SERVICE_RETAIL_TYPEIDENTIFIER=103

INSERT INTO ASM_MC_SERVICE_FACT(Type,
FK_Docid,
DOCNAME,
Docdate,
FK_Companyid,
FK_Ibid,
FK_Modelid,
FK_Branchid,
Pretaxrevenue,
Posttaxrevenue,
Dealercode,
ASD_Dealercode,
Chassis_CWI,
Vehicleinvoicedatetime,
Billeddatetime,
ExpiryDate,
CompanyType,
Service_Retail_TypeIdentifier,
Refresh_Date)

SELECT 
Type,
FK_Docid,
DOCNAME,
Docdate,
FK_Companyid,
FK_Ibid,
FK_Modelid,
FK_Branchid,
Pretaxrevenue,
Posttaxrevenue,
Dealercode,
ASD_Dealercode,
Chassis_CWI,
Vehicleinvoicedatetime,
Billeddatetime,
ExpiryDate,
CompanyType,
Service_Retail_TypeIdentifier,
GETDATE() AS Refresh_Date
FROM ASM_MC_CWI_STG

Print('Deleted data from ASM_MC_SERVICE_FACT_AGR for 103 SERVICE_RETAIL_TYPEIDENTIFIER')
DELETE FROM ASM_MC_SERVICE_FACT_AGR WHERE SERVICE_RETAIL_TYPEIDENTIFIER=103

INSERT INTO ASM_MC_SERVICE_FACT_AGR(Type,
FK_Docid,
DOCNAME,
Docdate,
FK_Ibid,
FK_Modelid,
FK_Branchid,
Pretaxrevenue,
Posttaxrevenue,
Dealercode,
ASD_Dealercode,
Chassis_CWI,
Vehicleinvoicedatetime,
Billeddatetime,
ExpiryDate,
Service_Retail_TypeIdentifier,
Refresh_Date)

select 
Type,
FK_Docid,
DOCNAME,
Docdate,
FK_Ibid,
FK_Modelid,
FK_Branchid,
Pretaxrevenue,
Posttaxrevenue,
Dealercode,
ASD_Dealercode,
Chassis_CWI,
Vehicleinvoicedatetime,
Billeddatetime,
ExpiryDate,
Service_Retail_TypeIdentifier,
GETDATE() as Refresh_Date
from ASM_MC_CWI_STG

Print('Data inserted in ASM_MC_SERVICE_FACT_AGR table')
-------------------------------------------------------

--Loading Dealer AMC Data
TRUNCATE TABLE ASM_MC_DEALER_AMC_STG

INSERT INTO ASM_MC_DEALER_AMC_STG
SELECT DISTINCT 'DEALER AMC' as Type,
DOCNAME,
CAST(DOCDATE AS DATE) DOCDATE,
CAST(DOCDATE AS DATE) BILLEDDATETIME,
ACS.DEALERCODE AS DEALERCODE,
ACS.DEALERCODE AS ASD_DEALERCODE,
ACS.TOTALAMOUNT AS POSTTAXREVENUE,
(ACS.RATE - ACS.TRADEDISCOUNT) AS PRETAXREVENUE,
IBM.IBID AS FK_IBID,
BM.BRANCHID AS FK_BRANCHID,
IM.ITEMID AS FK_MODELID,
1 AS COMPANYTYPE,
104 as Service_Retail_TypeIdentifier
FROM AMC_CONTRACT_SALE ACS
JOIN BRANCH_MASTER BM ON BM.CODE = ACS.BRANCHCODE
LEFT JOIN ITEM_MASTER IM ON IM.CODE = ACS.MODELCODE
LEFT JOIN INSTALL_BASE_MASTER IBM ON TRIM(IBM.NAME) = TRIM(ACS.CHASSISNO)
WHERE CAST(DOCDATE AS DATE) >= '2022-04-01'

--------------------------------------------------------DEALER ASD MAPPING UPDATE
SELECT * INTO #ServiceDealerMapping1 FROM
(SELECT DISTINCT ZF_ASC ASD_DEALERCODE,DEALER_CODE DEALERCODE
FROM SAP_ZSD_ASC_DETAIL
WHERE SER_STATUS = 'OPERATIONAL')T

UPDATE B
SET B.Dealercode=A.DEALERCODE
FROM ASM_MC_DEALER_AMC_STG B
INNER JOIN #ServiceDealerMapping1 A ON B.ASD_DealerCode=A.ASD_DEALERCODE

------------------------------------------------------INSERT INTO FACT TABLE
DELETE FROM ASM_MC_SERVICE_FACT WHERE SERVICE_RETAIL_TYPEIDENTIFIER=104

INSERT INTO ASM_MC_SERVICE_FACT(Type,
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
ASD_DealerCode,
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
ASD_DealerCode,
GETDATE() AS Refresh_Date
FROM  ASM_MC_DEALER_AMC_STG


DELETE FROM ASM_MC_SERVICE_FACT_AGR WHERE SERVICE_RETAIL_TYPEIDENTIFIER=104
Print('Deleted data from ASM_MC_SERVICE_FACT_AGR for 104 SERVICE_RETAIL_TYPEIDENTIFIER')

INSERT INTO ASM_MC_SERVICE_FACT_AGR(Type,
DOCNAME,
Docdate,
FK_Ibid,
FK_Branchid,
FK_Modelid,
Pretaxrevenue,
DealerCode,
Billeddatetime,
Service_Retail_TypeIdentifier,
Posttaxrevenue,
ASD_DealerCode,
Refresh_Date)

select 
Type,
DOCNAME,
Docdate,
FK_Ibid,
FK_Branchid,
FK_Modelid,
Pretaxrevenue,
DealerCode,
Billeddatetime,
Service_Retail_TypeIdentifier,
Posttaxrevenue,
ASD_DealerCode,
GETDATE() Refresh_Date
from ASM_MC_DEALER_AMC_STG
Print('Data inserted in ASM_MC_SERVICE_FACT_AGR table')

--------------------------------------------------------------------------------------------------------
---------------------------------------------------AMC Redemption Caclulations-----------------------------
print('truncating ASM_MC_AMC_SERVICE')
TRUNCATE TABLE [ASM_MC_AMC_Service];
print('Loading data in ASM_MC_AMC_SERVICE')
Insert into [ASM_MC_AMC_Service]
Select circle,areaoffice,brand,policyno,policysolddate,dateofsale,dealercode,dealername,customername,mobile,modelname,[chassisno.],
[cardno.],odometerreading,startdate,enddate,enrollmentdate,invoiceno,invoicedate,mrp,taxableamount,cgst,sgst,amountpaid
,discounamt,AMC1ExpDate,AMC2ExpDate,AMC3ExpDate,AMC1Date,AMC1_kmreading,AMC2Date,AMC2_kmreading,AMC3Date,AMC3_kmreading,FK_Modelid,Branchcode
from
(select distinct CWI.circle,areaoffice,brand,policyno,cast(policysolddate as date)[policysolddate],
cast(dateofsale as date)[dateofsale],
COALESCE(m.Dealercode, CASE WHEN CWI.Dealercode LIKE '[0-9][0-9][0-9][0-9][0-9]' THEN CONCAT('00000',CWI.Dealercode)
      ELSE CWI.Dealercode END) as Dealercode---new logic
,CWI.dealername,customername,mobile,modelname,[chassisno.],
[cardno.],odometerreading,cast(startdate as date)[startdate],cast(enddate as date)[enddate],cast(enrollmentdate as date)[enrollmentdate],
CWI.invoiceno,CWI.invoicedate,
mrp,taxableamount,cgst,sgst,amountpaid,discounamt,
/*case when 
isnull(dateadd(day,(3333/nullif(odometerreading/nullif(datediff(day,dateofsale,enrollmentdate),0),0)),startdate),'2300-01-01')
< dateadd(month,4,cast(startdate as date)) then isnull(dateadd(day,(3333/nullif(odometerreading/nullif(datediff(day,dateofsale,enrollmentdate),0),0)),startdate),'2300-01-01')
else dateadd(month,4,cast(startdate as date))
end */
dateadd(month,4,cast(startdate as date)) as AMC1ExpDate,
/*case when 
isnull(dateadd(day,(6666/nullif(odometerreading/nullif(datediff(day,dateofsale,enrollmentdate),0),0)),startdate),'2300-01-01')
< dateadd(month,8,cast(startdate as date)) then isnull(dateadd(day,(6666/nullif(odometerreading/nullif(datediff(day,dateofsale,enrollmentdate),0),0)),startdate),'2300-01-01')
else dateadd(month,8,cast(startdate as date))
end
*/
dateadd(month,8,cast(startdate as date)) as AMC2ExpDate,
/*case when 
isnull(dateadd(day,(10000/nullif(odometerreading/nullif(datediff(day,dateofsale,enrollmentdate),0),0)),startdate),'2300-01-01')
< dateadd(month,12,cast(startdate as date)) then isnull(dateadd(day,(10000/nullif(odometerreading/nullif(datediff(day,dateofsale,enrollmentdate),0),0)),startdate),'2300-01-01')
else dateadd(month,12,cast(startdate as date))
end */
dateadd(month,12,cast(startdate as date)) as AMC3ExpDate,
AMC1Date = null,
AMC1_kmreading = null,
AMC2Date = null,
AMC2_kmreading = null,
AMC3Date = null,
AMC3_kmreading = null,
IBM.ITEMID AS FK_Modelid,
CASE WHEN CWI.Dealercode LIKE '[0-9][0-9][0-9][0-9][0-9]' THEN CONCAT('00000',CWI.Dealercode)
      ELSE CWI.Dealercode END AS Branchcode,
row_number() over (partition by [chassisno.] order by startdate desc)[Rank]
from ext_cwi_report_data CWI
LEFT JOIN INSTALL_BASE_MASTER IBM ON (IBM.NAME=TRIM(REPLACE(CWI.[CHASSISNO.],':','')) AND IBM.IMPORTEDDATE = (SELECT MAX(IBM1.IMPORTEDDATE) FROM INSTALL_BASE_MASTER IBM1 WHERE IBM1.NAME = IBM.NAME))
-----------------------------------------
LEFT JOIN dealer_asd_mapping m on 
CASE WHEN LEFT(CWI.Dealercode, 1) NOT LIKE '[A-Za-z]%' 
           THEN CONCAT('00000', CWI.Dealercode)
           ELSE CWI.Dealercode
       END = m.SAP_Code

where program = 'amc')DT
where [Rank] = 1

----------------------- AMC Service Date Update
--AMC First service Date
print('Calculating first AMC redemption')

SELECT distinct ib.name[chassis]
,CAST(SH.DOCDATE AS DATE) AS AMCFS_DATE,SH.USAGEREADING AS AMC1_km
into #amc1
FROM SERVICE_HEADER SH
join install_base_master ib 
on ib.ibid = sh.ibid
JOIN [ASM_MC_AMC_Service] ac ON (ac.[chassisno.]=ib.name and ac.startdate <= sh.docdate)
join service_line sl on sh.headerid = sl.docid
join item_master im on sl.itemid = im.itemid
WHERE SH.CONTRACTTYPEID IN (193) AND 
SH.CANCELLATIONDATE IS NULL
AND ib.IMPORTEDDATE = (SELECT MAX(ib1.IMPORTEDDATE) FROM install_base_master ib1 WHERE ib.name = ib1.name)
and im.code = 'Secure-001'


UPDATE B
SET B.AMC1Date=A.AMCFS_DATE,B.AMC1_kmreading = A.AMC1_km
FROM [ASM_MC_AMC_Service] B
JOIN #amc1 A ON A.[chassis]=B.[chassisno.]

print('Calculating second AMC redemption')
--AMC Second service Date
SELECT distinct ib.name[chassis]
,CAST(SH.DOCDATE AS DATE) AS AMCSS_DATE,SH.USAGEREADING AS AMC2_km
into #amc2
FROM SERVICE_HEADER SH
join install_base_master ib 
on ib.ibid = sh.ibid
JOIN [ASM_MC_AMC_Service] ac ON (ac.[chassisno.]=ib.name and ac.startdate <= sh.docdate)
join service_line sl on sh.headerid = sl.docid
join item_master im on sl.itemid = im.itemid
WHERE SH.CONTRACTTYPEID IN (193) AND 
SH.CANCELLATIONDATE IS NULL
AND ib.IMPORTEDDATE = (SELECT MAX(ib1.IMPORTEDDATE) FROM install_base_master ib1 WHERE ib.name = ib1.name)
and im.code = 'Secure-002'


UPDATE B
SET B.AMC2Date=A.AMCSS_DATE,B.AMC2_kmreading = A.AMC2_km
FROM [ASM_MC_AMC_Service] B
JOIN #amc2 A ON A.[chassis]=B.[chassisno.]

print('Calculating third AMC redemption')
--AMC3
SELECT distinct ib.name[chassis]
,CAST(SH.DOCDATE AS DATE) AS AMCTS_DATE,SH.USAGEREADING AS AMC3_km
into #amc3
FROM SERVICE_HEADER SH
join install_base_master ib 
on ib.ibid = sh.ibid
JOIN [ASM_MC_AMC_Service] ac ON (ac.[chassisno.]=ib.name and ac.startdate <= sh.docdate)
join service_line sl on sh.headerid = sl.docid
join item_master im on sl.itemid = im.itemid
WHERE SH.CONTRACTTYPEID IN (193) AND 
SH.CANCELLATIONDATE IS NULL
AND ib.IMPORTEDDATE = (SELECT MAX(ib1.IMPORTEDDATE) FROM install_base_master ib1 WHERE ib.name = ib1.name)
and im.code = 'Secure-003'


UPDATE B
SET B.AMC3Date=A.AMCTS_DATE,B.AMC3_kmreading = A.AMC3_km
FROM [ASM_MC_AMC_Service] B
JOIN #amc3 A ON A.[chassis]=B.[chassisno.]

------
--ASM_Service_Flag
print('Trucating AMC_SERVICE_FLAG')
truncate table [ASM_MC_AMC_Service_Flags];
insert into [ASM_MC_AMC_Service_Flags]
(
[circle],
[areaoffice],
[brand],
[policyno],
[policysolddate],
[dateofsale],
[dealercode],
[dealername],
[customername],
[mobile],
[modelname],
[chassisno.],
[cardno.],
[odometerreading],
[startdate],
[enddate],
[enrollmentdate],
[invoiceno],
[invoicedate],
[mrp],
[taxableamount],
[cgst],
[sgst],
[amountpaid],
[discounamt],
[AMC1ExpDate],
[AMC2ExpDate],
[AMC3ExpDate],
[AMC1Date],
[AMC1_kmreading],
[AMC2Date],
[AMC2_kmreading],
[AMC3Date],
[AMC3_kmreading],
[AMC1_Red_Flag],
[AMC2_Red_Flag],
[AMC3_Red_Flag],
[FK_Branchid],
[FK_Modelid]
)
select 
[circle],
[areaoffice],
[brand],
[policyno],
[policysolddate],
[dateofsale],
[dealercode],
[dealername],
[customername],
[mobile],
[modelname],
[chassisno.],
[cardno.],
[odometerreading],
[startdate],
[enddate],
[enrollmentdate],
[invoiceno],
[invoicedate],
[mrp],
[taxableamount],
[cgst],
[sgst],
[amountpaid],
[discounamt],
[AMC1ExpDate],
[AMC2ExpDate],
[AMC3ExpDate],
[AMC1Date],
[AMC1_kmreading],
[AMC2Date],
[AMC2_kmreading],
[AMC3Date],
[AMC3_kmreading],
case 
    when amc1date is not null then 'Done'
    when startdate<= getdate() and getdate()<=amc1expdate and amc1date is null then 'Due'
else null
end as amc1_red_flag,

case 
    when amc2date is not null then 'Done'
    when amc1expdate<getdate() and getdate() <=amc2expdate and amc1date is null then 'Due'
else null
end as amc2_red_flag,

case 
    when amc3date is not null then 'Done'
    when amc2expdate<getdate()and getdate()<=amc3expdate and amc3date is null then 'Due'
else null
end as amc3_red_flag,
BM.BRANCHID,
ASM_MC_AMC_Service.FK_Modelid
from ASM_MC_AMC_Service
LEFT JOIN BRANCH_MASTER BM ON BM.CODE = ASM_MC_AMC_Service.Branchcode
print('Dropping temp tables')
drop table #amc1
drop table #amc2
drop table #amc3


drop table #ServiceDealerMapping

END
GO