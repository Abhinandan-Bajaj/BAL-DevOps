SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[USP_ASM_PB_SERVICE_APP_FULLLOAD]
AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			    */
/*--------------------------------------------------------------------------------------------------*/
/*	2025-01-03 	|	Richa	  | New SP for Service App Dashboard     */              
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/


TRUNCATE TABLE ASM_PB_SERVICE_ORDER_DIM

INSERT INTO ASM_PB_SERVICE_ORDER_DIM(
[DealerCode],
[BranchId],
[Job_card_name],
[Registration_no],
[Job_card_date],
[Model],
[Chassis_no],
[Customer_name],
[Mobile_no],
[City],
[Job_type],
[Ready_for_bill],
[Total_amount],
[Online_payment],
[is_paid],
[is_pickup_drop],
[is_repair_stage],
[is_amount_revised],
[is_tat_revised],
[Refresh_Date],
[ImportedDate]
)
select 
CM.CODE AS DealerCode,
STG.FK_Branchid AS BranchId,
STG.DocName AS Job_card_name,
CASE WHEN IBM.ItemGroupType = 9 THEN IBM.CODE ELSE NULL END  AS Registration_no,
STG.DocDate AS Job_card_date,
IM.ITEMID AS Model, ---ITEMID FOR ID
IBM.NAME AS Chassis_no,
CN.NAME AS Customer_name,
CN.Mobile AS Mobile_no,
AM.NAME AS City,
SCM.NAME AS Job_type,
NULL AS Ready_for_bill,
SUM((STG.QTY*STG.RATE)+ ISNULL(STG.TOTALTAX,0)) AS Total_amount,
CASE WHEN PD.JobCardId IS NOT NULL THEN 'True' ELSE 'False' END  AS Online_payment,
NULL AS is_paid,
Null as is_pickup_drop,
Null as is_repair_stage,
 CASE 
        WHEN 
            SUM((STG.QTY * STG.RATE) + ISNULL(STG.TOTALTAX, 0)) > 0 AND
            (
                ISNULL(SUM(ISNULL(AV.PartCost, 0) + ISNULL(AV.LabourCost, 0)), 0) +
                ISNULL(SUM(ISNULL(MSP.PartCost, 0)), 0) +
                ISNULL(SUM(
                    CASE 
                        WHEN ISNULL(PDS.IsSelected, 0) = 1 THEN PDS.Pricing
                        ELSE 0
                    END
                ), 0)
            ) > 0 AND
            (
                ISNULL(SUM(ISNULL(AV.PartCost, 0) + ISNULL(AV.LabourCost, 0)), 0) +
                ISNULL(SUM(ISNULL(MSP.PartCost, 0)), 0) +
                ISNULL(SUM(
                    CASE 
                        WHEN ISNULL(PDS.IsSelected, 0) = 1 THEN PDS.Pricing
                        ELSE 0
                    END
                ), 0)
            ) <> SUM((STG.QTY * STG.RATE) + ISNULL(STG.TOTALTAX, 0))
        THEN 1
        ELSE 
            CASE 
                WHEN ISNULL(REN.IsSyced, 0) = 1 THEN 1
                ELSE 0
            END
    

END AS is_amount_revised,
Null as is_tat_revised,
GETDATE() AS Refresh_Date
,STG.Importeddate
FROM
ASM_PB_SERVICE_STG STG

INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=STG.FK_Companyid AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)AND CM.COMPANYTYPE IN (2)) 
Left JOIN INSTALL_BASE_MASTER IBM ON IBM.IBID=STG.FK_Ibid 
Left JOIN ITEM_MASTER IM ON IBM.ITEMID=IM.ITEMID  
LEFT JOIN CONTACT_MASTER CN ON CN.CONTACTID=STG.FK_Contactid
LEFT JOIN  AREA_MASTER AM ON CN.CITYID=AM.AREAMASTERID
LEFT JOIN SERVICE_CONTRACT_MASTER SCM  ON STG.FK_Contracttypeid = SCM.ID
LEFT JOIN CDMS_SERVICE_PAYMENT_DETAILS PD ON PD.JobCardId=STG.FK_Docid
LEFT JOIN CDMS_APPOINTMENT_HEADER AH ON AH.JobCardId=STG.FK_Docid
LEFT JOIN CDMS_ADDITIONAL_VALUEADDED_JOBDATA AV ON AH.HeaderID = AV.AppointmentDocID
LEFT JOIN CDMS_MENU_SERVPARTS_BOOKING MSP ON AH.HeaderID = MSP.AppointmentDocID
LEFT JOIN CDMS_PICKUPDROP_SLABSINFO_BOOKING PDS ON AH.HeaderID = PDS.AppointmentDocID
LEFT JOIN CDMS_REVISED_ESTIMATION_NOITIFICATION REN ON REN.JobCardId=STG.FK_Docid

