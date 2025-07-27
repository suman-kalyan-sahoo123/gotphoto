from snowflake.snowpark.functions import sum, count, when, col, lit

def model(dbt, session):
    """
    Customer Lifetime Value (CLV) calculation model.
    
    This model calculates basic CLV metrics for each customer including:
    - Customer aggregation and metrics
    - Customer segmentation and tiering
    - Lifetime value calculations
    
    Returns:
        DataFrame with customer-level CLV metrics
    """
    
    # Get customer order data
    customer_orders_df = dbt.ref("fact_customer_orders")
    
    # Calculate customer-level aggregations using proper Snowpark functions
    customer_metrics = customer_orders_df.group_by("customer_key").agg(
        sum("total_net_revenue").alias("total_revenue"),
        count("order_key").alias("total_orders")
    )
    
    # Calculate average order value
    customer_metrics = customer_metrics.with_column(
        "avg_order_value",
        col("total_revenue") / col("total_orders")
    )
    
    # Calculate orders per year (assuming 2-year period)
    customer_metrics = customer_metrics.with_column(
        "orders_per_year",
        col("total_orders") / 2
    )
    
    # Calculate simple CLV (Average Order Value × Orders per Year × 2 years)
    customer_metrics = customer_metrics.with_column(
        "simple_clv",
        col("avg_order_value") * col("orders_per_year") * 2
    )
    
    # Customer tiering based on total revenue
    customer_metrics = customer_metrics.with_column(
        "customer_tier",
        when(col("total_revenue") < 10000, "Bronze")
        .when(col("total_revenue") < 50000, "Silver")
        .when(col("total_revenue") < 100000, "Gold")
        .otherwise("Platinum")
    )
    
    # Customer value categories based on CLV
    customer_metrics = customer_metrics.with_column(
        "value_category",
        when(col("simple_clv") < 5000, "Low Value")
        .when(col("simple_clv") < 20000, "Medium Value")
        .when(col("simple_clv") < 50000, "High Value")
        .otherwise("Premium Value")
    )
    
    # Customer activity flags
    customer_metrics = customer_metrics.with_column(
        "is_high_value",
        col("total_revenue") > 50000
    )
    
    customer_metrics = customer_metrics.with_column(
        "is_frequent",
        col("total_orders") > 5
    )
    
    customer_metrics = customer_metrics.with_column(
        "is_high_aov",
        col("avg_order_value") > 1000
    )
    
    # Profitability calculations
    customer_metrics = customer_metrics.with_column(
        "estimated_profit",
        col("total_revenue") * 0.2
    )
    
    customer_metrics = customer_metrics.with_column(
        "profit_margin_pct",
        lit(20.0)
    )
    
    # Revenue metrics
    customer_metrics = customer_metrics.with_column(
        "revenue_per_order",
        col("total_revenue") / col("total_orders")
    )
    
    customer_metrics = customer_metrics.with_column(
        "revenue_per_year",
        col("total_revenue") / 2
    )
    
    return customer_metrics 