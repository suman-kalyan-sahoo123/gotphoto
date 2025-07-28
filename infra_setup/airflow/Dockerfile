FROM apache/airflow:2.8.1

USER root
RUN apt-get update && apt-get install -y git
USER airflow

# Install dbt using pip directly
RUN pip install --no-cache-dir dbt-core>=1.8.0 dbt-snowflake>=1.8.0 