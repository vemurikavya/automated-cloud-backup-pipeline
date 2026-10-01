# Automated Cloud Backup Pipeline

A Linux-based backup automation project built using **Bash, AWS CLI, Amazon S3, and cron**.

The project creates compressed backups of a local directory, uploads them to Amazon S3, verifies the upload, keeps the latest 7 local backups, and records the results in a log file.

## Architecture

```text
Linux / WSL2
     |
     v
  Bash Script
     |
     +-- Create compressed backup
     |
     +-- Upload to Amazon S3
     |
     +-- Retry failed uploads
     |
     +-- Verify S3 upload
     |
     +-- Remove old local backups
     |
     +-- Write logs
     |
     v
 Amazon S3

Cron runs the script automatically.
```

## Features

* Creates timestamped `.tar.gz` backup files
* Checks whether the source directory exists
* Checks whether AWS CLI is available
* Verifies AWS authentication
* Uploads backups to Amazon S3
* Retries failed S3 uploads up to 3 times
* Verifies that the uploaded backup exists in S3
* Keeps the latest 7 local backups
* Records operations in a log file
* Runs automatically using cron
* Supports restoring backup files

## Project Structure

```text
automated-cloud-backup-pipeline/
|
|-- backup.sh
|-- backups/
|-- logs/
|   `-- backup.log
|-- source/
|   |-- notes.txt
|   `-- report.txt
`-- README.md
```

### Main Components

* `backup.sh` — Main Bash backup script
* `source/` — Files that need to be backed up
* `backups/` — Local backup archives
* `logs/` — Backup logs
* `backup.log` — Records backup operations and errors
* `README.md` — Project documentation

## Requirements

* Linux or WSL2 Ubuntu
* Bash
* AWS CLI
* AWS account
* Amazon S3 bucket
* Cron
* Git

## AWS Setup

The AWS CLI must be configured with an AWS identity that has the required S3 permissions.

Configure AWS CLI:

```bash
aws configure
```

Check AWS authentication:

```bash
aws sts get-caller-identity
```

The S3 bucket used during development was created in the `ap-south-1` (Mumbai) region.

Keep the S3 bucket private and keep S3 Block Public Access enabled.

> Never commit AWS access keys, secret keys, or the `~/.aws/` directory to GitHub.

## How the Backup Works

The script performs the following steps:

1. Checks whether the source directory exists.
2. Checks whether AWS CLI is installed.
3. Verifies AWS authentication.
4. Creates a timestamped `.tar.gz` backup.
5. Uploads the backup to Amazon S3.
6. Retries the upload up to 3 times if it fails.
7. Verifies that the backup exists in S3.
8. Keeps only the latest 7 local backups.
9. Records the results in `backup.log`.

## S3 Upload

The backup is uploaded using the AWS CLI:

```bash
aws s3 cp backup_YYYYMMDD_HHMMSS.tar.gz s3://<bucket-name>/
```

If the upload fails, the script retries up to 3 times with a 5-second delay between attempts.

After a successful upload, the script verifies the backup:

```bash
aws s3 ls s3://<bucket-name>/backup_YYYYMMDD_HHMMSS.tar.gz
```

## Local Backup Retention

The script keeps the latest 7 timestamped backup files in the local `backups/` directory.

Older local backups are automatically removed.

Local backup retention and S3 storage are separate. Removing an old local backup does not remove the object from S3.

## Cron Automation

The backup script is scheduled using Linux cron.

Development cron entry:

```cron
30 13 * * * /home/kavya/linux-projects/automated-cloud-backup-pipeline/backup.sh
```

The WSL environment used during development runs on UTC, so `13:30 UTC` corresponds to `19:00 IST`.

Check the cron service:

```bash
systemctl status cron --no-pager
```

Check the configured cron job:

```bash
crontab -l
```

The scheduled job was successfully tested and the backup log confirmed that the script was executed by cron.

## Restore Backup

A backup can be restored by extracting the archive into a separate directory.

Create a restore directory:

```bash
mkdir restore-test
```

Extract the latest backup:

```bash
tar -xzf "$(ls -t backups/backup_*.tar.gz | head -1)" -C restore-test
```

Check the restored files:

```bash
find restore-test
```

Compare the restored files with the original source:

```bash
diff -r source/ restore-test/source/
```

If `diff` produces no output, the restored files match the original files.

The restore process was successfully tested during development.

## Logging

Backup operations are recorded in:

```text
logs/backup.log
```

The log records events such as:

* Successful backup creation
* S3 upload attempts
* S3 upload success or failure
* S3 verification
* Retry attempts
* Removal of old backups

View recent log entries:

```bash
tail -n 10 logs/backup.log
```

## Failure Handling

The script handles several failure conditions.

It checks:

* Missing source directory
* Missing AWS CLI
* Failed AWS authentication
* Failed backup creation
* Failed S3 upload
* Failed S3 verification

For S3 upload failures, the script retries up to 3 times.

If all attempts fail, the error is recorded in the log and the script exits with a non-zero status.

## Testing

The following scenarios were tested:

* Successful backup creation
* Missing source directory
* AWS CLI availability check
* AWS authentication check
* Successful S3 upload
* Failed S3 upload and retry handling
* S3 upload verification
* Local backup retention
* Backup restoration
* Cron execution

## Usage

Clone the repository:

```bash
git clone <your-github-repository-url>
cd automated-cloud-backup-pipeline
```

Make the script executable:

```bash
chmod +x backup.sh
```

Configure AWS CLI:

```bash
aws configure
```

Update the S3 bucket in `backup.sh`:

```bash
S3_BUCKET="s3://<your-bucket-name>"
```

Add files to the `source/` directory.

Run the backup:

```bash
./backup.sh
```

Check the log:

```bash
tail -n 10 logs/backup.log
```

Check local backups:

```bash
find backups -maxdepth 1 -type f -name "backup_*.tar.gz" | sort
```

Check S3:

```bash
aws s3 ls s3://<your-bucket-name>/ --human-readable
```

## Technologies Used

* Linux / WSL2 Ubuntu
* Bash
* tar
* gzip
* AWS CLI
* Amazon S3
* AWS STS
* cron
* Git / GitHub

## Security

* Never commit AWS credentials to GitHub.
* Keep the S3 bucket private.
* Keep S3 Block Public Access enabled.
* Use least-privilege IAM permissions.
* Do not commit the `~/.aws/` directory or credential files.

## Project Status

### Completed

* Bash backup automation
* Compressed backup creation
* AWS CLI integration
* Amazon S3 upload
* S3 upload retry handling
* S3 upload verification
* Local backup retention
* Logging
* Backup restoration testing
* Cron automation
* Failure scenario testing

### Future Improvements

* Configure a least-privilege IAM policy
* Run the pipeline on an EC2 Linux instance
* Use an EC2 IAM role instead of long-term AWS access keys
* Add S3 lifecycle management
* Add monitoring or alerting

