USE [Accounts]
GO
/****** Object:  StoredProcedure [dbo].[sp_acct_get_sales_order_line_details]    Script Date: 7/11/2025 6:16:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- GRANT ALL ON sp_acct_get_sales_order_line_details TO PUBLIC        
-- EXEC sp_acct_get_sales_order_line_details 841969, 15      
-- SELECT * FROM myob_salesorder_hdr WHERE trx_id = 818024        
-- SELECT * FROM myob_salesorder_dtl WHERE trx_id = 831446        

ALTER PROCEDURE [dbo].[sp_acct_get_sales_order_line_details]
(
    @trx_id INT,
    @NoofRows INT
)
AS
BEGIN

    SET NOCOUNT ON

    CREATE TABLE #SaleOrderItem
    (
        RowId INT,
        ItemId INT,
        Item_Code NVARCHAR(50),
        ItemName NVARCHAR(200),
        Item_Description NVARCHAR(4000),
        FromDate DATETIME,
        ToDate DATETIME,
        Amount_Per_Annum NUMERIC(18, 2),
        TotalAmount NUMERIC(18, 2),
        Tax_Code INT,
        TaxPercentageRate NUMERIC(15, 2),
        DateValidation NVARCHAR(1),
        NoofApplnValidation NVARCHAR(1),
        InvFrequencyValidation NVARCHAR(1),
        Orderno INT,
        frequency_id INT,
        trx_uid NVARCHAR(50),
        IsExcludedPackage BIT,
        seller_no NVARCHAR(25),
        department INT,
        project_no NVARCHAR(25),
		hod_userid INT,
		sub_dept_id INT
    )

    DECLARE @RowCount INT,
            @category_id INT,
            @merge_category_id INT

    SELECT @category_id = category_id
    FROM myob_salesorder_hdr (NOLOCK)
    WHERE trx_id = @trx_id

    SELECT @merge_category_id = dbo.fn_acct_get_merge_category_id(@category_id)

    INSERT INTO #SaleOrderItem
    SELECT ROW_NUMBER() OVER (ORDER BY sno),
           ItemId item_code,
           item_code,
           dbo.fn_acct_get_item_name(@category_id, CONVERT(INT, ItemId)) ItemName,
           
           item_description,
           FromDate,
           ToDate,
           CONVERT(INT, Amount_Per_Annum) Amount_Per_Annum,
           TotalAmount,

           
           Tax_Code,
           dbo.fn_acct_get_invoice_taxpercentagerate(@category_id, Tax_Code) TaxPercentageRate,
           
           ISNULL(dbo.fn_acct_get_invoice_validation(@category_id, dbo.fn_acct_get_merge_category_itemid(@category_id, CONVERT(INT, item_code)), 1), 'N') DateValidation,
           ISNULL(dbo.fn_acct_get_invoice_validation(@category_id, dbo.fn_acct_get_merge_category_itemid(@category_id, CONVERT(INT, item_code)), 2), 'N') NoofApplnValidation,
           ISNULL(dbo.fn_acct_get_invoice_validation(@category_id, dbo.fn_acct_get_merge_category_itemid(@category_id, CONVERT(INT, item_code)), 3), 'N') InvFrequencyValidation,

           1 Orderno,
           ISNULL(frequency_id, 0) frequency_id,
           trx_uid,
           IsExcludedPackage,
           seller_no,
           department,
           project_no,
		   CASE WHEN ISNULL(hod_userid, 0) <= 0 THEN -1 ELSE hod_userid END hod_userid,
		   CASE WHEN ISNULL(sub_dept_id, 0) <= 0 THEN -1 ELSE sub_dept_id END sub_dept_id
    FROM myob_salesorder_dtl a (NOLOCK)
    WHERE trx_id = @trx_id
    ORDER BY sno

    UPDATE #SaleOrderItem
    SET TaxPercentageRate = ISNULL(TaxPercentageRate, 0.00) / 100.00

    SELECT @RowCount = ISNULL(COUNT(*), 0)
    FROM #SaleOrderItem

    WHILE @RowCount < @NoofRows
    BEGIN

        INSERT INTO #SaleOrderItem
        SELECT @RowCount + 1,
               -1 ItemId,
               '-1' item_code,
               '' ItemName,
               '' item_description,
               NULL,
               NULL,
               NULL Amount_Per_Annum,
               NULL TotalAmount,
               -1 Tax_Code,
               0,
               'N',
               'N',
               'N',
               2 Orderno,
               0 frequency_id,
               NULL trx_uid,
               0,
               NULL,
               0,
               NULL,
			   - 1,
			   -1 

        SELECT @RowCount = @RowCount + 1

    END

    SELECT *,
           CONVERT(FLOAT, ISNULL(TotalAmount, 0.00) * ISNULL(TaxPercentageRate, 0.00)) TaxAmount
    FROM #SaleOrderItem
    ORDER BY RowId

END
