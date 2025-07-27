.PHONY: start stop docs

# Start container in background and open interactive session
dbt-start:
	docker-compose up -d
	sleep 2
	docker exec -it dbt-cli bash

# Stop container
dbt-stop:
	docker-compose down

# Generate and serve dbt documentation
dbt-docs-serve:
	docker-compose up -d
	sleep 2
	docker exec -d dbt-cli bash -c "cd /app/dbt_project && dbt docs generate"
	sleep 3
	docker exec -d dbt-cli bash -c "cd /app/dbt_project && dbt docs serve --host 0.0.0.0 --port 8080"
	@echo "✅ dbt documentation generated and served!"
	@echo "🌐 Access docs at: http://localhost:8080"
	@echo "📋 Press Ctrl+C to stop the server" 