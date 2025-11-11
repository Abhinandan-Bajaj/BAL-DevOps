SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_MC_SERVICE_SERVICE_FULLLOAD2] AS 

BEGIN

/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION					*/
/*--------------------------------------------------------------------------------------------------*/
/*	2024-06-19 	|	Sarvesh Kulkarni		| Added required columns for RJ report and PDT/PDC calculations & bucket*/
/*	2024-12-02 	|	Ashwini Ahire 		| Added required columns for KPI Custom */
/*	2025-02-20 	|	Sarvesh Kulkarni 		| Added changes for Agr Fact load */
/*	2025-02-20 	|	Sarvesh Kulkarni 		| Added changes for SDT <3 Hrs Changes */
/*	2025-06-13 	|	Dewang Makani 		| Added KPI Custom Line level report columns */
/* 2025-10-13 | Rashi Pradhan   | AMC date update for 10:25 prod issue */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

---------------------INSERT SERVICE DATA

DELETE FROM ASM_MC_SERVICE_FACT WHERE SERVICE_RETAIL_TYPEIDENTIFIER=101

INSERT INTO ASM_MC_SERVICE_FACT(Type,
FK_Contracttypeid,
FK_PartContracttypeid,
Lineid,
FK_Docid,
DOCNAME,
Docdate,
FK_Companyid,
FK_Contactid,
Isclosed,
FK_Itemid,
FK_Ibid,
FK_Branchid,
FK_Modelid,
COMPANYTYPE,
Isrevisited,
Isrepeated,
ReasonForDelay,
Repeat_Type,
MechanicalSameDayFlag,
AccidentalFlag,
Mechanical3HrsFlag,
Pdt_Flag,
Pdc_Flag,
TAT_Days,
Tat_Delivery,
Pretaxrevenue,
Itemgrouptype,
Bgo_Category,
PaidFlag,
ServiceType,
DealerCode,
Importeddate,
Vehicleinvoicedatetime,
Billeddatetime,
[READYFORBILLDATETIME],
[ESTTIMEGIVENTOCUSTOMER],
[TOTALAMOUNT],
[TOTALOFESTIMATEDCOST],
Service_Retail_TypeIdentifier,
Posttaxrevenue,
ASD_DealerCode,
OpenJC_Buckets_MC,
closeJC_Buckets_MC,
[3rdFS_To_1stPS],
Technician,
Service_Advisor,
Refresh_Date,
PDC_deviation_perc,
PDT_deviation_perc,
PDC_deviation_buckets,
PDT_deviation_buckets,
repeated_from_lined,
repeated_from_docname,
repeated_from_docdate,
DefectCode,
Job_Card_Source,
Usagereading,
Qty,
Rate,
TradeDiscount,
TOTALTAX,
Surveyor,
Insurance_Provider,
Campaign,
KM_Range,
Amc_date

)

SELECT Type,
FK_Contracttypeid,
FK_PartContracttypeid,
Lineid,
FK_Docid,
DOCNAME,
Docdate,
FK_Companyid,
FK_Contactid,
Isclosed,
FK_Itemid,
FK_Ibid,
FK_Branchid,
FK_Modelid,
COMPANYTYPE,
Isrevisited,
Isrepeated,
ReasonForDelay,
Repeat_Type,
MechanicalSameDayFlag,
AccidentalFlag,
Mechanical3HrsFlag,
CASE WHEN READYFORBILLDATETIME <= ESTTIMEGIVENTOCUSTOMER THEN 1 ELSE 0 END AS Pdt_Flag,
CASE WHEN -10<=PDC_deviation_perc and PDC_deviation_perc<= 10 THEN 1 ELSE 0 END AS Pdc_Flag,
TAT_Days,
Tat_Delivery,
Pretaxrevenue,
Itemgrouptype,
Bgo_Category,
PaidFlag,
ServiceType,
DealerCode,
Importeddate,
Vehicleinvoicedatetime,
Billeddatetime,
[READYFORBILLDATETIME],
[ESTTIMEGIVENTOCUSTOMER],
[TOTALAMOUNT],
[TOTALOFESTIMATEDCOST],
Service_Retail_TypeIdentifier,
Posttaxrevenue,
ASD_DealerCode,
CASE WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE())<=3 THEN '<3 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 7 THEN '3-7 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 15 THEN '7-15 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 30 THEN '15-30 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 60 THEN '30-60 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 90 THEN '60-90 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) < 120 THEN '90-120 Days'
WHEN ARS.ISCLOSED=0 AND DATEDIFF(D,CAST(DOCDATE AS DATE),GETDATE()) >= 120 THEN '>= 120 Days' END AS OpenJC_Buckets_MC,
closeJC_Buckets_MC,
[3rdFS_To_1stPS],
Technician,
Service_Advisor,
GETDATE() AS Refresh_Date,
PDC_deviation_perc,
PDT_deviation_perc,
CASE
    WHEN PDC_deviation_perc<-25 THEN '<-25%'
    WHEN -25 <= PDC_deviation_perc AND PDC_deviation_perc <-10 THEN '-25% to -10%'
    WHEN -10 <= PDC_deviation_perc AND PDC_deviation_perc < 0 THEN '-10% to 0%'
    WHEN  0 <= PDC_deviation_perc AND PDC_deviation_perc <= 10 THEN '0% to 10%'
    WHEN  10 < PDC_deviation_perc AND PDC_deviation_perc <= 25 THEN '10% to 25%'
    WHEN  25 <=PDC_deviation_perc THEN '>25%'
