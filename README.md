# Renue Test Assignment

## Overview
To get started, follow these steps:

1. Run the Bash script `install.sh` on the **host** server.
2. Run the Bash script `setup.sh` on the **hosta** and **hostb** servers.

## Server and Script Structure

| **Server** | **Script**     |
|------------|----------------|
| **host**   | `install.sh`   |
| **hosta**  | `setup.sh`     |
| **hostb**  | `setup.sh`     |

## Script Descriptions

### `install.sh`:
- Installs the necessary dependencies and tools (e.g., Ansible).
- Creates a public SSH key.
- Generates configuration files:
  - `inventory.ini` — Ansible inventory.
  - `playbook.yml` — Ansible playbook for performing all configuration tasks.
- Runs the Ansible playbook to configure the servers.

### `setup.sh`:
- Prompts to enter the public SSH key for the **DevOps** user.
- Disables SSH password authentication.
- Configures SSH key-based authentication for the **DevOps** user.
- Performs additional security and service configurations on the **hosta** and **hostb** servers.

## Tasks Addressed by the Project:

1. **Disabling SSH password authentication**:
   - Password-based SSH authentication is disabled on both servers.
   - Only SSH key-based authentication is enabled for the **DevOps** user.

2. **Adding the DevOps user and configuring permissions**:
   - A **DevOps** user is created on both servers.
   - SSH key-based authentication is configured for the **DevOps** user.
   - The **DevOps** user has passwordless sudo privileges.

3. **Configuring Fail2Ban**:
   - Fail2Ban is configured on **hosta** to block access for 1 hour if there are 3 failed login attempts within 1 minute.

4. **Configuring PostgreSQL on **hosta**:
   - PostgreSQL is installed on **hosta**.
   - Databases `app` and `custom` are created.
   - Users are added:
     - **app** — full access to the `app` database.
     - **custom** — full access to the `custom` database.
     - **service** — read-only access to all databases.

5. **Configuring Nginx on **hostb**:
   - Nginx is installed on **hostb**.
   - Nginx is configured to proxy requests to the site `https://renue.ru` when accessing localhost or the server's domain name.

6. **Configuring PostgreSQL access from **hostb**:
   - PostgreSQL on **hosta** is configured to allow access only from **hostb**.
   - Nginx access on **hostb** is restricted from **hosta**.

7. **Configuring PostgreSQL backups**:
   - Daily PostgreSQL backups are configured on **hosta**.
   - Backups are stored on **hostb**.

## Example Usage


```bash
git clone https://github.com/invorkel322/testrenue.git
cd testrenue
On the host server:

chmod +x install.sh
./install.sh
On the hosta and hostb servers:

# Copy the setup.sh script to each server
scp setup.sh root@hosta:/tmp/
scp setup.sh root@hostb:/tmp/

# Run setup.sh on each server
chmod +x /tmp/setup.sh
/tmp/setup.sh
