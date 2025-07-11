USE [Accounts]
GO
/****** Object:  StoredProcedure [dbo].[sp_acct_myob_salesorder_dtl_insert]    Script Date: 7/11/2025 5:24:38 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_acct_myob_salesorder_dtl_insert]
(
    @trx_id INT,
    @sno INT,
    @category_id INT,
    @ItemId INT,
    @ItemCode NVARCHAR(30),
    @item_description NVARCHAR(2000),
    @dt_FromDate NVARCHAR(10),
    @dt_ToDate NVARCHAR(10),
    @Amount_Per_Annum NUMERIC(15, 2),
    @TotalAmount NUMERIC(15, 2),
    @Tax_Code NVARCHAR(10),
    @TaxInclusive NCHAR(1),
    @Userid NVARCHAR(30),
    @frequency_id INT = NULL,
    @trx_uid NVARCHAR(50) = NULL,
    @hide_date BIT = 0, --Flag to hide appended date part in item description    
    @isExcludedPackage BIT = 0,
    @invoice_uid NVARCHAR(50) = NULL,
    @invoice_type INT = NULL,
    @seller_no NVARCHAR(30) = NULL,
    @department INT = NULL,
    @project_no NVARCHAR(30) = NULL,
	@hod_userid INT = NULL,
	@sub_dept_id INT = NULL
)
AS
BEGIN

    SET NOCOUNT ON

    DECLARE @Insert_Error INT,
            @FromDate DATETIME,
            @ToDate DATETIME,
            --@GST_Amount    NUMERIC(15,2),    
            --@IncTax_TotalAmount  NUMERIC(15,2),    
            @GST_Amount FLOAT,
            @IncTax_TotalAmount FLOAT,
            @PeriodFromTo NVARCHAR(1000),
            @ItemSalesTaxRefListID NVARCHAR(100),
            @company_id INT
    IF @dt_FromDate IS NULL
       OR LTRIM(RTRIM(@dt_FromDate)) = ''
        SET @FromDate = null
    ELSE
        SET @FromDate = CONVERT(DATETIME, @dt_FromDate, 103)

    IF @dt_ToDate IS NULL
       OR LTRIM(RTRIM(@dt_ToDate)) = ''
        SET @ToDate = null
    ELSE
        SET @ToDate = CONVERT(DATETIME, @dt_ToDate, 103)


    IF (
           @FromDate IS NOT NULL
           AND @ToDate IS NOT NULL
           AND ISNULL(@hide_date, CAST(0 AS BIT)) = 0
       )
    BEGIN
        SET @PeriodFromTo
            = ' *(From ' + ISNULL(REPLACE(CONVERT(NVARCHAR(10), @FromDate, 103), '/', '.'), '') + ' To '
              + ISNULL(REPLACE(CONVERT(NVARCHAR(10), @ToDate, 103), '/', '.'), '') + ')'
        SET @item_description = ISNULL(@item_description, '') + ISNULL(@PeriodFromTo, '')
        SET @item_description
            = REPLACE(
                         @item_description,
                         SUBSTRING(
                                      @item_description,
                                      CHARINDEX('*(From', @item_description),
                                      LEN(LTRIM(RTRIM(@item_description))) - CHARINDEX('*(From', @item_description) + 1
                                  ),
                         @PeriodFromTo
                     )
    END
    ELSE IF (@hide_date = 1 AND CHARINDEX('*(From', @item_description) > 0)
    BEGIN
        SET @item_description
            = REPLACE(
                         @item_description,
                         SUBSTRING(
                                      @item_description,
                                      CHARINDEX('*(From', @item_description),
                                      LEN(LTRIM(RTRIM(@item_description))) - CHARINDEX('*(From', @item_description) + 1
                                  ),
                         ''
                     )
    END

    SELECT @company_id = card_id
    FROM myob_salesorder_hdr (NOLOCK)
    WHERE trx_id = @trx_id

    
    SELECT @ItemSalesTaxRefListID = ItemSalesTaxRefListID
    FROM vw_acct_quickbook_salestaxcode (NOLOCK)
    WHERE category_id = @category_id
          AND SalesTaxCodeID = @Tax_Code

    

	SELECT @GST_Amount = dbo.fn_acct_get_invoice_tax_amount(@category_id, CONVERT(INT, @Tax_Code), @TotalAmount, 1)
        SELECT @IncTax_TotalAmount
            = dbo.fn_acct_get_invoice_tax_amount(@category_id, CONVERT(INT, @Tax_Code), @TotalAmount, 2)

    SELECT @GST_Amount = ISNULL(@GST_Amount, 0)
    SELECT @IncTax_TotalAmount = ISNULL(@IncTax_TotalAmount, 0)

    IF EXISTS
    (
        SELECT '*'
        FROM myob_salesorder_dtl
        WHERE trx_id = @trx_id
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(50), trx_uid))) = LTRIM(RTRIM(CONVERT(NVARCHAR(50), @trx_uid)))
              AND @ItemId > 0
              AND @trx_uid IS NOT NULL
    )
    BEGIN

        UPDATE myob_salesorder_dtl
        SET sno = @sno,
            ItemId = @ItemId,
            ItemCode = @ItemCode,
            QuotationId = @ItemId,
            item_code = CONVERT(NVARCHAR(50), @ItemId),
            item_description = @item_description,
            FromDate = @FromDate,
            ToDate = @ToDate,
            Amount_Per_Annum = @Amount_Per_Annum,
            TotalAmount = @TotalAmount,
            Inc_Tax_TotalAmount = @IncTax_TotalAmount,
            GST_Amount = @GST_Amount,
            Tax_Code = @Tax_Code,
            TaxPercentageRate = dbo.fn_acct_get_invoice_taxpercentagerate(@category_id, CONVERT(INT, @Tax_Code)),

            Create_User = @Userid,
            Create_Date = GETDATE(),
            Status = 'A',
            frequency_id = @frequency_id,
            IsExcludedPackage = @isExcludedPackage,
            seller_no = @seller_no,
            department = @department,
            project_no = @project_no,
		hod_userid = @hod_userid,
		hod_user_sub_dept = dbo.fn_acct_get_hod_user_sub_dept(@hod_userid),
		sub_dept_id = @sub_dept_id
        WHERE trx_id = @trx_id
              AND LTRIM(RTRIM(CONVERT(NVARCHAR(50), trx_uid))) = LTRIM(RTRIM(CONVERT(NVARCHAR(50), @trx_uid)))
              AND @ItemId > 0
              AND @trx_uid IS NOT NULL

        SELECT @Insert_Error = @@ERROR
    END
    ELSE
    BEGIN

        INSERT INTO myob_salesorder_dtl
        (
            trx_id,
            sno,
            ItemId,
            ItemCode,
            QuotationId,
            item_code,
            item_description,
            FromDate,
            ToDate,
            Amount_Per_Annum,
            TotalAmount,
            Inc_Tax_TotalAmount,
            GST_Amount,
            Tax_Code,
            TaxPercentageRate,
            Create_User,
            Create_Date,
            Status,
            frequency_id,
            trx_uid,
            IsExcludedPackage,
            seller_no,
            department,
            project_no,
		hod_userid,
		hod_user_sub_dept,
		sub_dept_id
        )
        SELECT @trx_id,
               @sno,
               @ItemId,
               @ItemCode,
               @ItemId,
               CONVERT(NVARCHAR(50), @ItemId),
               @item_description,
               @FromDate,
               @ToDate,
               @Amount_Per_Annum,
               @TotalAmount,
               @IncTax_TotalAmount,
               @GST_Amount,
               @Tax_Code,
               dbo.fn_acct_get_invoice_taxpercentagerate(@category_id, CONVERT(INT, @Tax_Code)),
               @Userid,
               GETDATE(),
               'A',
               @frequency_id,
               NEWID(),
               @isExcludedPackage,
               @seller_no,
               @department,
               @project_no,
		   @hod_userid,
		   dbo.fn_acct_get_hod_user_sub_dept(@hod_userid),
		   @sub_dept_id


        SELECT @Insert_Error = @@ERROR

    END

    IF (@Insert_Error = 0)
    BEGIN
        EXEC sp_set_total_withholding_tax_amount @category_id,
                                                 @trx_id,
                                                 @invoice_type
        SELECT @sno

    END
    ELSE
    BEGIN
        SELECT 0

    END
END
