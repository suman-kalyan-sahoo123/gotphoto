# Airflow Management Makefile
# Simple commands for Airflow management

.PHONY: help airflow-up airflow-down list-dags

# Default target
help:
	@echo "Airflow Management Commands:"
	@echo "  make airflow-up   - Setup, initialize, and start Airflow"
	@echo "  make airflow-down - Stop and cleanup Airflow"
	@echo "  make list-dags    - List all available DAGs"

# Setup, initialize, and start Airflow
airflow-up:
	@echo "🚀 Setting up Airflow..."
	@echo "1. Creating directories..."
	mkdir -p dags logs plugins
	@echo "2. Initializing database..."
	docker compose up airflow-init
	@echo "3. Starting all services..."
	docker compose up -d
	@echo "✅ Airflow is ready!"
	@echo "🌐 Web UI: http://localhost:8082 (airflow/airflow)"
	@echo "🌸 Flower: http://localhost:5555"
	@echo "📁 DAGs folder: ./dags/"

# Stop and cleanup Airflow
airflow-down:
	@echo "🛑 Stopping Airflow..."
	docker compose down
	@echo "✅ Airflow stopped and cleaned up"

# List all available DAGs
list-dags:
	@echo "📋 Listing all available DAGs..."
	docker compose run --rm airflow-worker airflow dags list 