END as 'PDC_deviation_buckets',
CASE
    WHEN abs(PDT_deviation_perc)<= 10 THEN '<10%'
    WHEN -10 < abs(PDT_deviation_perc) AND abs(PDT_deviation_perc) <=25 THEN '10% to 25%'
    WHEN 25 < abs(PDT_deviation_perc) AND abs(PDT_deviation_perc) <= 50 THEN '25% to 50%'
    WHEN 50 < abs(PDT_deviation_perc) AND abs(PDT_deviation_perc) <= 75 THEN '50% to 75%'
    WHEN 75 <abs(PDT_deviation_perc) THEN '>75%'
END as 'PDT_deviation_buckets',
repeated_from_lined,
repeated_from_docname,
repeated_from_docdate,
DefectCode,
Job_Card_Source,
Usagereading,
Qty,
Rate,
TradeDiscount,
TOTALTAX,
Surveyor,
Insurance_Provider,
Campaign,
CASE
    WHEN ARS.Usagereading <= 100 THEN '<= 100'
    WHEN ARS.Usagereading >100 and ARS.Usagereading <=500 THEN '101-500'
    WHEN ARS.Usagereading >500 and ARS.Usagereading <=1000 THEN '501-1000'
    WHEN ARS.Usagereading >1000 and ARS.Usagereading <=3000 THEN '1001-3000'
    WHEN ARS.Usagereading >3000 and ARS.Usagereading <=5000 THEN '3001-5000'
    WHEN ARS.Usagereading >5000 and ARS.Usagereading <=10000 THEN '5001-10000'
    WHEN ARS.Usagereading >10000 and ARS.Usagereading <=20000 THEN '10001-20000'
    WHEN ARS.Usagereading >20000 and ARS.Usagereading <=30000 THEN '20001-30000'
    WHEN ARS.Usagereading >30000 THEN '> 30000'
END as KM_Range,
Amc_date


FROM ASM_MC_SERVICE_STG ARS
WHERE ARS.DELETE_FLAG<>1
and ARS.CANCELLATIONDATE is null
PRINT 'Service Data inserted into fact table' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

print('Service Data inserted into fact table');

DELETE FROM ASM_MC_SERVICE_FACT_AGR WHERE SERVICE_RETAIL_TYPEIDENTIFIER=101
PRINT 'Data deleted from ASM_MC_SERVICE_FACT_AGR' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

INSERT INTO ASM_MC_SERVICE_FACT_AGR(Type,
FK_Contracttypeid,
FK_PartContracttypeid,
FK_Docid,
DOCNAME,
Docdate,
FK_Contactid,
Isclosed,
FK_Ibid,
FK_Branchid,
FK_Modelid,
Isrevisited,
Isrepeated,
ReasonForDelay,
Repeat_Type,
MechanicalSameDayFlag,
AccidentalFlag,
Mechanical3HrsFlag,
Pdt_Flag,
Pdc_Flag,
TAT_Days,
Tat_Delivery,
Pretaxrevenue,
Itemgrouptype,
Bgo_Category,
PaidFlag,
ServiceType,
[Dealercode],
Vehicleinvoicedatetime,
Billeddatetime,
Service_Retail_TypeIdentifier,
Posttaxrevenue,
OpenJC_Buckets_MC,
closeJC_Buckets_MC,
[3rdFS_To_1stPS],
Technician,
Service_Advisor,
Refresh_Date,
ASD_Dealercode,
PDC_deviation_buckets,
PDT_deviation_buckets,
Amc_date
)

SELECT 
Type,
FK_Contracttypeid,
FK_PartContracttypeid,
FK_Docid,
DOCNAME,
Docdate,
FK_Contactid,
Isclosed,
FK_Ibid,
FK_Branchid,
FK_Modelid,
Isrevisited,
MAX(Isrepeated) AS Isrepeated,
ReasonForDelay,
Repeat_Type,
MechanicalSameDayFlag,
AccidentalFlag,
Mechanical3HrsFlag,
Pdt_Flag,
Pdc_Flag,
TAT_Days,
Tat_Delivery,
SUM(Pretaxrevenue) AS Pretaxrevenue,
Itemgrouptype,
Bgo_Category,
PaidFlag,
ServiceType,
Dealercode,
Vehicleinvoicedatetime,
Billeddatetime,
Service_Retail_TypeIdentifier,
SUM(Posttaxrevenue) AS Posttaxrevenue,
OpenJC_Buckets_MC,
closeJC_Buckets_MC,
[3rdFS_To_1stPS],
Technician,
Service_Advisor,
GETDATE() AS Refresh_Date,
ASD_Dealercode,
PDC_deviation_buckets,
PDT_deviation_buckets,
Amc_date
FROM ASM_MC_SERVICE_FACT ARS
where Service_Retail_TypeIdentifier=101
GROUP BY
Type,
FK_Contracttypeid,
FK_PartContracttypeid,
FK_Docid,
DOCNAME,
Docdate,
FK_Contactid,
Isclosed,
FK_Ibid,
FK_Branchid,
FK_Modelid,
Isrevisited,
ReasonForDelay,
Repeat_Type,
MechanicalSameDayFlag,
AccidentalFlag,
Mechanical3HrsFlag,
Pdt_Flag,
Pdc_Flag,
TAT_Days,
Tat_Delivery,
Itemgrouptype,
Bgo_Category,
PaidFlag,
ServiceType,
Dealercode,
Vehicleinvoicedatetime,
Billeddatetime,
Service_Retail_TypeIdentifier,
[3rdFS_To_1stPS],
Technician,
Service_Advisor,
ASD_Dealercode,
PDC_deviation_buckets,
PDT_deviation_buckets,
OpenJC_Buckets_MC,
closeJC_Buckets_MC,
Amc_date;
PRINT 'Service Data inserted into aggregate fact table' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

PRINT 'Script Execution completed' +       CONVERT(VARCHAR, DATEADD(MINUTE, 330, GETDATE()))

END
GO