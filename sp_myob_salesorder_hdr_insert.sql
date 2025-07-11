USE [Accounts]
GO
/****** Object:  StoredProcedure [dbo].[sp_myob_salesorder_hdr_insert_backup_11Jul2025]    Script Date: 7/11/2025 4:46:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_myob_salesorder_hdr_insert_backup_11Jul2025]
(
    @category_id INT,
    @dt_invoice_date NVARCHAR(10),
    @card_id INT,
    @customer_name NVARCHAR(255),
    @Ship_Address NVARCHAR(255),
    @Journal_Memo NVARCHAR(255),
    @Sales_Person NVARCHAR(255),
    @Comments NVARCHAR(255),
    @QuotationType INT,
    @Userid NVARCHAR(30),
    @LinkToCompany INT = NULL,
    @premade_quotation_id INT = NULL,
    @CurrencyCode NVARCHAR(5) = NULL,
    @AcctPackage INT = NULL,
    @exchangeRate NUMERIC(18, 4),
    @FiscalRate NUMERIC(18, 4) = NULL,
    @workorder INT = NULL,
    @hide_period_date BIT = 0,
    @location_group_id INT = NULL,
    @is_include_terms bit = NULL,
    @invoice_type INT = NULL,
    @sales_term NVARCHAR(25) = NULL,
    @PlaceOfSupply nvarchar(max) = null
)
AS
BEGIN

    SET NOCOUNT ON

    DECLARE @trx_id INT,
            @Insert_Error INT,
            @invoice_date DATETIME,
            @Customer_PO NVARCHAR(16),
            @invoice_no NVARCHAR(15)


    IF @dt_invoice_date is null
       or ltrim(rtrim(@dt_invoice_date)) = ''
        SET @invoice_date = null
    ELSE
        SET @invoice_date = CONVERT(DATETIME, @dt_invoice_date, 103)

    SELECT @workorder = ISNULL(@workorder, 0)

    BEGIN TRAN

    SELECT @customer_name = company_name
    FROM rikvin..accounting_customers_view (NOLOCK)
    WHERE company_id = @card_id

    EXEC sp_myob_salesorder_number_autogenerate @category_id,
                                                @Auto_Number_Tranno = @trx_id OUTPUT,
                                                @Auto_Number_PO = @Customer_PO OUTPUT,
                                                @Auto_Number_Invoice = @invoice_no OUTPUT

    INSERT INTO myob_salesorder_hdr
    (
        trx_id,
        category_id,
        customer_po,
        invoice_no,
        invoice_date,
        card_id,
        customer_name,
        Ship_Address1,
        Ship_Address2,
        Ship_Address3,
        Ship_Address4,
        Dest_country,
        Journal_Memo,
        Sales_Person,
        Comments,
        TaxInclusive,
        Create_User,
        Create_Date,
        Modify_User,
        Modify_Date,
        Status,
        DataTransfer,
        QuotationType,
        LinkToCompany,
        premade_quotation_id,
        CurrencyCode,
        AcctPackage,
        exchange_rate,
        FiscalRate,
        workorder,
        hide_period_date,
        location_group_id,
        terms_doc_id,
        invoice_type,
        sales_term,
        PlaceOfSupply,
        address_id,
        state_code
    )
    SELECT @trx_id,
           @category_id,
           @customer_po,
           @invoice_no,
           @invoice_date,
           @card_id,
           @customer_name,
           @customer_name,
           @Ship_Address,
           '',
           '',
           dbo.fn_acct_get_account_category_country_name(@category_id),
           @Journal_Memo,
           @Sales_Person,
           @Comments,
           'N',
           @Userid,
           GETDATE(),
           @Userid,
           GETDATE(),
           'A',
           'Y',
           @QuotationType,
           ISNULL(@LinkToCompany, 0),
           ISNULL(@premade_quotation_id, 0),
           @CurrencyCode,
           ISNULL(@AcctPackage, 0),
           @exchangeRate,
           @FiscalRate,
           @workorder,
           @hide_period_date,
           @location_group_id,
           CASE
               WHEN @is_include_terms = 1 THEN
               (
                   SELECT top 1
                       doc_id
                   FROM terms_and_condition_documents (NOLOCK)
                   WHERE category_id = @category_id
                         AND [status] = 'A'
               )
               ELSE
                   null
           END,
           @invoice_type,
           @sales_term,
           @PlaceOfSupply,
           ISNULL(@PlaceOfSupply, 0),
           rikvin.dbo.fn_get_company_address_country_state_code(@PlaceOfSupply)

    SELECT @Insert_Error = @@ERROR

    IF (@Insert_Error = 0)
    BEGIN
        SELECT @trx_id
        COMMIT TRAN
    END
    ELSE
    BEGIN
        SELECT 0
        ROLLBACK TRAN
    END
END
