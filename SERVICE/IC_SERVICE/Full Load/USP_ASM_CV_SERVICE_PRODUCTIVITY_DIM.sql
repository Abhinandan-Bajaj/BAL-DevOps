/*******************************************HISTORY***************************************************************************************************/
/*----------------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY     |CHANGE DESCRIPTION	                                                                              */
/*----------------------------------------------------------------------------------------------------------------------------------------------------*/
/* 2024-12-22 	|	Ashwini Ahire		| Productivity IC screen- New Dim Table Created                                                       */
/*----------------------------------------------------------------------------------------------------------------------------------------------------*/
/*----------------------------------------------------------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY****************************************************************************************************/


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [dbo].[USP_ASM_CV_SERVICE_PRODUCTIVITY_DIM] AS
BEGIN

PRINT('LOADING DATA FROM Source TABLE')
--*****************************************************************
--1. Load Productivity for IC

TRUNCATE TABLE ASM_CV_SERVICE_PRODUCTIVITY_DIM 

INSERT INTO ASM_CV_SERVICE_PRODUCTIVITY_DIM(
         [BU]
	,[Bay_Code]
	,[Name]
	,[CompanyID]
	,[DealerCode]
	,[DealerName]
	,[BranchID]
	,[Branch]
	,[ImportedDate]
        ,[Refresh_Date]
)
SELECT DISTINCT
		 BMD.BU
		,BMD.Code AS Bay_Code
		,BMD.Name
		,CM.CompanyID
		,ADM.DealerCode
		,BMD.Dealer AS DealerName
		,BMD.BranchID
		,BMD.Branch
		,BMD.ImportedDate
                ,getdate() AS Refresh_Date
	 	
FROM CDMS_BAY_MASTER_DATA BMD 
INNER JOIN COMPANY_MASTER CM ON (CM.COMPANYID = BMD.COMPANYID AND CM.IMPORTEDDATE = 
(SELECT MAX(CM1.IMPORTEDDATE) FROM COMPANY_MASTER CM1 WHERE CM.COMPANYID = CM1.COMPANYID))
INNER JOIN ASM_SERVICE_DEALER_MASTER_DIM ADM ON ADM.DealerCode = CM.CODE
WHERE BMD.BU = '3W Dealer'

PRINT('ASM_CV_SERVICE_PRODUCTIVITY_DIM LOADED')

END
GO