
/*******************************************HISTORY**************************************************/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*    DATE   	|	CREATED/MODIFIED BY		|					CHANGE DESCRIPTION		*/
/*--------------------------------------------------------------------------------------------------*/
/*	2025-09-16 	|	Lachmanna 	| Added ABC contorl for sales and service                       			*/
/*--------------------------------------------------------------------------------------------------*/
/*--------------------------------------------------------------------------------------------------*/
/*******************************************HISTORY**************************************************/

CREATE PROCEDURE [dbo].[USP_Audit_Balance_Control_Logs] 
    @spid INT,
    @sp_name VARCHAR(128),
    @table_name VARCHAR(128),
    @bussiness_process_name VARCHAR(128),
    @bu_name VARCHAR(50),
    @start_date_utc DATETIME,
    @end_date_utc DATETIME,
    @start_date_ist DATETIME,
    @end_date_ist DATETIME,
    @duration VARCHAR(15),
    @source_count bigInt,
    @target_count bigInt,
    @status VARCHAR(20),
    @error_message VARCHAR(1000)
AS
BEGIN
    INSERT INTO Audit_Balance_Control_Master
    (
        spid,
        sp_name,
        table_name,
        bussiness_process_name,
        bu_name,
        start_date_utc,
        end_date_utc,
	start_date_ist,
        end_date_ist,
        duration,
        source_count,
        target_count,
        status,
        error_message
    )
    VALUES
    (
        @spid,
        @sp_name,
	@table_name,
        @bussiness_process_name,
        @bu_name,
        @start_date_utc,
        @end_date_utc,
        @start_date_ist,
        @end_date_ist,
        @duration,
        @source_count,
        @target_count,
        @status,
        @error_message
    );
END
GO
