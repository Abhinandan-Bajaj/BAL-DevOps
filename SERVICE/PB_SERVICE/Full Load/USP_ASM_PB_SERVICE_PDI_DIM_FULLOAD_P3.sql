SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Alter PROC [dbo].[USP_ASM_PB_SERVICE_PDI_DIM_FULLOAD_P3]
AS
BEGIN
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|CHANGE DESCRIPTION			    */
/*--------------------------------------------------------------------------------------------------*/
/* 2025-02-06 	|	Dewang Makani		    | ASM_PB_SERVICE_PDI_DIM - New Dim Table Created */
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/
PRINT('LOADING DATA FROM Source TABLE')

TRUNCATE TABLE ASM_PB_SERVICE_PDI_DIM

INSERT INTO ASM_PB_SERVICE_PDI_DIM
(
      FK_Docid,
      SD_HeaderID,
      DOCNAME,
      Docdate,
      FK_Companyid,
      FK_Contactid,
      FK_Ibid,
      Usagereading,
      FK_Branchid,
      FK_Modelid,
      BU,
      ServiceType, 
      DealerCode,
      PDIOK, 
      PDINOTOK, 
      PDINOWOK,
      Importeddate,
      InvoiceDate,
      GRNDocname,
      GRNDate,
      RefreshDate
)

SELECT DISTINCT 
FCT.FK_Docid AS [FK_Docid] --
,SD.HEADERID AS [SD_HeaderID] --
,FCT.DOCNAME --
,CAST(FCT.Docdate AS DATE) AS Docdate --
,FCT.FK_Companyid AS [FK_Companyid] --
,FCT.FK_Contactid AS FK_Contactid --
,FCT.FK_Ibid AS [FK_Ibid] --
,FCT.Usagereading --
,FCT.FK_Branchid AS [FK_Branchid] --
,FCT.FK_Modelid AS [FK_Modelid] --
,FCT.BU --
,FCT.ServiceType AS ServiceType --
,FCT.DealerCode AS DealerCode --
,FCT.PDIOK AS PDIOK
,FCT.PDINOTOK AS PDINOTOK
,FCT.PDINOWOK AS PDINOWOK
,FCT.Importeddate --
,IBM.INVOICEDATE AS InvoiceDate --
,GH.DOCUMENTNO AS GRNDocname
,CAST(GH.DOCUMENTDATE AS DATE) AS GRNDate
,getdate() AS RefreshDate

FROM ASM_PB_SERVICE_FACT FCT
INNER JOIN SERVICE_DETAIL SD ON SD.DOCID = FCT.FK_Docid
LEFT JOIN INSTALL_BASE_MASTER IBM ON IBM.IBID=FCT.FK_IBID
LEFT JOIN GRN_LINE GL ON GL.CHASSIS = IBM.NAME
LEFT JOIN GRN_HEADER GH ON GH.CDMSDOCID = GL.CDMSDOCID
WHERE FCT.Service_Retail_Typeidentifier = '101' and FCT.DOCNAME LIKE 'PBPDI%' AND GH.DOCUMENTNO LIKE 'GRN%'

PRINT('ASM_PB_SERVICE_PDI_DIM TABLE LOADED')

END
GO