where  Cast(STG.DocDate as Date) >= '2022-01-01'
and Upper(IM.Name) Not like 'HUSQVARNA%'
GROUP BY
CM.CODE ,
STG.FK_Branchid,
STG.DocName,
IBM.CODE ,
STG.DocDate,
IM.ITEMID,
IBM.NAME,
CN.NAME,
CN.Mobile,
AM.NAME,
SCM.NAME,
--SH.ISREADYFORINVOICE, SH.DeliveredDateTime,---TO ADD ISREADYFORINVOICE AND DeliveredDateTime IN STG TABLE
PD.JobCardId,
AV.PartCost,AV.LabourCost,
MSP.PartCost, 
PDS.IsSelected, PDS.Pricing,
IBM.ItemGroupType,
REN.IsSyced,
STG.ImportedDate


--------------APPOINTMENT------------------------

TRUNCATE TABLE ASM_PB_SERVICE_APPOINTMENT_DIM
INSERT INTO ASM_PB_SERVICE_APPOINTMENT_DIM(

[Dealer]
,[Branch]
,[DocumentName]
,[RegistrationNo]
,[ChassisNo]
,[Model]
,[CustomerName]
,[MobileNo]
,[BookingDate]
,[BookingCancelledDate]
,[PickUpDrop]
,[BookingAmount]
,[BookingSource]
,[City]
,[ServiceAdvisor]
,[JobType]
,[Status]
,[ReadyForBill]
,[JobCardName]
,[JobCardDate]
,[JCAmount]
,[TotalAmount]
,[OnlinePayment]
,[IsPaid]
,[RevisedEstimate]
,[Refresh_Date]
,[ImportedDate]
)
SELECT
CM.CODE AS Dealer,
STG.FK_Branchid AS BranchId,
AH.DocName AS DocumentName,
CASE WHEN IBM.ItemGroupType = 9 THEN IBM.CODE ELSE NULL END  AS Registration_no,
IBM.NAME AS Chassis_no,
IM.ITEMID AS Model,
CN1.NAME AS Customer_name,
CN1.Mobile AS Mobile_no,
AH.AppointmentDate AS BookingDate,
AH.CancellationDate AS BookingCancelledDate,
AHE.IsPickupDrop AS PickUpDrop,
ISNULL(SUM(ISNULL(AV.PartCost, 0) + ISNULL(AV.LabourCost, 0)), 0) +
    ISNULL(SUM(ISNULL(MSP.PartCost, 0)), 0) +
    ISNULL(SUM(CASE WHEN ISNULL(PDS.IsSelected, 0) = 1 THEN ISNULL(PDS.Pricing, 0) ELSE 0 END), 0) AS BookingAmount,
