.PHONY: up down logs scan lockfiles
up:
	docker compose up --build

down:
	docker compose down

logs:
	docker compose logs -f

scan:
	bash scripts/scan-for-sensitive.sh

lockfiles:
	bash scripts/generate-lockfiles.sh
