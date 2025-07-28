"""
dbt Pipeline DAG
Runs dbt commands in the correct order: staging → intermediate → dimensions → marts
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.dummy import DummyOperator

# Default arguments
default_args = {
    'owner': 'gotphoto',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Create the DAG
dag = DAG(
    'dbt_pipeline',
    default_args=default_args,
    description='dbt pipeline: staging → intermediate → dimensions → marts',
    schedule_interval=timedelta(days=1),
    catchup=False,
    tags=['dbt', 'gotphoto', 'data-pipeline'],
)

# Define tasks
start = DummyOperator(
    task_id='start',
    dag=dag,
)

# dbt commands
dbt_debug = BashOperator(
    task_id='dbt_debug',
    bash_command='cd /opt/airflow/dbt_project && dbt debug --project-dir . --profiles-dir profiles',
    dag=dag,
)

dbt_deps = BashOperator(
    task_id='dbt_deps',
    bash_command='cd /opt/airflow/dbt_project && dbt deps --project-dir . --profiles-dir profiles',
    dag=dag,
)

dbt_compile = BashOperator(
    task_id='dbt_compile',
    bash_command='cd /opt/airflow/dbt_project && dbt compile --project-dir . --profiles-dir profiles',
    dag=dag,
)

# Build models by layer
dbt_build_staging = BashOperator(
    task_id='dbt_build_staging',
    bash_command='cd /opt/airflow/dbt_project && dbt build --select staging --project-dir . --profiles-dir profiles',
    dag=dag,
)

dbt_build_intermediate = BashOperator(
    task_id='dbt_build_intermediate',
    bash_command='cd /opt/airflow/dbt_project && dbt build --select intermediate --project-dir . --profiles-dir profiles',
    dag=dag,
)

dbt_build_dimensions = BashOperator(
    task_id='dbt_build_dimensions',
    bash_command='cd /opt/airflow/dbt_project && dbt build --select dimensions --project-dir . --profiles-dir profiles',
    dag=dag,
)

# Run marts in parallel (4 separate tasks)
dbt_build_revenue_mart = BashOperator(
    task_id='dbt_build_revenue_mart',
    bash_command='cd /opt/airflow/dbt_project && dbt build --select marts.revenue_pricing --project-dir . --profiles-dir profiles',
    dag=dag,
)

dbt_build_customer_mart = BashOperator(
    task_id='dbt_build_customer_mart',
    bash_command='cd /opt/airflow/dbt_project && dbt build --select marts.customer_analytics --project-dir . --profiles-dir profiles',
    dag=dag,
)

dbt_build_supplier_mart = BashOperator(
    task_id='dbt_build_supplier_mart',
    bash_command='cd /opt/airflow/dbt_project && dbt build --select marts.supplier_analytics --project-dir . --profiles-dir profiles',
    dag=dag,
)

dbt_build_order_mart = BashOperator(
    task_id='dbt_build_order_mart',
    bash_command='cd /opt/airflow/dbt_project && dbt build --select marts.order_performance --project-dir . --profiles-dir profiles',
    dag=dag,
)

end = DummyOperator(
    task_id='end',
    dag=dag,
)

# Define task dependencies
start >> dbt_debug >> dbt_deps >> dbt_compile >> dbt_build_staging >> dbt_build_intermediate >> dbt_build_dimensions >> [dbt_build_revenue_mart, dbt_build_customer_mart, dbt_build_supplier_mart, dbt_build_order_mart] >> end 