AHE.BookingSource,
AM.NAME AS City,
CN2.NAME AS ServiceAdvisor,
SCM.NAME AS JobType,
(case when ISNULL(AH.IsClosed,0) = 'True' then
		(Case when AH.CancellationDate is not null then 
		(Case when AH.CancellationType = 'Not Reported' then 'Not Reported' else 'Cancelled' end) 
		else 'Confirmed' end)
	else
	(case
		when Cast( AH.AppointmentDate as Date) < Cast(GetDate() as date) then 'Not Reported'
		when Cast( AH.AppointmentDate as Date) >= Cast(GetDate() as date) 
		then (case when ISNULL(AHE.IsBookingConfirmed,0) = 'True' then 'Confirmed'
		else 'Pending for Confirmation' end)
	end)
end) AS Status,
NULL AS ReadyForBill,
STG.DocName AS JobCardName,
STG.DocDate AS JobCardDate,
SUM((STG.QTY*STG.RATE)+ ISNULL(STG.TOTALTAX,0)) AS JCAmount,
SUM((STG.QTY*STG.RATE)+ ISNULL(STG.TOTALTAX,0)) AS TotalAmount,
CASE WHEN PD.JobCardId IS NOT NULL THEN 'True' ELSE 'False' END  AS OnlinePayment,
NULL AS IsPaid,
--REN.IsSyced AS RevisedEstimate,
CASE WHEN ISNULL(REN.IsSyced,0) = 1 then 'True' else 'False' END AS RevisedEstimate,
GETDATE() AS Refresh_Date,
AH.ImportedDate

FROM
CDMS_APPOINTMENT_HEADER AH
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID=AH.CompanyID AND CM.IMPORTEDDATE = (SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID)AND CM.COMPANYTYPE IN (2))
--LEFT JOIN BRANCH_MASTER BM ON AH.BRANCHID=BM.BranchID
Left JOIN INSTALL_BASE_MASTER IBM ON IBM.IBID=AH.IBID --AND IBM.ITEMGROUPTYPE=9
Left JOIN ITEM_MASTER IM ON IBM.ITEMID=IM.ITEMID 
LEFT JOIN CONTACT_MASTER CN1 ON CN1.CONTACTID=AH.CONTACTID
LEFT JOIN CDMS_APPOINTMENT_HEADER_EXT AHE ON AH.HeaderID=AHE.HeaderID
LEFT JOIN CDMS_ADDITIONAL_VALUEADDED_JOBDATA AV ON AH.HeaderID = AV.AppointmentDocID
LEFT JOIN CDMS_MENU_SERVPARTS_BOOKING MSP ON AH.HeaderID = MSP.AppointmentDocID
LEFT JOIN CDMS_PICKUPDROP_SLABSINFO_BOOKING PDS ON AH.HeaderID = PDS.AppointmentDocID
LEFT JOIN  AREA_MASTER AM ON CN1.CITYID=AM.AREAMASTERID
LEFT JOIN CONTACT_MASTER CN2 ON CN2.CONTACTID=AHE.SalesPersonID
LEFT JOIN SERVICE_CONTRACT_MASTER SCM ON AH.ContractTypeID=SCM.SERVICECONTRACTID
LEFT JOIN ASM_PB_SERVICE_STG STG ON AH.JobCardID=STG.FK_Docid
--LEFT JOIN SERVICE_LINE STG ON STG.DOCID = AH.HEADERID
LEFT JOIN CDMS_SERVICE_PAYMENT_DETAILS PD ON PD.JobCardId=AH.JobCardID
LEFT JOIN CDMS_REVISED_ESTIMATION_NOITIFICATION REN ON REN.JobCardId=AH.JobCardID
WHERE
 Cast( AH.AppointmentDate as Date) >= '2022-01-01'
 and Upper(IM.Name) Not like 'HUSQVARNA%'

GROUP BY
CM.CODE ,
STG.FK_Branchid,
AH.DocName ,
IBM.CODE,
IBM.NAME,
IM.ITEMID,
CN1.NAME ,
CN1.Mobile ,
AH.AppointmentDate ,
AH.CancellationDate ,
AHE.IsPickupDrop ,
AV.PartCost,AV.LabourCost,
MSP.PartCost, 
PDS.IsSelected, PDS.Pricing, 
AHE.BookingSource,
AM.NAME,
CN2.NAME ,
SCM.NAME,
AH.IsClosed,
AH.CancellationDate,
AH.CancellationType,
AHE.IsBookingConfirmed,
--SH.IsReadyForInvoice,
STG.DocName,
STG.DocDate,
STG.QTY,
STG.RATE,
PD.JobCardId,
 AH.IsPaid,
 --SH.BILLEDDATETIME,
 --SH.DELIVEREDDATETIME,
REN.IsSyced,
IBM.ItemGroupType,
AH.ImportedDate


END
GO