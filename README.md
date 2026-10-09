# Digital Evidence Management System (DEMS)

A database-driven system for managing digital evidence and its chain of custody.
Built with MariaDB and a Bash menu on Linux.

## Features
- Case and evidence records with SHA-256 hash
- Chain of custody, logged automatically and tamper-proof (triggers block edit/delete)
- Atomic evidence transfer through a stored procedure
- Search, filter, case reports and dashboard

## Setup (Debian / Ubuntu / Kali)
```bash
sudo apt update && sudo apt install -y mariadb-server mariadb-client
sudo systemctl enable --now mariadb
sudo mysql < schema.sql
chmod +x dems.sh
./dems.sh
```

## Files
- `schema.sql` - database, tables, triggers, procedure, views, sample data
- `dems.sh` - terminal menu application
- `DEMS_Presentation.pdf` - project presentation
