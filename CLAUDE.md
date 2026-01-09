# biggpdb

PostgreSQL + PostGIS database for geospatial data.

## Stack
- PostgreSQL 16.4 with PostGIS 3.4
- Docker container: `biggpdb`
- Port: 5432
- Database: biggpdb, User: postgres, Password: postgres

## Commands
```bash
# Start
docker compose up -d

# Stop
docker compose down

# Logs
docker logs biggpdb

# Connect
docker exec -it biggpdb psql -U postgres biggpdb
```

## Backup
Backup scripts in separate repo: vps-finland-backup
